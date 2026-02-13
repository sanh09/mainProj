import hashlib
import os
from threading import Lock
from typing import Dict, Iterable, List, Optional

from models import Law

try:
    from pinecone import Pinecone, ServerlessSpec
except Exception:
    Pinecone = None  # type: ignore[assignment]
    ServerlessSpec = None  # type: ignore[assignment]


EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))
PINECONE_INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "contract-rag")
PINECONE_NAMESPACE = os.getenv("PINECONE_NAMESPACE_LAW", "laws")
PINECONE_CLOUD = os.getenv("PINECONE_CLOUD", "aws")
PINECONE_REGION = os.getenv("PINECONE_REGION", "us-east-1")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "")

_INDEX = None
_INDEX_LOCK = Lock()


def _is_enabled() -> bool:
    return bool(PINECONE_API_KEY and Pinecone is not None)


def _existing_index_names(pc: Pinecone) -> set[str]:
    try:
        raw = pc.list_indexes()
    except Exception:
        return set()

    names: set[str] = set()
    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, dict):
                name = item.get("name")
                if name:
                    names.add(str(name))
            else:
                name = getattr(item, "name", None)
                if name:
                    names.add(str(name))
        return names

    if hasattr(raw, "names"):
        try:
            names.update(str(name) for name in raw.names())
            return names
        except Exception:
            pass

    if hasattr(raw, "to_dict"):
        try:
            data = raw.to_dict()
            idxs = data.get("indexes", []) if isinstance(data, dict) else []
            for item in idxs:
                if isinstance(item, dict) and item.get("name"):
                    names.add(str(item["name"]))
        except Exception:
            pass
    return names


def _normalize_doc_key(doc_type: str, doc_id: str, doc_hash: str) -> str:
    doc_type = (doc_type or "").strip()
    doc_id = (doc_id or "").strip()
    if doc_type and doc_id:
        return f"{doc_type}:{doc_id}"
    return f"hash:{doc_hash}"


def _compute_hash(law: Law) -> str:
    blob = "|".join(
        [
            law.doc_type or "",
            law.doc_id or "",
            law.title or "",
            law.summary or "",
            law.content or "",
            law.date or "",
            law.org or "",
        ]
    )
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _build_search_text(law: Law) -> str:
    parts = [
        law.doc_type,
        law.doc_id,
        law.title,
        law.summary,
        law.content,
        law.date,
        law.org,
    ]
    return " ".join([p for p in parts if p]).strip().lower()


def _search_tokens(text: str) -> List[str]:
    if not text:
        return []
    tokens = []
    for token in text.replace(",", " ").split():
        cleaned = token.strip().lower()
        if not cleaned:
            continue
        if cleaned not in tokens:
            tokens.append(cleaned)
        if len(tokens) >= 40:
            break
    return tokens


def _to_law(match) -> Law:
    metadata = getattr(match, "metadata", None) or {}
    item = Law(
        doc_id=str(metadata.get("doc_id", "")),
        doc_type=str(metadata.get("doc_type", "")),
        title=str(metadata.get("title", "")),
        summary=str(metadata.get("summary", "")),
        content=str(metadata.get("content", "")),
        date=str(metadata.get("date", "")),
        org=str(metadata.get("org", "")),
        url=str(metadata.get("url", "")),
    )
    embedding = metadata.get("embedding")
    if isinstance(embedding, list):
        setattr(item, "embedding", embedding)
    embedding_model = metadata.get("embedding_model")
    if embedding_model:
        setattr(item, "embedding_model", str(embedding_model))
    score = getattr(match, "score", None)
    if score is not None:
        item.similarity_score = float(score)
    return item


def _zero_vector() -> List[float]:
    # Pinecone dense vectors cannot be all-zero values.
    if EMBEDDING_DIM <= 0:
        return []
    v = [0.0] * EMBEDDING_DIM
    v[0] = 1e-3
    return v


def _get_index():
    global _INDEX
    if not _is_enabled():
        return None
    if _INDEX is not None:
        return _INDEX

    with _INDEX_LOCK:
        if _INDEX is not None:
            return _INDEX

        pc = Pinecone(api_key=PINECONE_API_KEY)
        existing = _existing_index_names(pc)
        if PINECONE_INDEX_NAME not in existing:
            if ServerlessSpec is None:
                return None
            pc.create_index(
                name=PINECONE_INDEX_NAME,
                dimension=EMBEDDING_DIM,
                metric="cosine",
                spec=ServerlessSpec(cloud=PINECONE_CLOUD, region=PINECONE_REGION),
            )
        _INDEX = pc.Index(PINECONE_INDEX_NAME)
        return _INDEX


def ensure_law_tables() -> None:
    _get_index()


def upsert_laws(laws: Iterable[Law], keywords: Optional[List[str]] = None) -> int:
    items = list(laws)
    if not items:
        return 0

    index = _get_index()
    if index is None:
        return 0

    keyword_tokens = _search_tokens(" ".join(keywords or []))
    vectors: List[Dict] = []
    for law in items:
        doc_hash = _compute_hash(law)
        doc_key = _normalize_doc_key(law.doc_type, law.doc_id, doc_hash)

        embedding = getattr(law, "embedding", None)
        if not isinstance(embedding, list) or not embedding:
            # keyword 검색만 가능한 캐시 문서로 저장
            embedding = _zero_vector()

        search_text = _build_search_text(law)
        search_tokens = _search_tokens(search_text)
        for token in keyword_tokens:
            if token not in search_tokens:
                search_tokens.append(token)

        metadata = {
            "doc_key": doc_key,
            "doc_type": law.doc_type or "",
            "doc_id": law.doc_id or "",
            "title": law.title or "",
            "summary": law.summary or "",
            "content": law.content or "",
            "date": law.date or "",
            "org": law.org or "",
            "url": law.url or "",
            "search_text": search_text,
            "search_tokens": search_tokens,
            "embedding_model": getattr(law, "embedding_model", None),
        }
        metadata = {k: v for k, v in metadata.items() if v is not None}
        vectors.append({"id": f"law:{doc_key}", "values": embedding, "metadata": metadata})

    batch_size = 100
    for i in range(0, len(vectors), batch_size):
        index.upsert(vectors=vectors[i : i + batch_size], namespace=PINECONE_NAMESPACE)
    return len(vectors)


def _query_by_vector(vector: List[float], limit: int = 20):
    index = _get_index()
    if index is None or not vector:
        return []
    response = index.query(
        vector=vector,
        top_k=max(int(limit), 1),
        include_metadata=True,
        namespace=PINECONE_NAMESPACE,
    )
    matches = getattr(response, "matches", None)
    if matches is not None:
        return matches
    if isinstance(response, dict):
        return response.get("matches", [])
    return []


def search_laws(keyword: str, limit: int = 20) -> List[Law]:
    normalized = (keyword or "").strip().lower()
    if not normalized:
        return []

    # 키워드 검색은 query text를 임베딩해 벡터 검색으로 수행
    try:
        from embedding_manager import EmbeddingManager

        manager = EmbeddingManager()
        query_embedding = manager.generate_embedding(normalized)
        if query_embedding == "api필요":
            return []
    except Exception:
        return []

    matches = _query_by_vector(query_embedding, limit=limit)
    return [_to_law(match) for match in matches]


def search_laws_by_vector(embedding: List[float], limit: int = 5) -> List[Law]:
    matches = _query_by_vector(embedding, limit=limit)
    return [_to_law(match) for match in matches]
