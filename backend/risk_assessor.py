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
        "\uB9E4\uC6B0\uB192\uC74C": RiskType.CRITICAL,
        "\uB9E4\uC6B0 \uB192\uC74C": RiskType.CRITICAL,
        "high": RiskType.HIGH,
        "\uB192\uC74C": RiskType.HIGH,
        "medium": RiskType.MEDIUM,
        "\uC911\uAC04": RiskType.MEDIUM,
        "\uBCF4\uD1B5": RiskType.MEDIUM,
        "low": RiskType.LOW,
        "\uB0AE\uC74C": RiskType.LOW,
    }

    # LLM \uacfc\uc18c\ud0d0\uc9c0 \ub300\ube44 \ud0a4\uc6cc\ub4dc \uae30\ubc18 \ubcf4\uc815 \uaddc\uce59
    _HEURISTIC_PATTERNS = {
        RiskType.CRITICAL: [
            r"\uC804\uC561\s*\uBC30\uC0C1",
            r"\uBB34\uC81C\uD55C\s*\uBC30\uC0C1",
            r"\uBAA8\uB4E0\s*\uC190\uD574",
            r"\uC989\uC2DC\s*\uAC15\uC81C\s*\uC9D1\uD589",
            r"\uBCF4\uC99D\uAE08\s*\uBAB0\uC218",
            r"\uC77C\uBC29\s*\uD574\uC9C0",
        ],
        RiskType.HIGH: [
            r"\uC190\uD574",
            r"\uACC4\uC57D\uAE08",
            r"\uC9C0\uC5F0\uC190\uD574\uAE08",
            r"\uC704\uC57D\uAE08",
            r"\uC190\uD574\uBC30\uC0C1",
            r"\uC6D0\uC0C1\uBCF5\uAD6C",
            r"\uC5F0\uCCB4\s*\uBD80\uB2F4",
            r"\uBCF4\uC99D\uAE08\s*\uACF5\uC81C",
        ],
        RiskType.MEDIUM: [
            r"\uD1B5\uC9C0",
            r"\uC2E0\uACE0",
            r"\uAE30\uD55C",
            r"\uC218\uB9AC",
            r"\uAD00\uB9AC\uBE44",
        ],
    }

    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_RISK_MODEL") or "o4-mini"
        self.api_key = os.getenv("OPENAI_API_KEY") or "\uC544\uD53C\uD544\uC694"
        self.temperature = float(os.getenv("RISK_ASSESSOR_TEMPERATURE", "0"))
        self.votes = max(1, int(os.getenv("RISK_ASSESSOR_VOTES", "2")))
        self._client = self._build_client() if self.api_key != "\uC544\uD53C\uD544\uC694" else None

    def _build_client(self):
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError(
                "openai \uD328\uD0A4\uC9C0\uAC00 \uC5C6\uC2B5\uB2C8\uB2E4. `pip install openai`\uB85C \uC124\uCE58\uD558\uC138\uC694."
            ) from exc
        return OpenAI(api_key=self.api_key)

    def assess_clause(self, clause: Clause) -> Tuple[Optional[RiskType], str]:
        if self.api_key == "\uC544\uD53C\uD544\uC694":
            return None, "\uC544\uD53C\uD544\uC694"
        if self.votes == 1:
            return self._assess_once(clause)
        return self._assess_with_votes(clause)

    def _assess_once(self, clause: Clause) -> Tuple[Optional[RiskType], str]:
        if self.api_key == "\uC544\uD53C\uD544\uC694":
            return None, "\uC544\uD53C\uD544\uC694"

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

        request_kwargs = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
        }
        if self.model != "o4-mini":
            request_kwargs["temperature"] = self.temperature

        response = self._client.chat.completions.create(**request_kwargs)
        content = response.choices[0].message.content or ""
        self._log_usage("risk_assessor", prompt, content)

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
            return decisions[0] if decisions else (None, "\uC704\uD5D8 \uD310\uB2E8 \uADFC\uAC70\uAC00 \uBD80\uC871\uD569\uB2C8\uB2E4. \uCD94\uAC00 \uD655\uC778\uC774 \uD544\uC694\uD569\uB2C8\uB2E4.")

        counts = Counter(risks)
        top_count = max(counts.values())
        candidates = [risk for risk, count in counts.items() if count == top_count]
        # \ub3d9\ub960\uc774\uba74 \ubcf4\uc218\uc801\uc73c\ub85c \uc0c1\uc704 \uc704\ud5d8\ub3c4\ub97c \uc120\ud0dd
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
        # \ub192\uc740 \uc704\ud5d8 \ud0a4\uc6cc\ub4dc\uac00 \uc788\uc73c\uba74 \ubcf4\uc218\uc801\uc73c\ub85c \uc0c1\ud5a5
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
            return "\uc870\ud56d\uc774 \uc77c\ubc29 \ub2f9\uc0ac\uc790\uc5d0\uac8c \uacfc\ub3c4\ud55c \ucc45\uc784 \ub610\ub294 \uc911\ub300\ud55c \ubd88\uc774\uc775\uc744 \ubd80\uac00\ud560 \uc218 \uc788\uc2b5\ub2c8\ub2e4."
        if risk == RiskType.HIGH:
            return "\uc870\ud56d\uc774 \ubd88\ub9ac\ud558\uac8c \ud574\uc11d\ub420 \uc5ec\uc9c0\uac00 \uc788\uc5b4 \ubd84\uc7c1 \ub610\ub294 \uc190\uc2e4 \uc704\ud5d8\uc774 \ud06c\uc2b5\ub2c8\ub2e4."
        if risk == RiskType.MEDIUM:
            return "\uc870\ud56d \ubb38\uad6c\uac00 \ubaa8\ud638\ud558\uc5ec \ud574\uc11d \ucc28\uc774\ub85c \ubd84\uc7c1\uc774 \uc0dd\uae38 \uc218 \uc788\uc2b5\ub2c8\ub2e4."
        if risk == RiskType.LOW:
            return "\uc77c\ubc18\uc801\uc778 \ubc94\uc704\uc758 \uc870\ud56d\uc73c\ub85c \ubcf4\uc774\ub098 \uc801\uc6a9 \uc870\uac74\uc744 \ud655\uc778\ud558\uc138\uc694."
        return "\uc704\ud5d8 \ud310\ub2e8 \uadfc\uac70\uac00 \ubd80\uc871\ud569\ub2c8\ub2e4. \ucd94\uac00 \ud655\uc778\uc774 \ud544\uc694\ud569\ub2c8\ub2e4."

    @staticmethod
    def _log_usage(label: str, prompt: str, output: str) -> None:
        if os.getenv("LOG_LLM_TOKENS", "false").lower() not in ("1", "true", "yes", "y"):
            return
        input_chars = len(prompt or "")
        output_chars = len(output or "")
        approx_tokens = (input_chars + output_chars) // 4
        print(
            "[LLM TOKENS approx] "
            f"label={label} model=o4-mini input_chars={input_chars} "
            f"output_chars={output_chars} approx_tokens={approx_tokens}"
        )
