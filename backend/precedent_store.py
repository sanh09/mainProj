import hashlib
import json
import os
from typing import Iterable, List, Optional

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Json

from models import Precedent

EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))


def _get_db_conn():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "app_user"),
        password=os.getenv("DB_PASSWORD", "app_pass"),
        dbname=os.getenv("DB_NAME", "app_db"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )


def ensure_precedent_tables() -> None:
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
        cur.execute(
            f"""
            CREATE TABLE IF NOT EXISTS precedents (
                case_id TEXT PRIMARY KEY,
                case_hash TEXT NOT NULL UNIQUE,
                court TEXT,
                date TEXT,
                case_name TEXT,
                summary TEXT,
                key_paragraph TEXT,
                embedding JSONB,
                embedding_model TEXT,
                embedding_vec vector({EMBEDDING_DIM}),
                search_text TEXT,
                source TEXT DEFAULT 'openapi',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        cur.execute("ALTER TABLE precedents ADD COLUMN IF NOT EXISTS embedding JSONB")
        cur.execute("ALTER TABLE precedents ADD COLUMN IF NOT EXISTS embedding_model TEXT")
        cur.execute(
            f"ALTER TABLE precedents ADD COLUMN IF NOT EXISTS embedding_vec vector({EMBEDDING_DIM})"
        )
        cur.execute(
            """
            CREATE INDEX IF NOT EXISTS precedents_embedding_vec_idx
            ON precedents USING ivfflat (embedding_vec vector_cosine_ops)
            WITH (lists=100)
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS precedent_keywords (
                case_id TEXT NOT NULL,
                keyword TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (case_id, keyword)
            )
            """
        )
        conn.commit()
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()


def _normalize_case_id(case_id: str, case_hash: str) -> str:
    cleaned = (case_id or "").strip()
    if cleaned:
        return cleaned
    return f"hash:{case_hash}"


def _compute_hash(precedent: Precedent) -> str:
    blob = "|".join(
        [
            precedent.case_id or "",
            precedent.court or "",
            precedent.date or "",
            precedent.case_name or "",
            precedent.summary or "",
            precedent.key_paragraph or "",
        ]
    )
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _build_search_text(precedent: Precedent) -> str:
    parts = [
        precedent.case_id,
        precedent.court,
        precedent.date,
        precedent.case_name,
        precedent.summary,
        precedent.key_paragraph,
    ]
    return " ".join([p for p in parts if p]).strip().lower()


def _format_vector_literal(vector: Optional[List[float]]) -> Optional[str]:
    if not vector:
        return None
    return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"


def upsert_precedents(
    precedents: Iterable[Precedent],
    keywords: Optional[List[str]] = None,
) -> int:
    items = list(precedents)
    if not items:
        return 0

    keywords = [kw.strip().lower() for kw in (keywords or []) if kw and kw.strip()]
    ensure_precedent_tables()
    conn = None
    cur = None
    inserted = 0
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        for precedent in items:
            case_hash = _compute_hash(precedent)
            case_id = _normalize_case_id(precedent.case_id, case_hash)
            search_text = _build_search_text(precedent)
            try:
                cur.execute(
                    """
                    INSERT INTO precedents
                      (case_id, case_hash, court, date, case_name, summary, key_paragraph,
                       embedding, embedding_model, embedding_vec, search_text)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::vector, %s)
                    ON CONFLICT (case_id)
                    DO UPDATE SET
                      case_hash=EXCLUDED.case_hash,
                      court=EXCLUDED.court,
                      date=EXCLUDED.date,
                      case_name=EXCLUDED.case_name,
                      summary=EXCLUDED.summary,
                      key_paragraph=EXCLUDED.key_paragraph,
                      embedding=COALESCE(EXCLUDED.embedding, precedents.embedding),
                      embedding_model=COALESCE(EXCLUDED.embedding_model, precedents.embedding_model),
                      embedding_vec=COALESCE(EXCLUDED.embedding_vec, precedents.embedding_vec),
                      search_text=EXCLUDED.search_text,
                      updated_at=CURRENT_TIMESTAMP
                    """,
                    (
                        case_id,
                        case_hash,
                        precedent.court,
                        precedent.date,
                        precedent.case_name,
                        precedent.summary,
                        precedent.key_paragraph,
                        Json(getattr(precedent, "embedding", None)),
                        getattr(precedent, "embedding_model", None),
                        _format_vector_literal(getattr(precedent, "embedding", None)),
                        search_text,
                    ),
                )
            except psycopg.Error as exc:
                conn.rollback()
                if getattr(exc, "sqlstate", None) != "23505":
                    raise
                cur.execute(
                    """
                    UPDATE precedents
                    SET case_id=%s,
                        court=%s,
                        date=%s,
                        case_name=%s,
                        summary=%s,
                        key_paragraph=%s,
                        embedding=COALESCE(%s, precedents.embedding),
                        embedding_model=COALESCE(%s, precedents.embedding_model),
                        embedding_vec=COALESCE(%s::vector, precedents.embedding_vec),
                        search_text=%s,
                        updated_at=CURRENT_TIMESTAMP
                    WHERE case_hash=%s
                    """,
                    (
                        case_id,
                        precedent.court,
                        precedent.date,
                        precedent.case_name,
                        precedent.summary,
                        precedent.key_paragraph,
                        Json(getattr(precedent, "embedding", None)),
                        getattr(precedent, "embedding_model", None),
                        _format_vector_literal(getattr(precedent, "embedding", None)),
                        search_text,
                        case_hash,
                    ),
                )
            inserted += 1
            if keywords:
                for keyword in keywords:
                    cur.execute(
                        """
                        INSERT INTO precedent_keywords (case_id, keyword)
                        VALUES (%s, %s)
                        ON CONFLICT (case_id, keyword) DO NOTHING
                        """,
                        (case_id, keyword),
                    )
        conn.commit()
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()
    return inserted


def search_precedents(keyword: str, limit: int = 20) -> List[Precedent]:
    normalized = (keyword or "").strip().lower()
    if not normalized:
        return []

    ensure_precedent_tables()
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        tokens = [t for t in normalized.replace(",", " ").split() if t][:5]
        if not tokens:
            return []
        like_clauses = []
        params: List[str] = []
        for token in tokens:
            like_clauses.append("search_text LIKE %s")
            params.append(f"%{token}%")
        where_sql = " OR ".join(like_clauses)
        cur.execute(
            f"""
            SELECT case_id, court, date, case_name, summary, key_paragraph,
                   embedding, embedding_model
            FROM precedents
            WHERE {where_sql}
            ORDER BY updated_at DESC
            LIMIT %s
            """,
            (*params, limit),
        )
        rows = cur.fetchall() or []
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()

    precedents: List[Precedent] = []
    for row in rows:
        precedent = Precedent(
            case_id=str(row.get("case_id", "")),
            court=str(row.get("court", "")),
            date=str(row.get("date", "")),
            case_name=str(row.get("case_name", "")),
            summary=str(row.get("summary", "")),
            key_paragraph=str(row.get("key_paragraph", "")),
        )
        embedding = row.get("embedding")
        if embedding:
            if isinstance(embedding, str):
                try:
                    embedding = json.loads(embedding)
                except json.JSONDecodeError:
                    embedding = None
            if isinstance(embedding, list):
                setattr(precedent, "embedding", embedding)
        embedding_model = row.get("embedding_model")
        if embedding_model:
            setattr(precedent, "embedding_model", str(embedding_model))
        precedents.append(precedent)
    return precedents


def search_precedents_by_vector(embedding: List[float], limit: int = 5) -> List[Precedent]:
    if not embedding:
        return []
    ensure_precedent_tables()
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor(row_factory=dict_row)
        vector_literal = _format_vector_literal(embedding)
        if not vector_literal:
            return []
        cur.execute(
            """
            SELECT case_id, court, date, case_name, summary, key_paragraph,
                   embedding, embedding_model
            FROM precedents
            WHERE embedding_vec IS NOT NULL
            ORDER BY embedding_vec <-> %s::vector
            LIMIT %s
            """,
            (vector_literal, limit),
        )
        rows = cur.fetchall() or []
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()

    precedents: List[Precedent] = []
    for row in rows:
        precedent = Precedent(
            case_id=str(row.get("case_id", "")),
            court=str(row.get("court", "")),
            date=str(row.get("date", "")),
            case_name=str(row.get("case_name", "")),
            summary=str(row.get("summary", "")),
            key_paragraph=str(row.get("key_paragraph", "")),
        )
        embedding_val = row.get("embedding")
        if embedding_val:
            if isinstance(embedding_val, str):
                try:
                    embedding_val = json.loads(embedding_val)
                except json.JSONDecodeError:
                    embedding_val = None
            if isinstance(embedding_val, list):
                setattr(precedent, "embedding", embedding_val)
        embedding_model = row.get("embedding_model")
        if embedding_model:
            setattr(precedent, "embedding_model", str(embedding_model))
        precedents.append(precedent)
    return precedents
