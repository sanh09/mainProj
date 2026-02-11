import argparse
import os
import sys
from pathlib import Path
from typing import List

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from law_fetcher import LawFetcher
from precedent_fetcher import PrecedentFetcher


def _split_keywords(raw: str) -> List[str]:
    if not raw:
        return []
    return [kw.strip() for kw in raw.split(",") if kw.strip()]


def _get_keywords(args_keywords: str) -> List[str]:
    if args_keywords:
        return _split_keywords(args_keywords)
    env_keywords = os.getenv("REFERENCE_REFRESH_KEYWORDS") or os.getenv("LAW_DOMAIN_KEYWORDS") or ""
    return _split_keywords(env_keywords)


def main() -> int:
    parser = argparse.ArgumentParser(description="Refresh precedent/law cache from OpenAPI.")
    parser.add_argument(
        "--keywords",
        help="Comma-separated keywords (overrides REFERENCE_REFRESH_KEYWORDS).",
        default="",
    )
    args = parser.parse_args()

    keywords = _get_keywords(args.keywords)
    if not keywords:
        print("No keywords provided. Set REFERENCE_REFRESH_KEYWORDS or pass --keywords.")
        return 1

    precedent_fetcher = PrecedentFetcher()
    law_fetcher = LawFetcher()
    precedent_fetcher.prefer_db = False
    law_fetcher.prefer_db = False

    for keyword in keywords:
        precedents = precedent_fetcher.fetch_precedents(keyword)
        laws = law_fetcher.fetch_laws(keyword)
        prec_count = len(precedents) if isinstance(precedents, list) else 0
        law_count = len(laws) if isinstance(laws, list) else 0
        print(f"[{keyword}] precedents={prec_count} laws={law_count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
