import argparse
import os
import sys
from pathlib import Path

import psycopg
from psycopg.types.json import Json

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from embedding_manager import EmbeddingManager
from law_store import ensure_law_tables
from precedent_store import ensure_precedent_tables


def _get_db_conn():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "app_user"),
        password=os.getenv("DB_PASSWORD", "app_pass"),
        dbname=os.getenv("DB_NAME", "app_db"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )


def _format_vector_literal(vector):
    if not vector:
        return None
    return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"


def _build_precedent_text(row: dict) -> str:
    parts = [
        row.get("case_name"),
        row.get("summary"),
        row.get("key_paragraph"),
    ]
    return "\n".join([p.strip() for p in parts if isinstance(p, str) and p.strip()])


def _build_law_text(row: dict) -> str:
    parts = [
        row.get("title"),
        row.get("summary"),
        row.get("content"),
    ]
    return "\n".join([p.strip() for p in parts if isinstance(p, str) and p.strip()])


def backfill_precedents(limit: int, dry_run: bool = False) -> int:
    ensure_precedent_tables()
    embedder = EmbeddingManager()
    if embedder.api_key == "api필요":
        print("OPENAI_API_KEY is missing.")
        return 0
    conn = _get_db_conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT case_id, case_name, summary, key_paragraph
        FROM precedents
        WHERE embedding IS NULL
        LIMIT %s
        """,
        (limit,),
    )
    rows = cur.fetchall() or []
    updated = 0
    for case_id, case_name, summary, key_paragraph in rows:
        row = {
            "case_name": case_name or "",
            "summary": summary or "",
            "key_paragraph": key_paragraph or "",
        }
        text = _build_precedent_text(row)
        if not text:
            continue
        embedding = embedder.generate_embedding(text)
        if embedding == "api필요":
            break
        if not dry_run:
            cur.execute(
                """
                UPDATE precedents
                SET embedding=%s,
                    embedding_model=%s,
                    embedding_vec=%s::vector,
                    updated_at=CURRENT_TIMESTAMP
                WHERE case_id=%s
                """,
                (Json(embedding), embedder.model, _format_vector_literal(embedding), case_id),
            )
        updated += 1
    if not dry_run:
        conn.commit()
    cur.close()
    conn.close()
    return updated


def backfill_laws(limit: int, dry_run: bool = False) -> int:
    ensure_law_tables()
    embedder = EmbeddingManager()
    if embedder.api_key == "api필요":
        print("OPENAI_API_KEY is missing.")
        return 0
    conn = _get_db_conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT doc_key, title, summary, content
        FROM laws
        WHERE embedding IS NULL
        LIMIT %s
        """,
        (limit,),
    )
    rows = cur.fetchall() or []
    updated = 0
    for doc_key, title, summary, content in rows:
        row = {
            "title": title or "",
            "summary": summary or "",
            "content": content or "",
        }
        text = _build_law_text(row)
        if not text:
            continue
        embedding = embedder.generate_embedding(text)
        if embedding == "api필요":
            break
        if not dry_run:
            cur.execute(
                """
                UPDATE laws
                SET embedding=%s,
                    embedding_model=%s,
                    embedding_vec=%s::vector,
                    updated_at=CURRENT_TIMESTAMP
                WHERE doc_key=%s
                """,
                (Json(embedding), embedder.model, _format_vector_literal(embedding), doc_key),
            )
        updated += 1
    if not dry_run:
        conn.commit()
    cur.close()
    conn.close()
    return updated


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill embeddings for precedents/laws.")
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--targets", default="precedents,laws")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    targets = {t.strip().lower() for t in args.targets.split(",") if t.strip()}
    total = 0
    if "precedents" in targets:
        updated = backfill_precedents(args.limit, dry_run=args.dry_run)
        print(f"precedents updated: {updated}")
        total += updated
    if "laws" in targets:
        updated = backfill_laws(args.limit, dry_run=args.dry_run)
        print(f"laws updated: {updated}")
        total += updated
    return 0 if total >= 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
