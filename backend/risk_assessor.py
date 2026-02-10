import json
import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional, Tuple



from models import Clause, RiskType


class RiskAssessor:
    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_RISK_MODEL") or "gpt-5.2"
        self.api_key = os.getenv("OPENAI_API_KEY") or "api필요"
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
        prompt = (
            "You are a legal risk assistant. Assess the risk level of the clause below.\n"
            "Return JSON only: {\"risk\": \"low|medium|high|critical\", \"rationale\": \"...\"}\n"
            "Write the rationale in Korean.\n"
            f"Clause:\n{clause.content}"
        )
        response = self._client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
        )
        content = response.choices[0].message.content or ""
        try:
            payload = json.loads(content)
            risk_raw = str(payload.get("risk", "")).lower()
            risk = self._map_risk(risk_raw)
            rationale = str(payload.get("rationale", "")).strip()
            return risk, rationale
        except json.JSONDecodeError:
            risk = self._map_risk(content.lower())
            return risk, content.strip()

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
            future_map = {executor.submit(self.assess_clause, clause): clause for clause in clauses}
            for future in as_completed(future_map):
                clause = future_map[future]
                risk, rationale = future.result()
                clause.risk_level = risk
                clause.risk_reason = rationale
                if risk in (RiskType.MEDIUM, RiskType.HIGH, RiskType.CRITICAL):
                    risky.append(clause)
        return risky

    def _map_risk(self, value: str) -> Optional[RiskType]:
        if "critical" in value:
            return RiskType.CRITICAL
        if "high" in value:
            return RiskType.HIGH
        if "medium" in value:
            return RiskType.MEDIUM
        if "low" in value:
            return RiskType.LOW
        return None
