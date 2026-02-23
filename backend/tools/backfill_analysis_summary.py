import argparse
import json
import os
import sys
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from llm_summarizer import LLMSummarizer


def _get_db_conn():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "app_user"),
        password=os.getenv("DB_PASSWORD", "app_pass"),
        dbname=os.getenv("DB_NAME", "app_db"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )


def _build_summary_input(row: dict, max_clauses: int, max_chars: int) -> str:
    clauses = row.get("risky_clauses_json") or row.get("clauses_json") or []
    if isinstance(clauses, str):
        try:
            clauses = json.loads(clauses) or []
        except json.JSONDecodeError:
            clauses = []
    parts = []
    for clause in clauses[:max_clauses]:
        if not isinstance(clause, dict):
            continue
        article = str(clause.get("article_num") or clause.get("article") or "").strip()
        title = str(clause.get("title") or clause.get("name") or "").strip()
        content = str(clause.get("content") or clause.get("body") or clause.get("text") or "").strip()
        header = f"{article} {title}".strip()
        body = f"{header}\n{content}" if header else content
        if body.strip():
            parts.append(body.strip())
    text = "\n\n".join(parts).strip()
    if not text:
        raw_text = row.get("raw_text") or ""
        if isinstance(raw_text, str):
            text = raw_text.strip()
    if max_chars > 0 and len(text) > max_chars:
        text = text[:max_chars]
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill analysis_history.summary with LLM summary.")
    parser.add_argument("--limit", type=int, default=200)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    max_clauses = int(os.getenv("SUMMARY_MAX_CLAUSES", "12"))
    max_chars = int(os.getenv("SUMMARY_MAX_CHARS", "6000"))

    summarizer = LLMSummarizer()
    if summarizer.api_key == "api필요":
        print("OPENAI_API_KEY is missing.")
        return 1

    conn = _get_db_conn()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT id, clauses_json, risky_clauses_json, raw_text
        FROM analysis_history
        WHERE summary IS NULL OR summary = ''
        ORDER BY id DESC
        LIMIT %s
        """,
        (args.limit,),
    )
    rows = cur.fetchall() or []
    updated = 0
    for row in rows:
        row_id, clauses_json, risky_clauses_json, raw_text = row
        summary_input = _build_summary_input(
            {
                "clauses_json": clauses_json,
                "risky_clauses_json": risky_clauses_json,
                "raw_text": raw_text,
            },
            max_clauses=max_clauses,
            max_chars=max_chars,
        )
        if not summary_input:
            continue
        summary = summarizer.generate_summary(summary_input)
        if not summary:
            continue
        if not args.dry_run:
            cur.execute(
                "UPDATE analysis_history SET summary=%s WHERE id=%s",
                (summary, row_id),
            )
        updated += 1
    if not args.dry_run:
        conn.commit()
    cur.close()
    conn.close()

    print(f"updated: {updated}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
