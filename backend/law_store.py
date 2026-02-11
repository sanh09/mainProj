import hashlib
import json
import os
from typing import Iterable, List, Optional, Tuple

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Json

from models import Law

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


def ensure_law_tables() -> None:
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector")
        cur.execute(
            f"""
            CREATE TABLE IF NOT EXISTS laws (
                doc_key TEXT PRIMARY KEY,
                doc_type TEXT NOT NULL,
                doc_id TEXT,
                doc_hash TEXT NOT NULL UNIQUE,
                title TEXT,
                summary TEXT,
                content TEXT,
                embedding JSONB,
                embedding_model TEXT,
                embedding_vec vector({EMBEDDING_DIM}),
                date TEXT,
                org TEXT,
                url TEXT,
                search_text TEXT,
                source TEXT DEFAULT 'openapi',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        cur.execute("ALTER TABLE laws ADD COLUMN IF NOT EXISTS embedding JSONB")
        cur.execute("ALTER TABLE laws ADD COLUMN IF NOT EXISTS embedding_model TEXT")
        cur.execute(
            f"ALTER TABLE laws ADD COLUMN IF NOT EXISTS embedding_vec vector({EMBEDDING_DIM})"
        )
        cur.execute(
            """
            CREATE INDEX IF NOT EXISTS laws_embedding_vec_idx
            ON laws USING ivfflat (embedding_vec vector_cosine_ops)
            WITH (lists=100)
            """
        )
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS law_keywords (
                doc_key TEXT NOT NULL,
                keyword TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (doc_key, keyword)
            )
            """
        )
        conn.commit()
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()


def _normalize_doc_key(doc_type: str, doc_id: str, doc_hash: str) -> str:
    doc_type = (doc_type or "").strip()
    doc_id = (doc_id or "").strip()
    if doc_type and doc_id:
        return f"{doc_type}:{doc_id}"
    return f"hash:{doc_hash}"


def _compute_hash(law: Law) -> str:
    blob = "|".join(
        [
            law.doc_type or "",
            law.doc_id or "",
            law.title or "",
            law.summary or "",
            law.content or "",
            law.date or "",
            law.org or "",
        ]
    )
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _build_search_text(law: Law) -> str:
    parts = [
        law.doc_type,
        law.doc_id,
        law.title,
        law.summary,
        law.content,
        law.date,
        law.org,
    ]
    return " ".join([p for p in parts if p]).strip().lower()


def _format_vector_literal(vector: Optional[List[float]]) -> Optional[str]:
    if not vector:
        return None
    return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"


def upsert_laws(laws: Iterable[Law], keywords: Optional[List[str]] = None) -> int:
    items = list(laws)
    if not items:
        return 0

    keywords = [kw.strip().lower() for kw in (keywords or []) if kw and kw.strip()]
    ensure_law_tables()
    conn = None
    cur = None
    inserted = 0
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        for law in items:
            doc_hash = _compute_hash(law)
            doc_key = _normalize_doc_key(law.doc_type, law.doc_id, doc_hash)
            search_text = _build_search_text(law)
            try:
                cur.execute(
                    """
                    INSERT INTO laws
                      (doc_key, doc_type, doc_id, doc_hash, title, summary, content,
                       embedding, embedding_model, embedding_vec, date, org, url, search_text)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::vector, %s, %s, %s, %s)
                    ON CONFLICT (doc_key)
                    DO UPDATE SET
                      doc_type=EXCLUDED.doc_type,
                      doc_id=EXCLUDED.doc_id,
                      doc_hash=EXCLUDED.doc_hash,
                      title=EXCLUDED.title,
                      summary=EXCLUDED.summary,
                      content=EXCLUDED.content,
                      embedding=COALESCE(EXCLUDED.embedding, laws.embedding),
                      embedding_model=COALESCE(EXCLUDED.embedding_model, laws.embedding_model),
                      embedding_vec=COALESCE(EXCLUDED.embedding_vec, laws.embedding_vec),
                      date=EXCLUDED.date,
                      org=EXCLUDED.org,
                      url=EXCLUDED.url,
                      search_text=EXCLUDED.search_text,
                      updated_at=CURRENT_TIMESTAMP
                    """,
                    (
                        doc_key,
                        law.doc_type,
                        law.doc_id,
                        doc_hash,
                        law.title,
                        law.summary,
                        law.content,
                        Json(getattr(law, "embedding", None)),
                        getattr(law, "embedding_model", None),
                        _format_vector_literal(getattr(law, "embedding", None)),
                        law.date,
                        law.org,
                        law.url,
                        search_text,
                    ),
                )
            except psycopg.Error as exc:
                conn.rollback()
                if getattr(exc, "sqlstate", None) != "23505":
                    raise
                cur.execute(
                    """
                    UPDATE laws
                    SET doc_key=%s,
                        doc_type=%s,
                        doc_id=%s,
                        title=%s,
                        summary=%s,
                        content=%s,
                        embedding=COALESCE(%s, laws.embedding),
                        embedding_model=COALESCE(%s, laws.embedding_model),
                        embedding_vec=COALESCE(%s::vector, laws.embedding_vec),
                        date=%s,
                        org=%s,
                        url=%s,
                        search_text=%s,
                        updated_at=CURRENT_TIMESTAMP
                    WHERE doc_hash=%s
                    """,
                    (
                        doc_key,
                        law.doc_type,
                        law.doc_id,
                        law.title,
                        law.summary,
                        law.content,
                        Json(getattr(law, "embedding", None)),
                        getattr(law, "embedding_model", None),
                        _format_vector_literal(getattr(law, "embedding", None)),
                        law.date,
                        law.org,
                        law.url,
                        search_text,
                        doc_hash,
                    ),
                )
            inserted += 1
            if keywords:
                for keyword in keywords:
                    cur.execute(
                        """
                        INSERT INTO law_keywords (doc_key, keyword)
                        VALUES (%s, %s)
                        ON CONFLICT (doc_key, keyword) DO NOTHING
                        """,
                        (doc_key, keyword),
                    )
        conn.commit()
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()
    return inserted


def search_laws(keyword: str, limit: int = 20) -> List[Law]:
    normalized = (keyword or "").strip().lower()
    if not normalized:
        return []

    ensure_law_tables()
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
            SELECT doc_type, doc_id, title, summary, content, date, org, url,
                   embedding, embedding_model
            FROM laws
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

    laws: List[Law] = []
    for row in rows:
        law = Law(
            doc_id=str(row.get("doc_id", "")),
            doc_type=str(row.get("doc_type", "")),
            title=str(row.get("title", "")),
            summary=str(row.get("summary", "")),
            content=str(row.get("content", "")),
            date=str(row.get("date", "")),
            org=str(row.get("org", "")),
            url=str(row.get("url", "")),
        )
        embedding = row.get("embedding")
        if embedding:
            if isinstance(embedding, str):
                try:
                    embedding = json.loads(embedding)
                except json.JSONDecodeError:
                    embedding = None
            if isinstance(embedding, list):
                setattr(law, "embedding", embedding)
        embedding_model = row.get("embedding_model")
        if embedding_model:
            setattr(law, "embedding_model", str(embedding_model))
        laws.append(law)
    return laws


def search_laws_by_vector(embedding: List[float], limit: int = 5) -> List[Law]:
    if not embedding:
        return []
    ensure_law_tables()
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
            SELECT doc_type, doc_id, title, summary, content, date, org, url,
                   embedding, embedding_model
            FROM laws
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

    laws: List[Law] = []
    for row in rows:
        law = Law(
            doc_id=str(row.get("doc_id", "")),
            doc_type=str(row.get("doc_type", "")),
            title=str(row.get("title", "")),
            summary=str(row.get("summary", "")),
            content=str(row.get("content", "")),
            date=str(row.get("date", "")),
            org=str(row.get("org", "")),
            url=str(row.get("url", "")),
        )
        embedding_val = row.get("embedding")
        if embedding_val:
            if isinstance(embedding_val, str):
                try:
                    embedding_val = json.loads(embedding_val)
                except json.JSONDecodeError:
                    embedding_val = None
            if isinstance(embedding_val, list):
                setattr(law, "embedding", embedding_val)
        embedding_model = row.get("embedding_model")
        if embedding_model:
            setattr(law, "embedding_model", str(embedding_model))
        laws.append(law)
    return laws
