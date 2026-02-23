import json
import os
from typing import Optional


class LLMSummarizer:
    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_SUMMARY_MODEL") or "o4-mini"
        self.report_model = os.getenv("OPENAI_REPORT_MODEL") or self.model
        self.api_key = os.getenv("OPENAI_API_KEY") or "api필요"
        self._client = self._build_client() if self.api_key != "api필요" else None

    def _build_client(self):
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError("openai 패키지가 없습니다. `pip install openai`로 설치하세요.") from exc
        return OpenAI(api_key=self.api_key)

    def generate_summary(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Summarize the contract clauses concisely, focusing on key obligations and risks. "
            "Respond in Korean."
        )
        response = self._client.chat.completions.create(
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
        response = self._client.chat.completions.create(
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
        response = self._client.chat.completions.create(
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
        response = self._client.chat.completions.create(
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
        response = self._client.chat.completions.create(
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
            "- L2: use '가능 주장' tone, avoid judgments.\n"
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

        response = self._client.chat.completions.create(
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

        return {
            "clause_id": clause_id,
            "title": title,
            "risk_level": risk_level,
            "risk_reason": risk_reason,
            "P": payload,
        }

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
