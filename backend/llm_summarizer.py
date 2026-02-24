import json
import os
from typing import Optional


class LLMSummarizer:
    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_SUMMARY_MODEL") or "gpt-4o-mini"
        self.report_model = os.getenv("OPENAI_REPORT_MODEL") or self.model
        self.api_key = os.getenv("OPENAI_API_KEY") or "api필요"
        self._client = self._build_client() if self.api_key != "api필요" else None

    def _build_client(self):
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError("openai 패키지가 없습니다. `pip install openai`로 설치하세요.") from exc
        return OpenAI(api_key=self.api_key)

    def _timed_chat_completion(self, label: str, **kwargs):
        start_time = None
        if os.getenv("LOG_LLM_LATENCY", "false").lower() in ("1", "true", "yes", "y"):
            import time
            start_time = time.perf_counter()
        response = self._client.chat.completions.create(**kwargs)
        if start_time is not None:
            import time
            elapsed = time.perf_counter() - start_time
            model = kwargs.get("model")
            print(f"[LLM LATENCY] label={label} model={model} seconds={elapsed:.2f}")
        return response

    def generate_summary(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Summarize the contract clauses concisely, focusing on key obligations and risks. "
            "Respond in Korean."
        )
        response = self._timed_chat_completion(
            "summary",
            model=self.model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("summary", [prompt, text], content)
        return content

    def generate_comprehensive_report(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Create a comprehensive report with sections: overview, key clauses, risks, and recommendations. "
            "Respond in Korean."
        )
        response = self._timed_chat_completion(
            "comprehensive_report",
            model=self.report_model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("comprehensive_report", [prompt, text], content)
        return content

    def generate_debate_summary(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Summarize the debate with three labeled sections in Korean:\n"
            "임대인 입장 2-3 bullets\n"
            "임차인 입장 2-3 bullets\n"
            "중재(판사) 요약 2-3 bullets (공통점/쟁점 구분)\n"
            "Use the exact section labels and keep each bullet concise."
        )
        response = self._timed_chat_completion(
            "debate_summary",
            model=self.report_model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("debate_summary", [prompt, text], content)
        return content

    def generate_overall_debate_summary(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Summarize the clause-level debate summaries into a single concise report. "
            "Include: 주요 쟁점, 공통점, 임대인/임차인 주장, 합의/권고. "
            "Respond in Korean and keep it brief (6-10 bullets)."
        )
        response = self._timed_chat_completion(
            "overall_debate_summary",
            model=self.report_model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("overall_debate_summary", [prompt, text], content)
        return content

    def generate_clause_ui_payload(self, text: str) -> dict:
        if self.api_key == "api필요":
            return {"error": "api필요"}
        prompt = (
            "You are generating a structured UI payload for a risky clause analysis. "
            "If a debate transcript is included in the input, use it as the primary source and summarize the debate outcome. "
            "Return ONLY valid JSON with the following keys:\n"
            "summary: string,\n"
            "why_check: string,\n"
            "landlord_view: string,\n"
            "tenant_view: string,\n"
            "alternatives: [string, ...],\n"
            "questions: [string, ...],\n"
            "overall_takeaway: string\n"
            "Respond in Korean. Keep each string concise (1-3 sentences). "
            "No extra text outside JSON."
        )
        response = self._timed_chat_completion(
            "clause_ui_payload",
            model=self.report_model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("clause_ui_payload", [prompt, text], content)
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            return {"raw": content}

    def generate_clause_ui_payload_v2(
        self,
        clause_id: str,
        title: str,
        clause_text: str,
        risk_level: str,
        risk_reason: str,
        precedents: list[str],
        laws: list[str],
        debate_snippet: str = "",
    ) -> dict:
        if self.api_key == "api필요":
            return {"error": "api필요"}
        ref_precedents = "\n".join(f"- {p}" for p in precedents) if precedents else "- 없음"
        ref_laws = "\n".join(f"- {l}" for l in laws) if laws else "- 없음"

        system_prompt = (
            "You are drafting neutral, non-judgmental guidance for a rental contract clause. "
            "Use a 'possible claim' tone. Avoid definitive legal conclusions. "
            "Do NOT say the clause is illegal/valid. Do NOT give legal advice."
        )
        prompt = (
            "Return ONLY valid JSON with the following structure:\n"
            "{\n"
            "  \"L1\": {\n"
            "    \"why_check\": [2-3 neutral sentences],\n"
            "    \"fact_questions\": [1-2 questions]\n"
            "  },\n"
            "  \"L2\": {\n"
            "    \"tenant_view\": \"possible-claim tone\",\n"
            "    \"landlord_view\": \"possible-claim tone\",\n"
            "    \"neutral_summary\": \"neutral summary\"\n"
            "  },\n"
            "  \"L3\": {\n"
            "    \"before\": \"short excerpt or concise paraphrase of the clause\",\n"
            "    \"after_options\": [\n"
            "      {\"label\": \"옵션 A\", \"text\": \"...\"},\n"
            "      {\"label\": \"옵션 B\", \"text\": \"...\"},\n"
            "      {\"label\": \"옵션 C\", \"text\": \"...\"}\n"
            "    ],\n"
            "    \"note\": \"범위 제안이며 구체 문구는 협의 필요\"\n"
            "  },\n"
            "  \"L4\": {\n"
            "    \"why\": \"확인 필요 이유\",\n"
            "    \"questions\": [\n"
            "      {\"q\": \"확인 질문\", \"reason\": \"질문 이유\"},\n"
            "      {\"q\": \"추가 확인 질문\", \"reason\": \"추가 확인 이유\"}\n"
            "    ]\n"
            "  }\n"
            "}\n"
            "Constraints:\n"
            "- L1 why_check: 2-3 lines, neutral, non-definitive.\n"
            "- L1 fact_questions: 1-2 items, factual.\n"
            "- L2: use 'possible-claim' tone, avoid judgments.\n"
            "- L2 tenant_view and landlord_view must be meaningfully different.\n"
            "- L2 tenant_view: focus on tenant downside, 생활 불편, 비용/책임 확대, 권리 제한.\n"
            "- L2 landlord_view: focus on 관리/운영 필요, 안전/보안, 리스크 통제, 집행 가능성.\n"
            "- L2 views must not reuse the same key phrases or sentence structure.\n"
            "- L2 tenant_view must include at least one tenant-side impact (e.g., 생활 불편, 비용 부담, 권리 제한).\n"
            "- L2 landlord_view must include at least one landlord-side rationale (e.g., 관리 필요, 안전/보안, 책임 통제).\n"
            "- L2 neutral_summary: 2 concise sentences describing what the clause says and a neutral implication.\n"
            "- L2 tenant_view, landlord_view, and neutral_summary MUST include at least one concrete detail from the clause text (e.g., time window, 대상, 금지/의무).\n"
            "- Avoid generic statements that could apply to any clause.\n"
            "- L3: provide options A/B/C as ranges, not fixed edits.\n"
            "- L4: why -> questions with reasons (no drafts).\n"
            "- L4 questions/reasons must focus on the problematic or unclear points in the clause.\n"
            "- L4 should guide what to ask, not propose edits.\n"
            "Strict JSON rules:\n"
            "- Use double quotes for all keys and strings.\n"
            "- No trailing commas.\n"
            "- Do not wrap in code fences.\n"
            "- If unsure, return empty arrays/strings but keep the schema.\n"
            "No extra text outside JSON. Respond in Korean.\n\n"
            f"Clause ID: {clause_id}\n"
            f"Title: {title}\n"
            f"Risk level: {risk_level}\n"
            f"Risk reason: {risk_reason}\n"
            f"Clause text:\n{clause_text}\n\n"
            f"Related precedents:\n{ref_precedents}\n\n"
            f"Related laws:\n{ref_laws}\n\n"
            f"Debate snippet (if any):\n{debate_snippet or '- 없음'}\n"
        )

        response = self._timed_chat_completion(
            "clause_ui_payload_v2",
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("clause_ui_payload_v2", [system_prompt, prompt], content)
        try:
            payload = json.loads(content)
        except json.JSONDecodeError:
            return {"error": "invalid_json", "raw": content}

        if os.getenv("REPAIR_SIMILAR_VIEWS", "true").lower() in ("1", "true", "yes", "y"):
            payload = self._repair_similar_views(payload, clause_text, risk_reason)
        if os.getenv("ENFORCE_DETAIL_IN_VIEWS", "true").lower() in ("1", "true", "yes", "y"):
            payload = self._ensure_detail_in_l2(payload, clause_text, risk_reason)
        return {
            "clause_id": clause_id,
            "title": title,
            "risk_level": risk_level,
            "risk_reason": risk_reason,
            "P": payload,
        }




    def _repair_similar_views(self, payload: dict, clause_text: str, risk_reason: str) -> dict:
        l2 = payload.get("L2") if isinstance(payload, dict) else None
        if not isinstance(l2, dict):
            return payload
        tenant_view = str(l2.get("tenant_view") or "").strip()
        landlord_view = str(l2.get("landlord_view") or "").strip()
        if not tenant_view or not landlord_view:
            return payload
        if not self._views_too_similar(tenant_view, landlord_view):
            return payload
        repair_prompt = (
            "Rewrite the two views so they are clearly different. "
            "Tenant view must focus on tenant downside or ambiguity risks. "
            "Landlord view must focus on landlord operational need, risk control, or enforceability. "
            "Do not reuse the same phrases or sentence structure. "
            "Return ONLY JSON with keys: tenant_view, landlord_view, neutral_summary. "
            "neutral_summary must be one concise sentence describing what the clause says (no recommendation).\\n\\n"
            f"Clause text:\\n{clause_text}\\n\\n"
            f"Risk reason:\\n{risk_reason}\\n\\n"
            f"Current tenant_view:\\n{tenant_view}\\n\\n"
            f"Current landlord_view:\\n{landlord_view}\\n"
        )
        response = self._timed_chat_completion(
            "repair_views",
            model=self.model,
            messages=[{"role": "user", "content": repair_prompt}],
        )
        content = response.choices[0].message.content or ""
        self._log_usage("repair_views", [repair_prompt], content)
        try:
            repaired = json.loads(content)
        except json.JSONDecodeError:
            return payload
        if not isinstance(repaired, dict):
            return payload
        new_tenant = str(repaired.get("tenant_view") or "").strip()
        new_landlord = str(repaired.get("landlord_view") or "").strip()
        if new_tenant:
            l2["tenant_view"] = new_tenant
        if new_landlord:
            l2["landlord_view"] = new_landlord
        neutral = str(repaired.get("neutral_summary") or "").strip()
        if neutral:
            l2["neutral_summary"] = neutral
        payload["L2"] = l2
        return payload

    def _ensure_detail_in_l2(self, payload: dict, clause_text: str, risk_reason: str) -> dict:
        l2 = payload.get("L2") if isinstance(payload, dict) else None
        if not isinstance(l2, dict):
            return payload
        tenant_view = str(l2.get("tenant_view") or "").strip()
        landlord_view = str(l2.get("landlord_view") or "").strip()
        neutral_summary = str(l2.get("neutral_summary") or "").strip()
        required_terms = self._extract_detail_terms(clause_text)
        if not required_terms:
            return payload
        if (
            self._contains_any(tenant_view, required_terms)
            and self._contains_any(landlord_view, required_terms)
            and self._contains_any(neutral_summary, required_terms)
        ):
            return payload
        detail_phrase = " ".join(required_terms[:3])
        l2["tenant_view"] = (
            f"임차인은 {detail_phrase} 조건이 생활의 자유를 과도하게 제한하거나 "
            "해석상 불리하게 작용할 수 있어 주의가 필요하다고 볼 수 있습니다."
        )
        l2["landlord_view"] = (
            f"임대인은 {detail_phrase} 기준을 통해 안전과 관리 목적의 출입 통제를 "
            "명확히 하고 책임 리스크를 줄이려는 필요가 있다고 주장할 수 있습니다."
        )
        l2["neutral_summary"] = (
            f"이 조항은 {detail_phrase}와 관련해 타인의 출입을 제한하는 내용을 담고 있습니다."
        )
        payload["L2"] = l2
        return payload

    @staticmethod
    def _views_too_similar(text_a: str, text_b: str) -> bool:
        norm_a = LLMSummarizer._normalize_for_similarity(text_a)
        norm_b = LLMSummarizer._normalize_for_similarity(text_b)
        if not norm_a or not norm_b:
            return False
        if norm_a == norm_b:
            return True
        if norm_a in norm_b or norm_b in norm_a:
            return True
        set_a = set(norm_a.split())
        set_b = set(norm_b.split())
        if not set_a or not set_b:
            return False
        jaccard = len(set_a & set_b) / len(set_a | set_b)
        return jaccard >= 0.6

    @staticmethod
    def _normalize_for_similarity(text: str) -> str:
        raw = (text or "").strip().lower()
        if not raw:
            return ""
        for ch in [",", ".", "?", "!", ":", ";", "(", ")", "[", "]", "{", "}", "'"]:
            raw = raw.replace(ch, " ")
        tokens = raw.split()
        stop = {"and", "or", "the", "to", "of", "in", "on", "for", "with"}
        tokens = [t for t in tokens if t not in stop]
        return " ".join(tokens)

    @staticmethod
    def _extract_detail_terms(clause_text: str) -> list[str]:
        text = (clause_text or "").strip()
        if not text:
            return []
        terms = []
        keywords = [
            "\uCD9C\uC785",
            "\uCD9C\uC785\uAE08\uC9C0",
            "\uAE08\uC9C0",
            "\uBD88\uD5C8",
            "\uBCF8\uC778",
            "\uD0C0\uC778",
            "\uC774\uD6C4",
            "\uC774\uC804",
            "\uC2DC\uAC04",
            "\uC57C\uAC04",
            "\uBC29\uBB38",
            "\uBC29\uBB38\uAC1D",
        ]
        for kw in keywords:
            if kw in text and kw not in terms:
                terms.append(kw)
        import re
        for match in re.findall(r"\d+\s*\uC2DC|\d+\s*\uBD84", text):
            if match not in terms:
                terms.append(match.strip())
        return terms[:6]

    @staticmethod
    def _contains_any(text: str, terms: list[str]) -> bool:
        if not text:
            return False
        for term in terms:
            if term and term in text:
                return True
        return False
    def _log_usage(self, label: str, inputs: list[str], output: str) -> None:
        if os.getenv("LOG_LLM_TOKENS", "false").lower() not in ("1", "true", "yes", "y"):
            return
        input_chars = sum(len(x or "") for x in inputs)
        output_chars = len(output or "")
        approx_tokens = (input_chars + output_chars) // 4
        print(
            "[LLM TOKENS approx] "
            f"label={label} model={self.model} input_chars={input_chars} "
            f"output_chars={output_chars} approx_tokens={approx_tokens}"
        )
