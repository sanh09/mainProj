import os
from typing import List, Optional

try:
    import requests
except ImportError as exc:
    raise ImportError(
        "필수 패키지가 없습니다: requests. `pip install requests`로 설치하세요."
    ) from exc

from models import Precedent
from precedent_store import search_precedents, upsert_precedents


class PrecedentFetcher:
    def __init__(self, api_url: str | None = None, api_key: str | None = None) -> None:
        self.api_url = api_url or os.getenv("PRECEDENT_API_URL") or ""
        self.api_key = api_key or os.getenv("PRECEDENT_API_KEY") or "api필요"
        self.detail_limit = int(os.getenv("PRECEDENT_DETAIL_LIMIT") or "10")
        self._local_store: List[Precedent] = []
        self.prefer_db = os.getenv("PRECEDENT_PREFER_DB", "true").lower() in (
            "1",
            "true",
            "yes",
            "y",
        )
        self.db_limit = int(os.getenv("PRECEDENT_DB_LIMIT") or "20")
        self.page_size = int(os.getenv("PRECEDENT_PAGE_SIZE") or "20")
        self.max_pages = int(os.getenv("PRECEDENT_MAX_PAGES") or "5")

    def fetch_precedents(self, keyword: str) -> List[Precedent] | str:
        if self.prefer_db:
            cached = search_precedents(keyword, limit=self.db_limit)
            if cached:
                return cached
        if self.api_key == "api필요":
            return "api필요"
        if not self.api_url:
            return []
        precedents: List[Precedent] = []
        seen_ids = set()
        for page in range(1, max(self.max_pages, 1) + 1):
            response = requests.get(
                self.api_url,
                params={
                    "OC": self.api_key,
                    "target": "prec",
                    "type": "JSON",
                    "query": keyword,
                    "page": page,
                    "display": self.page_size,
                },
                timeout=30,
            )
            try:
                response.raise_for_status()
            except requests.HTTPError:
                break
            try:
                payload = response.json() or {}
            except ValueError:
                break
            items = payload.get("PrecSearch", {}).get("prec", []) or []
            if not items:
                break
            for item in items:
                if not isinstance(item, dict):
                    continue
                case_id = str(item.get("판례일련번호", "")) or ""
                if case_id and case_id in seen_ids:
                    continue
                seen_ids.add(case_id)
                precedents.append(
                    Precedent(
                        case_id=case_id,
                        court=str(item.get("법원명", "")),
                        date=str(item.get("선고일자", "")),
                        case_name=str(item.get("사건명", "")),
                        summary=str(item.get("판시사항", "")),
                        key_paragraph=str(item.get("판결요지", "")),
                    )
                )
        self._hydrate_precedent_details(precedents)
        detailed = [
            p
            for p in precedents
            if (p.summary and p.summary.strip()) or (p.key_paragraph and p.key_paragraph.strip())
        ]
        final_items = detailed or precedents
        if final_items:
            upsert_precedents(final_items, keywords=[keyword])
        return final_items

    def _detail_base_url(self) -> str:
        if not self.api_url:
            return "https://www.law.go.kr/DRF/lawService.do"
        if "lawSearch.do" in self.api_url:
            return self.api_url.replace("lawSearch.do", "lawService.do")
        return self.api_url.rstrip("/") + "/lawService.do"

    def _fetch_precedent_detail(self, case_id: str) -> Optional[dict]:
        if not case_id:
            return None
        response = requests.get(
            self._detail_base_url(),
            params={"OC": self.api_key, "target": "prec", "type": "JSON", "ID": case_id},
            timeout=30,
        )
        try:
            response.raise_for_status()
        except requests.HTTPError:
            return None
        try:
            payload = response.json() or {}
        except ValueError:
            return None
        return payload.get("PrecService") or payload.get("PrecSearch") or None

    def _hydrate_precedent_details(self, precedents: List[Precedent]) -> None:
        if self.detail_limit <= 0:
            return
        for precedent in precedents[: self.detail_limit]:
            if precedent.summary and precedent.key_paragraph:
                continue
            detail = self._fetch_precedent_detail(precedent.case_id)
            if not detail:
                continue
            precedent.case_name = precedent.case_name or str(detail.get("사건명", ""))
            precedent.court = precedent.court or str(detail.get("법원명", ""))
            precedent.date = precedent.date or str(detail.get("선고일자", ""))
            precedent.summary = precedent.summary or str(detail.get("판시사항", ""))
            precedent.key_paragraph = precedent.key_paragraph or str(detail.get("판결요지", ""))

    def get_precedents_by_keyword(self, keyword: str) -> List[Precedent]:
        return [p for p in self._local_store if keyword in p.keywords]

    def add_precedent(self, precedent: Precedent) -> None:
        self._local_store.append(precedent)
