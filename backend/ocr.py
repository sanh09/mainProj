import base64
import json
import mimetypes
import os
from typing import Any, Dict


class GPTDocumentExtractor:
    def __init__(self, api_key: str | None = None, model: str | None = None) -> None:
        self.api_key = api_key or os.getenv("OPENAI_API_KEY") or "api필요"
        self.model = model or os.getenv("OPENAI_OCR_MODEL") or "gpt-4o-mini"
        self.output_format = (os.getenv("DOC_EXTRACT_OUTPUT_FORMAT") or "markdown").lower()
        self.max_input_chars = int(os.getenv("DOC_EXTRACT_MAX_INPUT_CHARS", "50000"))

    def _get_client(self):
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise RuntimeError(
                "openai 패키지가 없습니다. `pip install openai`로 설치하세요."
            ) from exc
        if self.api_key == "api필요":
            raise RuntimeError("환경 변수에 OPENAI_API_KEY가 설정되어 있지 않습니다.")
        return OpenAI(api_key=self.api_key)

    def extract_text_from_file(self, file_path: str) -> Dict[str, Any] | str:
        if self.api_key == "api필요":
            return "api필요"
        return self.extract_structured_from_file(file_path)

    def extract_structured_from_file(self, file_path: str) -> Dict[str, Any]:
        mime_type, _ = mimetypes.guess_type(file_path)
        mime_type = mime_type or "application/octet-stream"
        if mime_type.startswith("image/"):
            return self._extract_from_image(file_path, mime_type)
        if mime_type == "application/pdf":
            text = self._extract_pdf_text(file_path)
            return self._structure_text_with_gpt(text, source_type="pdf")
        text = self._read_text_file(file_path)
        return self._structure_text_with_gpt(text, source_type="text")

    def _extract_from_image(self, file_path: str, mime_type: str) -> Dict[str, Any]:
        with open(file_path, "rb") as file_handle:
            b64 = base64.b64encode(file_handle.read()).decode("ascii")
        data_url = f"data:{mime_type};base64,{b64}"
        prompt = self._build_json_prompt(
            "Extract text from the contract image and preserve document structure."
        )
        client = self._get_client()
        response = client.chat.completions.create(
            model=self.model,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": "You extract contract documents accurately."},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": data_url}},
                    ],
                },
            ],
        )
        content = response.choices[0].message.content or "{}"
        parsed = self._safe_json(content)
        return self._normalize_payload(parsed, source_type="image")

    def _structure_text_with_gpt(self, text: str, source_type: str) -> Dict[str, Any]:
        if not text.strip():
            return {
                "source_type": source_type,
                "mode": self.output_format,
                "text": "",
                "markdown": "",
                "content_json": {},
                "metadata": {"headings": [], "lists": [], "tables": []},
            }
        trimmed = text[: self.max_input_chars]
        prompt = self._build_json_prompt(
            "Convert the extracted contract text into structured output.\n"
            f"INPUT TEXT:\n{trimmed}"
        )
        client = self._get_client()
        response = client.chat.completions.create(
            model=self.model,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": "You extract and structure legal contract text."},
                {"role": "user", "content": prompt},
            ],
        )
        content = response.choices[0].message.content or "{}"
        parsed = self._safe_json(content)
        return self._normalize_payload(parsed, source_type=source_type)

    def _build_json_prompt(self, task_text: str) -> str:
        mode = "json" if self.output_format == "json" else "markdown"
        return (
            f"{task_text}\n\n"
            "Return ONLY a JSON object with this schema:\n"
            "{\n"
            '  "mode": "markdown|json",\n'
            '  "text": "plain text output",\n'
            '  "markdown": "markdown output preserving headings/lists/tables when possible",\n'
            '  "content_json": {"sections": []},\n'
            '  "metadata": {\n'
            '    "headings": [{"level": 1, "text": "..."}],\n'
            '    "lists": [{"type": "ordered|unordered", "items": ["..."]}],\n'
            '    "tables": [{"title": "...", "headers": ["..."], "row_count": 0}]\n'
            "  }\n"
            "}\n"
            f'Set "mode" to "{mode}". Use Korean output where applicable.'
        )

    @staticmethod
    def _safe_json(content: str) -> Dict[str, Any]:
        try:
            parsed = json.loads(content)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {"text": content, "markdown": content, "metadata": {}}

    def _normalize_payload(self, payload: Dict[str, Any], source_type: str) -> Dict[str, Any]:
        mode = payload.get("mode") if isinstance(payload, dict) else None
        mode = mode if mode in ("markdown", "json") else self.output_format
        text = payload.get("text") if isinstance(payload, dict) else ""
        markdown = payload.get("markdown") if isinstance(payload, dict) else ""
        content_json = payload.get("content_json") if isinstance(payload, dict) else {}
        metadata = payload.get("metadata") if isinstance(payload, dict) else {}
        if not isinstance(text, str):
            text = ""
        if not isinstance(markdown, str):
            markdown = text
        if not isinstance(content_json, dict):
            content_json = {}
        if not isinstance(metadata, dict):
            metadata = {}
        metadata.setdefault("headings", [])
        metadata.setdefault("lists", [])
        metadata.setdefault("tables", [])
        if not text:
            text = markdown
        return {
            "source_type": source_type,
            "mode": mode,
            "text": text,
            "markdown": markdown,
            "content_json": content_json,
            "metadata": metadata,
        }

    @staticmethod
    def _read_text_file(file_path: str) -> str:
        with open(file_path, "rb") as file_handle:
            raw = file_handle.read()
        for encoding in ("utf-8", "euc-kr", "cp949"):
            try:
                return raw.decode(encoding)
            except UnicodeDecodeError:
                continue
        return raw.decode("utf-8", errors="ignore")

    @staticmethod
    def _extract_pdf_text(file_path: str) -> str:
        try:
            from pypdf import PdfReader
        except ImportError as exc:
            raise RuntimeError(
                "PDF 처리를 위해 pypdf가 필요합니다. `pip install pypdf`로 설치하세요."
            ) from exc
        reader = PdfReader(file_path)
        texts = []
        for page in reader.pages:
            page_text = page.extract_text() or ""
            if page_text.strip():
                texts.append(page_text)
        return "\n\n".join(texts)


UpstageOCR = GPTDocumentExtractor


def get_extracted_text(result: Any) -> str:
    """
    Normalize extraction results to plain text.
    - If result is already a string, return it.
    - If result is a dict-like payload, prefer markdown then text/content.
    """
    if isinstance(result, str):
        return result
    if isinstance(result, dict):
        markdown = result.get("markdown")
        if isinstance(markdown, str) and markdown.strip():
            return markdown
        text = result.get("text")
        if isinstance(text, str):
            return text
        content = result.get("content")
        if isinstance(content, str):
            return content
    return ""
