import argparse
import os
import sys
import time
from pathlib import Path
from typing import Iterable, List

import psycopg

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from law_fetcher import LawFetcher
from law_store import ensure_law_tables
from precedent_fetcher import PrecedentFetcher
from precedent_store import ensure_precedent_tables


DEFAULT_KEYWORD_FILE = Path(__file__).with_name("data").joinpath(
    "precedent_keywords_toxic.txt"
)


def _get_db_conn():
    return psycopg.connect(
        host=os.getenv("DB_HOST", "db"),
        port=int(os.getenv("DB_PORT", "5432")),
        user=os.getenv("DB_USER", "app_user"),
        password=os.getenv("DB_PASSWORD", "app_pass"),
        dbname=os.getenv("DB_NAME", "app_db"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )


def _count_precedents() -> int:
    ensure_precedent_tables()
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM precedents")
        row = cur.fetchone()
        return int(row[0]) if row else 0
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()


def _count_laws() -> int:
    ensure_law_tables()
    conn = None
    cur = None
    try:
        conn = _get_db_conn()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM laws")
        row = cur.fetchone()
        return int(row[0]) if row else 0
    finally:
        if cur is not None:
            cur.close()
        if conn is not None:
            conn.close()


def _normalize_keywords(lines: Iterable[str]) -> List[str]:
    keywords: List[str] = []
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "," in line:
            parts = [p.strip() for p in line.split(",") if p.strip()]
            keywords.extend(parts)
        else:
            keywords.append(line)
    deduped = []
    seen = set()
    for kw in keywords:
        key = kw.strip()
        if not key or key in seen:
            continue
        seen.add(key)
        deduped.append(key)
    return deduped


def _load_keywords(path: Path) -> List[str]:
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    return _normalize_keywords(text.splitlines())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Seed precedents DB with toxic-clause-focused keywords."
    )
    parser.add_argument(
        "--keywords-file",
        default=str(DEFAULT_KEYWORD_FILE),
        help="Path to keyword list (one per line or comma-separated).",
    )
    parser.add_argument(
        "--max-count",
        type=int,
        default=int(os.getenv("PRECEDENT_SEED_TARGET", "30000")),
        help="Stop when precedents count reaches this number.",
    )
    parser.add_argument(
        "--law-max-count",
        type=int,
        default=int(os.getenv("LAW_SEED_TARGET", "0")),
        help="Optional stop target for laws (0 = ignore).",
    )
    parser.add_argument(
        "--max-keywords",
        type=int,
        default=0,
        help="Process only the first N keywords (0 = all).",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=float(os.getenv("PRECEDENT_SEED_SLEEP", "0")),
        help="Sleep seconds between keyword fetches.",
    )
    parser.add_argument(
        "--include-laws",
        action="store_true",
        help="Also fetch laws for each keyword.",
    )
    parser.add_argument(
        "--shuffle",
        action="store_true",
        help="Shuffle keywords before fetching.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print plan without fetching.",
    )
    args = parser.parse_args()

    keyword_path = Path(args.keywords_file)
    keywords = _load_keywords(keyword_path)
    if not keywords:
        print(f"No keywords found: {keyword_path}")
        return 1

    if args.shuffle:
        import random

        random.shuffle(keywords)

    if args.max_keywords and args.max_keywords > 0:
        keywords = keywords[: args.max_keywords]

    fetcher = PrecedentFetcher()
    fetcher.prefer_db = False
    law_fetcher = None
    if args.include_laws:
        law_fetcher = LawFetcher()
        law_fetcher.prefer_db = False

    total_start = _count_precedents()
    laws_start = _count_laws() if law_fetcher else None
    target = args.max_count
    law_target = args.law_max_count
    print(f"Start count: {total_start} / target={target}")
    if law_fetcher is not None:
        print(f"Start laws: {laws_start} / target={law_target or 'ignore'}")
    print(f"Keywords: {len(keywords)}")

    if args.dry_run:
        return 0

    for idx, keyword in enumerate(keywords, start=1):
        current = _count_precedents()
        if target and current >= target:
            print(f"Target reached: {current}")
            break
        if law_fetcher is not None and law_target:
            current_laws = _count_laws()
            if current_laws >= law_target:
                print(f"Law target reached: {current_laws}")
                break
        t0 = time.perf_counter()
        result = fetcher.fetch_precedents(keyword)
        fetched = len(result) if isinstance(result, list) else 0
        law_fetched = 0
        if law_fetcher is not None:
            laws = law_fetcher.fetch_laws(keyword)
            law_fetched = len(laws) if isinstance(laws, list) else 0
        after = _count_precedents()
        after_laws = _count_laws() if law_fetcher else None
        added = after - current
        elapsed = time.perf_counter() - t0
        if law_fetcher is None:
            print(
                f"[{idx}/{len(keywords)}] {keyword} fetched={fetched} "
                f"added={added} total={after} ({elapsed:.2f}s)"
            )
        else:
            print(
                f"[{idx}/{len(keywords)}] {keyword} "
                f"precedents={fetched} added={added} total={after} "
                f"laws={law_fetched} law_total={after_laws} ({elapsed:.2f}s)"
            )
        if args.sleep > 0:
            time.sleep(args.sleep)

    final_count = _count_precedents()
    if law_fetcher is None:
        print(f"Done. Final count: {final_count}")
    else:
        final_laws = _count_laws()
        print(f"Done. Final precedents: {final_count} / laws: {final_laws}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
