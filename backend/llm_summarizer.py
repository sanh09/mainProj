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
