import os
import re
from typing import List, Optional

try:
    import requests
except ImportError as exc:
    raise ImportError(
        "필수 패키지가 없습니다: requests. `pip install requests`로 설치하세요."
    ) from exc

from models import Law
from law_store import search_laws, upsert_laws


class LawFetcher:
    def __init__(
        self,
        api_url: str | None = None,
        api_key: str | None = None,
        targets: Optional[List[str]] = None,
    ) -> None:
        self.api_url = (
            api_url
            or os.getenv("LAW_API_URL")
            or os.getenv("PRECEDENT_API_URL")
            or ""
        )
        self.api_key = (
            api_key or os.getenv("LAW_API_KEY") or os.getenv("PRECEDENT_API_KEY") or "api필요"
        )
        target_env = os.getenv("LAW_TARGETS") or "law,admrul,ordin"
        self.targets = targets or [t.strip() for t in target_env.split(",") if t.strip()]
        self.detail_limit = int(os.getenv("LAW_DETAIL_LIMIT") or "10")
        self.max_text_chars = int(os.getenv("LAW_DETAIL_TEXT_LIMIT") or "4000")
        self.prefer_db = os.getenv("LAW_PREFER_DB", "true").lower() in (
            "1",
            "true",
            "yes",
            "y",
        )
        self.db_limit = int(os.getenv("LAW_DB_LIMIT") or "20")
        self.page_size = int(os.getenv("LAW_PAGE_SIZE") or "20")
        self.max_pages = int(os.getenv("LAW_MAX_PAGES") or "5")

    def fetch_laws(self, keyword: str, targets: Optional[List[str]] = None) -> List[Law] | str:
        db_only = os.getenv("LAW_DB_ONLY", "false").lower() in (
            "1",
            "true",
            "yes",
            "y",
        )
        if db_only:
            return search_laws(keyword, limit=self.db_limit) or []
        include_terms = self._get_include_terms()
        must_title_terms = self._get_must_title_terms()
        base_query = self._get_base_query()
        if self.prefer_db:
            cached = search_laws(keyword, limit=self.db_limit)
            if cached:
                return cached
                if db_only:
                    return []
        if self.api_key == "api필요":
            return "api필요"
        if not self.api_url:
            return []
        use_targets = targets or self.targets or ["law"]
        laws: List[Law] = []
        if "law" in use_targets:
            if base_query:
                laws.extend(self._search_target("law", base_query))
            if keyword and keyword != base_query:
                laws.extend(self._search_target("law", keyword))
        remaining_targets = [t for t in use_targets if t != "law"]
        if not laws and remaining_targets:
            for target in remaining_targets:
                laws.extend(self._search_target(target, keyword))
        laws = self._dedupe_laws(laws)
        laws = self._filter_by_terms(laws, include_terms, must_title_terms)
        laws = self._dedupe_laws(laws)
        self._hydrate_law_details(laws)
        detailed = [
            law
            for law in laws
            if (law.summary and law.summary.strip()) or (law.content and law.content.strip())
        ]
        final_items = detailed or laws
        if final_items:
            upsert_laws(final_items, keywords=[keyword])
        return final_items

    def _search_target(self, target: str, keyword: str) -> List[Law]:
        laws: List[Law] = []
        seen_keys = set()
        for page in range(1, max(self.max_pages, 1) + 1):
            response = requests.get(
                self.api_url,
                params={
                    "OC": self.api_key,
                    "target": target,
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
            items = self._extract_items(payload, target)
            if not items:
                break
            for item in items:
                if not isinstance(item, dict):
                    continue
                law = self._build_law_from_item(target, item)
                key = (law.doc_type, law.doc_id, law.title)
                if key in seen_keys:
                    continue
                seen_keys.add(key)
                laws.append(law)
        return laws

    def _build_law_from_item(self, target: str, item: dict) -> Law:
        if target == "law":
            doc_id = self._get_first(item, ["법령ID", "법령일련번호", "ID", "MST"])
            title = self._get_first(item, ["법령명한글", "법령명", "법령명약칭", "법령약칭명"])
            date = self._get_first(item, ["시행일자", "공포일자"])
            org = self._get_first(item, ["소관부처명", "소관부처"])
            url = self._get_first(item, ["법령상세링크", "법령링크", "법령상세"])
        elif target == "admrul":
            doc_id = self._get_first(item, ["행정규칙ID", "행정규칙일련번호", "ID", "MST"])
            title = self._get_first(item, ["행정규칙명", "규칙명"])
            date = self._get_first(item, ["발령일자", "시행일자", "공포일자"])
            org = self._get_first(item, ["소관부처명", "발령기관명", "소관부처"])
            url = self._get_first(item, ["행정규칙상세링크", "행정규칙링크", "행정규칙상세"])
        else:
            doc_id = self._get_first(item, ["자치법규ID", "자치법규일련번호", "ID", "MST"])
            title = self._get_first(item, ["자치법규명", "자치규칙명", "규칙명"])
            date = self._get_first(item, ["시행일자", "공포일자", "발령일자"])
            org = self._get_first(item, ["지방자치단체명", "자치단체명", "소관부처명"])
            url = self._get_first(item, ["자치법규상세링크", "자치법규링크", "자치법규상세"])

        return Law(
            doc_id=str(doc_id or ""),
            doc_type=target,
            title=str(title or ""),
            summary=str(item.get("제개정구분명", "") or ""),
            content="",
            date=str(date or ""),
            org=str(org or ""),
            url=str(url or ""),
        )

    def _extract_items(self, payload: dict, target: str) -> List[dict]:
        search_keys = [
            f"{target.capitalize()}Search",
            f"{target}Search",
            f"{target.upper()}Search",
            "LawSearch",
            "AdmrulSearch",
            "OrdinSearch",
        ]
        for key in search_keys:
            section = payload.get(key)
            if not isinstance(section, dict):
                continue
            for item_key in {target, target.lower(), target.upper(), "law", "admrul", "ordin"}:
                items = section.get(item_key)
                if isinstance(items, list):
                    return items
        for value in payload.values():
            if isinstance(value, dict):
                for nested in value.values():
                    if isinstance(nested, list):
                        return nested
        return []

    def _detail_base_url(self) -> str:
        if not self.api_url:
            return "https://www.law.go.kr/DRF/lawService.do"
        if "lawSearch.do" in self.api_url:
            return self.api_url.replace("lawSearch.do", "lawService.do")
        return self.api_url.rstrip("/") + "/lawService.do"

    def _fetch_law_detail(self, target: str, doc_id: str) -> Optional[dict]:
        if not doc_id:
            return None
        response = requests.get(
            self._detail_base_url(),
            params={"OC": self.api_key, "target": target, "type": "JSON", "ID": doc_id},
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
        return payload

    def _hydrate_law_details(self, laws: List[Law]) -> None:
        if self.detail_limit <= 0:
            return
        for law in laws[: self.detail_limit]:
            if law.content and law.content.strip():
                continue
            detail = self._fetch_law_detail(law.doc_type, law.doc_id)
            if not detail:
                continue
            detail_text = self._extract_detail_text(detail)
            if detail_text:
                law.content = detail_text

    def _extract_detail_text(self, payload: dict) -> str:
        texts: List[str] = []

        def walk(obj: object) -> None:
            if isinstance(obj, dict):
                for key, value in obj.items():
                    if key in {
                        "조문내용",
                        "내용",
                        "본문",
                        "조문제목",
                        "법령명",
                        "법령명한글",
                        "행정규칙명",
                        "자치법규명",
                        "규칙명",
                    } and isinstance(value, str):
                        texts.append(value)
                    else:
                        walk(value)
            elif isinstance(obj, list):
                for item in obj:
                    walk(item)

        walk(payload)
        merged = "\n".join([t.strip() for t in texts if t and t.strip()])
        merged = self._clean_text(merged)
        if self.max_text_chars > 0 and len(merged) > self.max_text_chars:
            return merged[: self.max_text_chars]
        return merged

    @staticmethod
    def _get_include_terms() -> List[str]:
        raw = os.getenv("LAW_DOMAIN_KEYWORDS") or ""
        return [term.strip() for term in raw.split(",") if term.strip()]

    @staticmethod
    def _get_must_title_terms() -> List[str]:
        raw = os.getenv("LAW_TITLE_MUST_KEYWORDS") or ""
        return [term.strip() for term in raw.split(",") if term.strip()]

    @staticmethod
    def _get_base_query() -> str:
        return (os.getenv("LAW_BASE_QUERY") or "").strip()

    @staticmethod
    def _filter_by_terms(
        laws: List[Law], terms: List[str], must_title_terms: Optional[List[str]] = None
    ) -> List[Law]:
        if not terms and not must_title_terms:
            return laws
        filtered: List[Law] = []
        for law in laws:
            title = law.title or ""
            text = " ".join([title, law.summary or "", law.content or ""])
            if must_title_terms:
                if not any(term in title for term in must_title_terms):
                    continue
            if terms and not any(term in text for term in terms):
                continue
            filtered.append(law)
        return filtered

    @staticmethod
    def _dedupe_laws(laws: List[Law]) -> List[Law]:
        seen = set()
        unique: List[Law] = []
        for law in laws:
            doc_id = (law.doc_id or "").strip()
            title = (law.title or "").strip()
            title_key = re.sub(r"\\s+", "", title)
            if not doc_id:
                key = (law.doc_type, title_key)
            else:
                key = (law.doc_type, doc_id)
            if key in seen:
                continue
            seen.add(key)
            unique.append(law)
        return unique

    @staticmethod
    def _clean_text(text: str) -> str:
        text = re.sub(r"<br\\s*/?>", "\n", text, flags=re.IGNORECASE)
        text = re.sub(r"<[^>]+>", "", text)
        return text.strip()

    @staticmethod
    def _get_first(item: dict, keys: List[str]) -> str:
        for key in keys:
            value = item.get(key)
            if value is None:
                continue
            value = str(value).strip()
            if value:
                return value
        return ""
