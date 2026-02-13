import json
import os
import re
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional, Tuple

from models import Clause, RiskType


class RiskAssessor:
    _RISK_VALUE_MAP = {
        "critical": RiskType.CRITICAL,
        "매우높음": RiskType.CRITICAL,
        "매우 높음": RiskType.CRITICAL,
        "치명": RiskType.CRITICAL,
        "high": RiskType.HIGH,
        "높음": RiskType.HIGH,
        "중상": RiskType.HIGH,
        "medium": RiskType.MEDIUM,
        "중간": RiskType.MEDIUM,
        "보통": RiskType.MEDIUM,
        "low": RiskType.LOW,
        "낮음": RiskType.LOW,
    }

    # LLM 판정 과소평가를 줄이기 위한 키워드 하한 보정
    _HEURISTIC_PATTERNS = {
        RiskType.CRITICAL: [
            r"전액\s*배상",
            r"무제한\s*배상",
            r"모든\s*손해",
            r"즉시\s*강제\s*집행",
            r"보증금\s*몰수",
            r"일방적\s*해지",
        ],
        RiskType.HIGH: [
            r"해지",
            r"위약금",
            r"지연손해금",
            r"면책",
            r"손해배상",
            r"원상복구",
            r"임차인\s*부담",
            r"보증금\s*공제",
        ],
        RiskType.MEDIUM: [
            r"협의",
            r"통보",
            r"기한",
            r"수리",
            r"관리비",
        ],
    }

    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_RISK_MODEL") or "gpt-5.2"
        self.api_key = os.getenv("OPENAI_API_KEY") or "api필요"
        self.temperature = float(os.getenv("RISK_ASSESSOR_TEMPERATURE", "0"))
        self.votes = max(1, int(os.getenv("RISK_ASSESSOR_VOTES", "2")))
        self._client = self._build_client() if self.api_key != "api필요" else None

    def _build_client(self):
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError(
                "openai 패키지가 없습니다. `pip install openai`로 설치하세요."
            ) from exc
        return OpenAI(api_key=self.api_key)

    def assess_clause(self, clause: Clause) -> Tuple[Optional[RiskType], str]:
        if self.api_key == "api필요":
            return None, "api필요"
        if self.votes == 1:
            return self._assess_once(clause)
        return self._assess_with_votes(clause)

    def _assess_once(self, clause: Clause) -> Tuple[Optional[RiskType], str]:
        if self.api_key == "api필요":
            return None, "api필요"

        clause_title = (clause.title or "").strip()
        clause_body = (clause.content or "").strip()
        clause_text = f"{clause_title}\n{clause_body}".strip()

        prompt = (
            "You are a legal risk assistant for Korean real-estate contracts.\n"
            "Assess clause risk using this rubric:\n"
            "- critical: severe unilateral burden, unlimited liability, deposit forfeiture, immediate enforcement\n"
            "- high: strong one-sided terms likely to cause dispute/loss\n"
            "- medium: ambiguity or operational burden with moderate dispute risk\n"
            "- low: generally standard and balanced wording\n"
            "Return JSON only with keys:\n"
            "{\"risk\":\"low|medium|high|critical\",\"rationale\":\"Korean, <=120 chars\"}\n"
            "Do not include markdown code fences.\n"
            f"Clause:\n{clause_text}"
        )

        response = self._client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=self.temperature,
        )
        content = response.choices[0].message.content or ""

        payload = self._parse_json_payload(content)
        llm_risk: Optional[RiskType] = None
        rationale = ""
        if payload:
            llm_risk = self._map_risk(str(payload.get("risk", "")).strip())
            rationale = str(payload.get("rationale", "")).strip()

        heuristic_risk = self._heuristic_risk(clause_text)
        final_risk = self._merge_risk(llm_risk, heuristic_risk)

        if not rationale:
            rationale = self._fallback_rationale(final_risk)
        return final_risk, rationale

    def _assess_with_votes(self, clause: Clause) -> Tuple[Optional[RiskType], str]:
        decisions: list[Tuple[Optional[RiskType], str]] = []
        for _ in range(self.votes):
            decisions.append(self._assess_once(clause))

        risks = [risk for risk, _ in decisions if risk is not None]
        if not risks:
            return decisions[0] if decisions else (None, "위험도 판단 근거가 충분하지 않아 추가 확인이 필요합니다.")

        counts = Counter(risks)
        top_count = max(counts.values())
        candidates = [risk for risk, count in counts.items() if count == top_count]
        # 동률이면 보수적으로 상위 위험도를 선택
        chosen_risk = max(candidates, key=self._risk_rank)

        for risk, rationale in decisions:
            if risk == chosen_risk and rationale.strip():
                return chosen_risk, rationale
        return chosen_risk, self._fallback_rationale(chosen_risk)

    def filter_risky_clauses(self, clauses: list[Clause]) -> list[Clause]:
        risky: list[Clause] = []
        if not clauses:
            return risky
        workers = int(os.getenv("RISK_ASSESSOR_WORKERS", "4"))
        if workers <= 1:
            for clause in clauses:
                risk, rationale = self.assess_clause(clause)
                clause.risk_level = risk
                clause.risk_reason = rationale
                if risk in (RiskType.MEDIUM, RiskType.HIGH, RiskType.CRITICAL):
                    risky.append(clause)
            return risky

        with ThreadPoolExecutor(max_workers=workers) as executor:
            future_map = {
                executor.submit(self.assess_clause, clause): clause for clause in clauses
            }
            for future in as_completed(future_map):
                clause = future_map[future]
                risk, rationale = future.result()
                clause.risk_level = risk
                clause.risk_reason = rationale
                if risk in (RiskType.MEDIUM, RiskType.HIGH, RiskType.CRITICAL):
                    risky.append(clause)
        return risky

    def _map_risk(self, value: str) -> Optional[RiskType]:
        normalized = (value or "").strip().lower().replace("_", " ")
        if not normalized:
            return None
        for key, risk in self._RISK_VALUE_MAP.items():
            if key in normalized:
                return risk
        return None

    def _heuristic_risk(self, text: str) -> Optional[RiskType]:
        source = (text or "").strip()
        if not source:
            return None
        for risk in (RiskType.CRITICAL, RiskType.HIGH, RiskType.MEDIUM):
            for pattern in self._HEURISTIC_PATTERNS.get(risk, []):
                if re.search(pattern, source, flags=re.IGNORECASE):
                    return risk
        return RiskType.LOW

    @staticmethod
    def _risk_rank(risk: Optional[RiskType]) -> int:
        order = {
            RiskType.LOW: 1,
            RiskType.MEDIUM: 2,
            RiskType.HIGH: 3,
            RiskType.CRITICAL: 4,
        }
        return order.get(risk, 0)

    def _merge_risk(
        self, llm_risk: Optional[RiskType], heuristic_risk: Optional[RiskType]
    ) -> Optional[RiskType]:
        if llm_risk is None:
            return heuristic_risk
        if heuristic_risk is None:
            return llm_risk
        # 명백한 고위험 키워드가 있으면 과소평가를 방지하기 위해 상향 보정
        if self._risk_rank(heuristic_risk) >= self._risk_rank(RiskType.HIGH):
            if self._risk_rank(heuristic_risk) > self._risk_rank(llm_risk):
                return heuristic_risk
        return llm_risk

    @staticmethod
    def _parse_json_payload(content: str) -> dict:
        raw = (content or "").strip()
        if not raw:
            return {}
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            match = re.search(r"\{[\s\S]*\}", raw)
            if not match:
                return {}
            try:
                parsed = json.loads(match.group(0))
                return parsed if isinstance(parsed, dict) else {}
            except json.JSONDecodeError:
                return {}

    @staticmethod
    def _fallback_rationale(risk: Optional[RiskType]) -> str:
        if risk == RiskType.CRITICAL:
            return "조항이 일방적 책임 또는 과도한 손해부담을 포함해 분쟁 및 금전 손실 위험이 큽니다."
        if risk == RiskType.HIGH:
            return "조항의 부담 배분이 불균형해 분쟁 가능성과 손실 위험이 높습니다."
        if risk == RiskType.MEDIUM:
            return "조항 문구가 다소 모호해 해석 차이에 따른 분쟁 가능성이 있습니다."
        if risk == RiskType.LOW:
            return "일반적인 범위의 조항으로 보이나 적용 조건은 확인이 필요합니다."
        return "위험도 판단 근거가 충분하지 않아 추가 확인이 필요합니다."
