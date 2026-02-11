import math
import os
from typing import List, Optional

try:
    from openai import OpenAI
except ImportError as exc:
    raise ImportError(
        "필수 패키지가 없습니다: openai. `pip install openai`로 설치하세요."
    ) from exc

from models import Precedent, Law


class EmbeddingManager:
    def __init__(self, model: Optional[str] = None) -> None:
        self.model = model or os.getenv("OPENAI_EMBEDDING_MODEL") or "text-embedding-3-small"
        self.api_key = os.getenv("OPENAI_API_KEY") or "api필요"
        self._client = OpenAI(api_key=self.api_key) if self.api_key != "api필요" else None
        self.use_db_vector_search = os.getenv("USE_DB_VECTOR_SEARCH", "false").lower() in (
            "1",
            "true",
            "yes",
            "y",
        )

    def generate_embedding(self, text: str) -> List[float] | str:
        if self.api_key == "api필요":
            return "api필요"
        response = self._client.embeddings.create(model=self.model, input=text)
        return response.data[0].embedding

    def calculate_similarity(self, vector_a: List[float], vector_b: List[float]) -> float:
        if not vector_a or not vector_b or len(vector_a) != len(vector_b):
            return 0.0
        dot = sum(a * b for a, b in zip(vector_a, vector_b))
        norm_a = math.sqrt(sum(a * a for a in vector_a))
        norm_b = math.sqrt(sum(b * b for b in vector_b))
        if norm_a == 0.0 or norm_b == 0.0:
            return 0.0
        return dot / (norm_a * norm_b)

    def find_similar_precedents(
        self, target_text: str, precedents: List[Precedent], top_k: int = 3
    ) -> List[Precedent] | str:
        return self._find_similar_items(target_text, precedents, top_k)

    def find_similar_laws(
        self, target_text: str, laws: List[Law], top_k: int = 3
    ) -> List[Law] | str:
        return self._find_similar_items(target_text, laws, top_k)

    def find_similar_precedents_db(self, target_text: str, top_k: int = 3) -> List[Precedent] | str:
        from precedent_store import search_precedents_by_vector

        target_embedding = self.generate_embedding(target_text)
        if target_embedding == "api필요":
            return "api필요"
        return search_precedents_by_vector(target_embedding, limit=top_k)

    def find_similar_laws_db(self, target_text: str, top_k: int = 3) -> List[Law] | str:
        from law_store import search_laws_by_vector

        target_embedding = self.generate_embedding(target_text)
        if target_embedding == "api필요":
            return "api필요"
        return search_laws_by_vector(target_embedding, limit=top_k)

    def attach_embeddings(self, items: List[object], text_getter, max_items: Optional[int] = None):
        if not items:
            return []
        if self.api_key == "api필요":
            return "api필요"
        limit = max_items if max_items is not None else len(items)
        for item in items[:limit]:
            text = text_getter(item)
            if not text:
                continue
            embedding = self.generate_embedding(text)
            if embedding == "api필요":
                return "api필요"
            setattr(item, "embedding", embedding)
            setattr(item, "embedding_model", self.model)
        return items

    def _find_similar_items(self, target_text: str, items: List[object], top_k: int):
        target_embedding = self.generate_embedding(target_text)
        if target_embedding == "api필요":
            return "api필요"
        scored: List[tuple[float, object]] = []
        for item in items:
            embedding = getattr(item, "embedding", None)
            if embedding is None:
                continue
            score = self.calculate_similarity(target_embedding, embedding)
            scored.append((score, item))
        scored.sort(key=lambda item: item[0], reverse=True)
        return [item[1] for item in scored[:top_k]]
