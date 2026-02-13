import json
import os
from typing import Optional


class LLMSummarizer:
    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_SUMMARY_MODEL") or "gpt-5.2"
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
        return response.choices[0].message.content or ""

    def generate_comprehensive_report(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Create a comprehensive report with sections: overview, key clauses, risks, and recommendations. "
            "Respond in Korean."
        )
        response = self._client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        return response.choices[0].message.content or ""

    def generate_debate_summary(self, text: str) -> str:
        if self.api_key == "api필요":
            return "api필요"
        prompt = (
            "Summarize the debate concisely in 4-6 bullets, focusing on key points, "
            "areas of agreement/disagreement, and practical takeaways. Respond in Korean."
        )
        response = self._client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        return response.choices[0].message.content or ""

    def generate_overall_debate_summary(self, text: str) -> str:
        if self.api_key == "api?꾩슂":
            return "api?꾩슂"
        prompt = (
            "Summarize the clause-level debate summaries into a single concise report. "
            "Include: 핵심 쟁점, 공통 합의, 주요 불일치, 실무적 조치. "
            "Respond in Korean and keep it brief (6-10 bullets)."
        )
        response = self._client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        return response.choices[0].message.content or ""

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
            model=self.model,
            messages=[
                {"role": "system", "content": prompt},
                {"role": "user", "content": text},
            ],
        )
        content = response.choices[0].message.content or ""
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            return {"raw": content}
