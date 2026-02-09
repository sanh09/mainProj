import os
import json
from dataclasses import asdict, is_dataclass
from datetime import datetime
from enum import Enum
from typing import Any, Optional
from uuid import uuid4
from threading import Lock

import psycopg
import requests
from psycopg.rows import dict_row
from fastapi import FastAPI, File, Form, HTTPException, Query, UploadFile
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr
from pipeline import ContractAnalysisPipeline
class UTF8JSONResponse(JSONResponse):
    media_type = "application/json; charset=utf-8"

app = FastAPI(default_response_class=UTF8JSONResponse)
pipeline = ContractAnalysisPipeline()

ANALYSIS_STORE: dict[str, dict[str, Any]] = {}
ANALYSIS_LOCK = Lock()
ANALYSIS_TTL_SECONDS = int(os.getenv("ANALYSIS_TTL_SECONDS", "3600"))
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "/app/uploads/user_files")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_ROLE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
SUPABASE_STORAGE_BUCKET = os.getenv("SUPABASE_STORAGE_BUCKET", "user-files")

def _get_db_conn():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "app_user"),
        password=os.getenv("DB_PASSWORD", "app_pass"),
        dbname=os.getenv("DB_NAME", "app_db"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )

def _upload_to_supabase_storage(
    local_path: str, remote_path: str, content_type: str
) -> Optional[str]:
    if not SUPABASE_URL or not SUPABASE_SERVICE_ROLE_KEY:
        return None
    upload_url = f"{SUPABASE_URL.rstrip('/')}/storage/v1/object/{SUPABASE_STORAGE_BUCKET}/{remote_path}"
    headers = {
        "Authorization": f"Bearer {SUPABASE_SERVICE_ROLE_KEY}",
        "apikey": SUPABASE_SERVICE_ROLE_KEY,
        "Content-Type": content_type or "application/octet-stream",
        "x-upsert": "true",
    }
    with open(local_path, "rb") as handle:
        response = requests.post(upload_url, headers=headers, data=handle, timeout=30)
    if response.status_code not in (200, 201):
        raise RuntimeError(
            f"Supabase Storage upload failed: {response.status_code} {response.text}"
        )
    return f"{SUPABASE_STORAGE_BUCKET}/{remote_path}"

def _ensure_analysis_columns():
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        db_schema = os.getenv("DB_SCHEMA", "public")
        cur.execute(
            """
            SELECT COLUMN_NAME
            FROM information_schema.columns
            WHERE table_schema=%s
              AND table_name='analysis_history'
              AND column_name IN ('clauses_json', 'risky_clauses_json', 'raw_text')
            """,
            (db_schema,),
        )
        existing = {row[0] for row in cur.fetchall() or []}
        if "clauses_json" not in existing:
            cur.execute("ALTER TABLE analysis_history ADD COLUMN clauses_json JSONB NULL")
        if "risky_clauses_json" not in existing:
            cur.execute("ALTER TABLE analysis_history ADD COLUMN risky_clauses_json JSONB NULL")
        if "raw_text" not in existing:
            cur.execute("ALTER TABLE analysis_history ADD COLUMN raw_text TEXT NULL")
        if (
            "clauses_json" not in existing
            or "risky_clauses_json" not in existing
            or "raw_text" not in existing
        ):
            conn.commit()
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass

def _normalize_filename(name: Optional[str]) -> Optional[str]:
    if not name:
        return None
    cleaned = name.strip()
    if not cleaned:
        return None
    # Heuristic fix for mojibake when UTF-8 bytes were decoded as latin-1.
    try:
        if any(ch == "�" for ch in cleaned) or "?" in cleaned:
            repaired = cleaned.encode("latin-1").decode("utf-8")
            if repaired.strip():
                return repaired
    except UnicodeError:
        pass
    return cleaned
def _serialize(obj: Any) -> Any:
    if is_dataclass(obj):
        return _serialize(asdict(obj))
    if isinstance(obj, Enum):
        return obj.value
    if isinstance(obj, list):
        return [_serialize(item) for item in obj]
    if isinstance(obj, dict):
        return {key: _serialize(value) for key, value in obj.items()}
    return obj
def _max_risk_level(clauses: list) -> Optional[str]:
    order = {"low": 1, "medium": 2, "high": 3, "critical": 4}
    highest = None
    highest_score = 0
    for clause in clauses:
        level = getattr(clause, "risk_level", None)
        value = level.value if level else None
        score = order.get(value or "", 0)
        if score > highest_score:
            highest_score = score
            highest = value
    return highest

def _format_result_for_app(result: Any, analysis_id: str) -> dict:
    risky_clauses = result.risky_clauses or []
    article_to_clause_id = {}
    clause_id_to_reason = {}
    for clause in risky_clauses:
        article_num = getattr(clause, "article_num", None)
        clause_id = getattr(clause, "id", None)
        if article_num and clause_id and article_num not in article_to_clause_id:
            article_to_clause_id[article_num] = clause_id
        if clause_id and clause_id not in clause_id_to_reason:
            raw_reason = _serialize(getattr(clause, "risk_reason", None))
            clause_id_to_reason[clause_id] = _normalize_reason(raw_reason)

    return {
        "analysis_id": analysis_id,
        "raw_text": _serialize(result.raw_text),
        "risky_clauses": _serialize(risky_clauses),
        "risky_article_nums": list(article_to_clause_id.keys()),
        "article_to_clause_id": article_to_clause_id,
        "clause_id_to_reason": clause_id_to_reason,
    }

def _prune_store():
    if ANALYSIS_TTL_SECONDS <= 0:
        return
    cutoff = datetime.utcnow().timestamp() - ANALYSIS_TTL_SECONDS
    stale_ids = []
    for analysis_id, entry in ANALYSIS_STORE.items():
        created_at = entry.get("created_at")
        if created_at and created_at.timestamp() < cutoff:
            stale_ids.append(analysis_id)
    for analysis_id in stale_ids:
        ANALYSIS_STORE.pop(analysis_id, None)

def _store_result(result: Any) -> str:
    analysis_id = uuid4().hex
    with ANALYSIS_LOCK:
        _prune_store()
        ANALYSIS_STORE[analysis_id] = {
            "result": result,
            "created_at": datetime.utcnow(),
            "debate_by_clause": {},
            "debate_summary": {},
        }
    return analysis_id

def _get_entry(analysis_id: str) -> dict[str, Any]:
    with ANALYSIS_LOCK:
        _prune_store()
        entry = ANALYSIS_STORE.get(analysis_id)
    if not entry:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return entry

def _find_clause(result: Any, clause_id: str):
    target = _normalize_clause_key(clause_id)
    for clause in result.risky_clauses or []:
        if _clause_matches(clause, clause_id, target):
            return clause
    for clause in result.clauses or []:
        if _clause_matches(clause, clause_id, target):
            return clause
    return None


def _normalize_clause_key(value: Optional[str]) -> str:
    if not value:
        return ""
    normalized = value.strip()
    normalized = normalized.replace(" ", "")
    normalized = normalized.replace("\u3000", "")
    return normalized.lower()


def _clause_matches(clause: Any, raw_id: str, normalized_target: str) -> bool:
    clause_id = getattr(clause, "id", None)
    article_num = getattr(clause, "article_num", None)
    title = getattr(clause, "title", None)

    if clause_id and str(clause_id) == raw_id:
        return True
    if article_num and str(article_num) == raw_id:
        return True
    if title and str(title) == raw_id:
        return True

    if normalized_target:
        if clause_id and _normalize_clause_key(str(clause_id)) == normalized_target:
            return True
        if article_num and _normalize_clause_key(str(article_num)) == normalized_target:
            return True
        if title and _normalize_clause_key(str(title)) == normalized_target:
            return True
    return False


def _clause_detail_from_obj(clause: Any) -> dict[str, Any]:
    clause_text = getattr(clause, "content", None) or ""
    risk_reason = getattr(clause, "risk_reason", None) or ""
    highlight_keywords = getattr(clause, "highlight_keywords", None) or []
    highlight_sentences = getattr(clause, "highlight_sentences", None) or []

    tenant_argument = getattr(clause, "tenant_argument", None) or ""
    landlord_argument = getattr(clause, "landlord_argument", None) or ""
    tenant_tags = getattr(clause, "tenant_tags", None) or []
    landlord_tags = getattr(clause, "landlord_tags", None) or []
    negotiation_points = getattr(clause, "negotiation_points", None) or []
    compromise_quote = getattr(clause, "compromise_quote", None) or ""

    if not tenant_argument and risk_reason:
        tenant_argument = f"해당 조항의 '{risk_reason}' 부분에 대한 조정이 필요합니다."
    if not landlord_argument and risk_reason:
        landlord_argument = f"해당 조항은 '{risk_reason}' 사유로 필요합니다."
    if not tenant_tags and highlight_keywords:
        tenant_tags = list(highlight_keywords)
    if not landlord_tags and highlight_keywords:
        landlord_tags = list(highlight_keywords)
    if not negotiation_points:
        if highlight_sentences:
            negotiation_points = list(highlight_sentences)[:5]
        elif risk_reason:
            negotiation_points = [risk_reason]
    if not compromise_quote and (tenant_argument or landlord_argument):
        compromise_quote = "상호 협의하여 합리적인 범위로 조정한다."

    return {
        "clause_text": clause_text,
        "tenant_argument": tenant_argument,
        "landlord_argument": landlord_argument,
        "tenant_tags": tenant_tags,
        "landlord_tags": landlord_tags,
        "negotiation_points": negotiation_points,
        "compromise_quote": compromise_quote,
    }


def _clause_detail_from_dict(clause: dict[str, Any]) -> dict[str, Any]:
    clause_text = clause.get("content") or clause.get("body") or clause.get("text") or ""
    risk_reason = clause.get("risk_reason") or ""
    highlight_keywords = clause.get("highlight_keywords") or []
    highlight_sentences = clause.get("highlight_sentences") or []

    tenant_argument = clause.get("tenant_argument") or ""
    landlord_argument = clause.get("landlord_argument") or ""
    tenant_tags = clause.get("tenant_tags") or []
    landlord_tags = clause.get("landlord_tags") or []
    negotiation_points = clause.get("negotiation_points") or []
    compromise_quote = clause.get("compromise_quote") or ""

    if not tenant_argument and risk_reason:
        tenant_argument = f"해당 조항의 '{risk_reason}' 부분에 대한 조정이 필요합니다."
    if not landlord_argument and risk_reason:
        landlord_argument = f"해당 조항은 '{risk_reason}' 사유로 필요합니다."
    if not tenant_tags and highlight_keywords:
        tenant_tags = list(highlight_keywords)
    if not landlord_tags and highlight_keywords:
        landlord_tags = list(highlight_keywords)
    if not negotiation_points:
        if highlight_sentences:
            negotiation_points = list(highlight_sentences)[:5]
        elif risk_reason:
            negotiation_points = [risk_reason]
    if not compromise_quote and (tenant_argument or landlord_argument):
        compromise_quote = "상호 협의하여 합리적인 범위로 조정한다."

    return {
        "clause_text": clause_text,
        "tenant_argument": tenant_argument,
        "landlord_argument": landlord_argument,
        "tenant_tags": tenant_tags,
        "landlord_tags": landlord_tags,
        "negotiation_points": negotiation_points,
        "compromise_quote": compromise_quote,
    }
@app.get("/")
def read_root():
    return {"message": "Hello from FastAPI + Docker!"}
@app.get("/health")
def health():
    return {"status": "ok"}

def _format_transcript_text(transcript: list[dict]) -> str:
    if not transcript:
        return ""
    lines = []
    for turn in transcript:
        speaker = turn.get("speaker", "")
        content = turn.get("content", "")
        lines.append(f"{speaker}: {content}".strip())
    return "\n".join(lines)
@app.post("/analyze/file")
async def analyze_file(
    file: UploadFile = File(...),
    user_id: Optional[int] = Form(None),
    email: Optional[EmailStr] = Form(None),
    original_name: Optional[str] = Form(None),
) -> UTF8JSONResponse:
    if not file.filename:
        raise HTTPException(status_code=400, detail="File name is required.")
    suffix = os.path.splitext(file.filename)[1] or ".dat"
    display_name = _normalize_filename(original_name) or _normalize_filename(file.filename) or file.filename
    saved_path = None
    conn = None
    cur = None
    try:
        contents = await file.read()
        size_bytes = len(contents)
        content_type = file.content_type or "application/octet-stream"
        os.makedirs(UPLOAD_DIR, exist_ok=True)
        saved_filename = f"{uuid4().hex}{suffix}"
        saved_path = os.path.join(UPLOAD_DIR, saved_filename)
        with open(saved_path, "wb") as out:
            out.write(contents)
        storage_path = saved_path

        result = pipeline.analyze(saved_path)
        raw_text = (result.raw_text or "").strip()
        if raw_text == "api필요":
            raise HTTPException(
                status_code=503,
                detail="OCR failed: UPSTAGE_API_KEY is missing.",
            )
        if not raw_text:
            raise HTTPException(
                status_code=422,
                detail="OCR produced empty text. Check the input file and OCR service.",
            )
        if not result.clauses and not os.getenv("OPENAI_API_KEY"):
            raise HTTPException(
                status_code=503,
                detail="Clause splitting fallback requires OPENAI_API_KEY.",
            )
        analysis_id = _store_result(result)

        risky_count = len(result.risky_clauses or [])
        risk_level = _max_risk_level(result.risky_clauses or [])
        summary = result.llm_summary or ""
        clauses_json = json.dumps(_serialize(result.clauses), ensure_ascii=False)
        risky_clauses_json = json.dumps(_serialize(result.risky_clauses), ensure_ascii=False)

        resolved_user_id = user_id
        if resolved_user_id is None and email:
            conn = _get_db_conn()
            cur = conn.cursor()
            cur.execute("SELECT id FROM users WHERE email=%s", (str(email),))
            row = cur.fetchone()
            if row:
                resolved_user_id = row[0]
            cur.close()
            conn.close()
            cur = None
            conn = None

        if resolved_user_id is not None:
            _ensure_analysis_columns()
            conn = _get_db_conn()
            cur = conn.cursor()
            cur.execute("SELECT id FROM users WHERE id=%s", (resolved_user_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=400, detail="User not found")
            try:
                remote_name = f"{resolved_user_id}/{saved_filename}"
                uploaded_path = _upload_to_supabase_storage(
                    saved_path, remote_name, content_type
                )
                if uploaded_path:
                    storage_path = uploaded_path
            except Exception as exc:
                print("SUPABASE UPLOAD ERROR >>>", repr(exc))
            cur.execute(
                """
                INSERT INTO user_files
                  (user_id, original_name, content_type, size_bytes, storage_path)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (
                    resolved_user_id,
                    display_name,
                    content_type,
                    size_bytes,
                    storage_path,
                ),
            )
            cur.execute(
                """
                INSERT INTO analysis_history
                  (user_id, original_name, risky_count, risk_level, summary, clauses_json, risky_clauses_json, raw_text)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    resolved_user_id,
                    display_name,
                    risky_count,
                    risk_level,
                    summary,
                    clauses_json,
                    risky_clauses_json,
                    result.raw_text,
                ),
            )
            conn.commit()

        return UTF8JSONResponse(
            content={
                "analysis_id": analysis_id,
                "analysisId": analysis_id,
                "user_id": resolved_user_id,
                "email": str(email) if email else None,
                "original_name": display_name,
                "raw_text": result.raw_text,
                "risky_count": risky_count,
                "risk_level": risk_level,
                "summary": summary,
                "llm_summary": summary,
                "clauses": _serialize(result.clauses),
                "risky_clauses": _serialize(result.risky_clauses),
            }
        )
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass
        if saved_path and not os.path.exists(saved_path):
            saved_path = None

@app.get("/history")
def get_history(user_id: int = Query(...)) -> UTF8JSONResponse:
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        cur.execute(
            """
            SELECT id, user_id, original_name, risky_count, risk_level, summary, created_at
            FROM analysis_history
            WHERE user_id=%s
            ORDER BY created_at DESC
            """,
            (user_id,),
        )
        rows = cur.fetchall() or []
        return UTF8JSONResponse(content=jsonable_encoder({"items": rows}))
    except Exception as e:
        print("HISTORY ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass

@app.get("/analysis/{analysis_id}")
def get_analysis_detail(analysis_id: int) -> UTF8JSONResponse:
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        try:
            cur.execute(
                """
                SELECT id, user_id, original_name, risky_count, risk_level, summary, created_at,
                       clauses_json, risky_clauses_json, raw_text
                FROM analysis_history
                WHERE id=%s
                """,
                (analysis_id,),
            )
        except psycopg.Error as exc:
            # Backward-compatible: column might not exist yet.
            if "does not exist" not in str(exc).lower():
                raise
            cur.execute(
                """
                SELECT id, user_id, original_name, risky_count, risk_level, summary, created_at,
                       clauses_json, risky_clauses_json
                FROM analysis_history
                WHERE id=%s
                """,
                (analysis_id,),
            )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Analysis not found")
        clauses_raw = row.pop("clauses_json", None)
        risky_clauses_raw = row.pop("risky_clauses_json", None)
        try:
            if isinstance(clauses_raw, (dict, list)):
                row["clauses"] = clauses_raw
            else:
                row["clauses"] = json.loads(clauses_raw) if clauses_raw else []
        except (TypeError, json.JSONDecodeError):
            row["clauses"] = []
        try:
            if isinstance(risky_clauses_raw, (dict, list)):
                row["risky_clauses"] = risky_clauses_raw
            else:
                row["risky_clauses"] = (
                    json.loads(risky_clauses_raw) if risky_clauses_raw else []
                )
        except (TypeError, json.JSONDecodeError):
            row["risky_clauses"] = []
        raw_text = row.get("raw_text")
        if isinstance(raw_text, str):
            row["raw_text"] = raw_text
        else:
            row["raw_text"] = None
        return UTF8JSONResponse(content=jsonable_encoder(row))
    except HTTPException:
        raise
    except Exception as e:
        print("ANALYSIS DETAIL ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass

@app.get("/files")
def get_files(user_id: int = Query(...)) -> UTF8JSONResponse:
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        cur.execute(
            """
            SELECT id, user_id, original_name, content_type, size_bytes, storage_path, uploaded_at
            FROM user_files
            WHERE user_id=%s
            ORDER BY uploaded_at DESC
            """,
            (user_id,),
        )
        rows = cur.fetchall() or []
        return UTF8JSONResponse(content=jsonable_encoder({"items": rows}))
    except Exception as e:
        print("FILES ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass

@app.get("/analysis/{analysis_id}/clauses/{clause_id}/debate/summary")
def get_clause_debate_summary(analysis_id: str, clause_id: str) -> UTF8JSONResponse:
    entry = _get_entry(analysis_id)
    result = entry["result"]
    clause = _find_clause(result, clause_id)
    if not clause:
        raise HTTPException(status_code=404, detail="Clause not found")
    summary_cache = entry["debate_summary"]
    if clause_id in summary_cache:
        return UTF8JSONResponse(
            content={
                "clause_id": clause_id,
                "article_num": clause.article_num,
                "title": clause.title,
                "summary": summary_cache[clause_id],
            }
        )
    transcript_cache = entry["debate_by_clause"]
    transcript = transcript_cache.get(clause_id)
    if transcript is None:
        transcript = pipeline.debate_agents.run(
            [clause],
            raw_text=result.raw_text,
            contract_type=result.contract_type,
        )
        transcript_cache[clause_id] = transcript
    transcript_text = _format_transcript_text(transcript)
    summary = pipeline.llm_summarizer.generate_debate_summary(transcript_text)
    summary_cache[clause_id] = summary
    return UTF8JSONResponse(
        content={
            "clause_id": clause_id,
            "article_num": clause.article_num,
            "title": clause.title,
            "summary": summary,
        }
    )

@app.get("/analysis/{analysis_id}/clause/{clause_id}")
def get_clause_detail(analysis_id: str, clause_id: str) -> UTF8JSONResponse:
    try:
        entry = _get_entry(analysis_id)
        result = entry["result"]
        clause = _find_clause(result, clause_id)
        if not clause:
            raise HTTPException(status_code=404, detail="Clause not found")
        return UTF8JSONResponse(content=_clause_detail_from_obj(clause))
    except HTTPException as exc:
        if exc.status_code != 404:
            raise
    except Exception:
        raise

    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        cur.execute(
            """
            SELECT clauses_json, risky_clauses_json
            FROM analysis_history
            WHERE id=%s
            """,
            (analysis_id,),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Analysis not found")
        clauses_raw = row.get("clauses_json")
        risky_raw = row.get("risky_clauses_json")
        clauses = []
        try:
            if isinstance(clauses_raw, (dict, list)):
                clauses = clauses_raw
            else:
                clauses = json.loads(clauses_raw) if clauses_raw else []
        except (TypeError, json.JSONDecodeError):
            clauses = []
        risky_clauses = []
        try:
            if isinstance(risky_raw, (dict, list)):
                risky_clauses = risky_raw
            else:
                risky_clauses = json.loads(risky_raw) if risky_raw else []
        except (TypeError, json.JSONDecodeError):
            risky_clauses = []

        normalized_target = _normalize_clause_key(clause_id)

        def matches(target: dict[str, Any]) -> bool:
            raw_id = str(target.get("id", "")).strip()
            article_num = str(target.get("article_num", "")).strip()
            title = str(target.get("title", "")).strip()

            if raw_id and raw_id == clause_id:
                return True
            if article_num and article_num == clause_id:
                return True
            if title and title == clause_id:
                return True

            if normalized_target:
                if raw_id and _normalize_clause_key(raw_id) == normalized_target:
                    return True
                if article_num and _normalize_clause_key(article_num) == normalized_target:
                    return True
                if title and _normalize_clause_key(title) == normalized_target:
                    return True
            return False

        for clause in risky_clauses:
            if isinstance(clause, dict) and matches(clause):
                return UTF8JSONResponse(content=_clause_detail_from_dict(clause))
        for clause in clauses:
            if isinstance(clause, dict) and matches(clause):
                return UTF8JSONResponse(content=_clause_detail_from_dict(clause))

        raise HTTPException(status_code=404, detail="Clause not found")
    except HTTPException:
        raise
    except Exception as e:
        print("CLAUSE DETAIL ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass

@app.get("/analysis/{analysis_id}/clauses/{clause_id}/debate/transcript")
def get_clause_debate_transcript(analysis_id: str, clause_id: str) -> UTF8JSONResponse:
    entry = _get_entry(analysis_id)
    result = entry["result"]
    clause = _find_clause(result, clause_id)
    if not clause:
        raise HTTPException(status_code=404, detail="Clause not found")
    transcript_cache = entry["debate_by_clause"]
    transcript = transcript_cache.get(clause_id)
    if transcript is None:
        transcript = pipeline.debate_agents.run(
            [clause],
            raw_text=result.raw_text,
            contract_type=result.contract_type,
        )
        transcript_cache[clause_id] = transcript
    return UTF8JSONResponse(
        content={
            "clause_id": clause_id,
            "article_num": clause.article_num,
            "title": clause.title,
            "transcript": transcript,
        }
    )
class SignupRequest(BaseModel):
    name: str
    email: EmailStr
    password: str
class LoginRequest(BaseModel):
    email: EmailStr
    password: str
class UpdateProfileRequest(BaseModel):
    email: EmailStr
    name: Optional[str] = None
    password: Optional[str] = None
class ProfileResponse(BaseModel):
    id: int
    name: str
    email: EmailStr
    created_at: datetime
@app.post("/signup")
def signup(req: SignupRequest):
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT id FROM users WHERE email=%s", (req.email,))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Email already exists")
        cur.execute(
            "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
            (req.name, req.email, req.password),
        )
        conn.commit()
        return {"result": "ok"}
    except Exception as e:
        # 🔥 이 줄이 핵심
        print("SIGNUP ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass
@app.post("/login")
def login(req: LoginRequest):
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        cur.execute(
            "SELECT id, name, email, password_hash, created_at FROM users WHERE email=%s",
            (str(req.email),),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        if row.get("password_hash") != req.password:
            raise HTTPException(status_code=401, detail="Invalid credentials")
        return {
            "id": row["id"],
            "name": row["name"],
            "email": row["email"],
            "created_at": row["created_at"],
        }
    except HTTPException:
        raise
    except Exception as e:
        print("LOGIN ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass
@app.get("/profile", response_model=ProfileResponse)
def get_profile(email: EmailStr = Query(...)):
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        cur.execute(
            "SELECT id, name, email, created_at FROM users WHERE email=%s",
            (str(email),),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        return row
    except HTTPException:
        raise
    except Exception as e:
        print("PROFILE ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass
@app.put("/profile", response_model=ProfileResponse)
def update_profile(req: UpdateProfileRequest):
    if not req.name and not req.password:
        raise HTTPException(status_code=400, detail="Nothing to update")
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        updates = []
        params = []
        if req.name:
            updates.append("name=%s")
            params.append(req.name)
        if req.password:
            updates.append("password_hash=%s")
            params.append(req.password)
        params.append(str(req.email))
        cur.execute(
            f"UPDATE users SET {', '.join(updates)} WHERE email=%s",
            tuple(params),
        )
        if cur.rowcount == 0:
            raise HTTPException(status_code=404, detail="User not found")
        conn.commit()
        cur.execute(
            "SELECT id, name, email, created_at FROM users WHERE email=%s",
            (str(req.email),),
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        return row
    except HTTPException:
        raise
    except Exception as e:
        print("PROFILE UPDATE ERROR >>>", repr(e))
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        try:
            if cur is not None:
                cur.close()
            if conn is not None:
                conn.close()
        except Exception:
            pass
