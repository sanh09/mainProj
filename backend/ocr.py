import json
import mimetypes
import os
from typing import Any, Dict


class UpstageDocumentExtractor:
    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("UPSTAGE_API_KEY") or ""
        self.endpoint = (
            os.getenv("UPSTAGE_OCR_ENDPOINT")
            or "https://api.upstage.ai/v1/document-digitization"
        )
        self.model = (os.getenv("UPSTAGE_OCR_MODEL") or "document-parse").strip()
        self.ocr = (os.getenv("UPSTAGE_OCR") or "force").strip().lower()
        self.output_format = (os.getenv("DOC_EXTRACT_OUTPUT_FORMAT") or "markdown").lower()
        self.coordinates = (
            os.getenv("UPSTAGE_OCR_COORDINATES", "false").strip().lower()
            in ("1", "true", "yes", "y")
        )
        self.timeout = int(os.getenv("UPSTAGE_OCR_TIMEOUT_SEC", "60"))

    def extract_text_from_file(self, file_path: str) -> Dict[str, Any] | str:
        if not self.api_key:
            return "api필요"
        return self.extract_structured_from_file(file_path)

    def extract_structured_from_file(self, file_path: str) -> Dict[str, Any]:
        mime_type, _ = mimetypes.guess_type(file_path)
        mime_type = mime_type or "application/octet-stream"
        if mime_type.startswith("text/"):
            text = self._read_text_file(file_path)
            return self._normalize_payload(
                {"mode": self.output_format, "text": text, "markdown": text},
                source_type="text",
            )
        payload = self._request_document_parse(file_path, mime_type)
        return self._payload_from_upstage(payload)

    def _request_document_parse(self, file_path: str, mime_type: str) -> Dict[str, Any]:
        try:
            import requests
        except ImportError as exc:
            raise RuntimeError(
                "requests package is required. Install with `pip install requests`."
            ) from exc
        output_formats = ["markdown"]
        if self.output_format in ("text", "markdown", "html"):
            output_formats = [self.output_format]
        data = {
            "ocr": self.ocr,
            "model": self.model,
            "output_formats": json.dumps(output_formats),
        }
        if self.coordinates:
            data["coordinates"] = "true"
        headers = {"Authorization": f"Bearer {self.api_key}"}
        with open(file_path, "rb") as file_handle:
            files = {"document": (os.path.basename(file_path), file_handle, mime_type)}
            response = requests.post(
                self.endpoint,
                headers=headers,
                files=files,
                data=data,
                timeout=self.timeout,
            )
        response.raise_for_status()
        return response.json()

    def _payload_from_upstage(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        content = payload.get("content") if isinstance(payload, dict) else {}
        if not isinstance(content, dict):
            content = {}
        markdown = content.get("markdown") if isinstance(content.get("markdown"), str) else ""
        text = content.get("text") if isinstance(content.get("text"), str) else ""
        html = content.get("html") if isinstance(content.get("html"), str) else ""
        if not markdown and self.output_format == "markdown":
            markdown = text or html
        if not text:
            text = markdown or html
        normalized = self._normalize_payload(
            {
                "mode": self.output_format,
                "text": text,
                "markdown": markdown,
                "content_json": {},
                "metadata": {},
            },
            source_type="upstage",
        )
        if html:
            normalized["html"] = html
        return normalized

    @staticmethod
    def _normalize_payload(payload: Dict[str, Any], source_type: str) -> Dict[str, Any]:
        mode = payload.get("mode") if isinstance(payload, dict) else None
        mode = mode if mode in ("markdown", "json") else "markdown"
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


UpstageOCR = UpstageDocumentExtractor


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
