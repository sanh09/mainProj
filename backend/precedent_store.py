import hashlib
import os
from threading import Lock
from typing import Dict, Iterable, List, Optional

from models import Precedent

try:
    from pinecone import Pinecone, ServerlessSpec
except Exception:
    Pinecone = None  # type: ignore[assignment]
    ServerlessSpec = None  # type: ignore[assignment]


EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))
PINECONE_INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "law-db")
PINECONE_NAMESPACE = os.getenv("PINECONE_NAMESPACE_PRECEDENT", "precedent_chunks")
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


def _compute_hash(precedent: Precedent) -> str:
    blob = "|".join(
        [
            precedent.case_id or "",
            precedent.court or "",
            precedent.date or "",
            precedent.case_name or "",
            precedent.summary or "",
            precedent.key_paragraph or "",
        ]
    )
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _normalize_case_id(case_id: str, case_hash: str) -> str:
    cleaned = (case_id or "").strip()
    if cleaned:
        return cleaned
    return f"hash:{case_hash}"


def _build_search_text(precedent: Precedent) -> str:
    parts = [
        precedent.case_id,
        precedent.court,
        precedent.date,
        precedent.case_name,
        precedent.summary,
        precedent.key_paragraph,
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


def _to_precedent(match) -> Precedent:
    metadata = getattr(match, "metadata", None) or {}
    if metadata.get("doc_type") == "precedent_chunk":
        source_id = str(metadata.get("source_id", "") or "")
        case_id = source_id.replace("prec:", "").strip() if source_id else ""
        title = str(metadata.get("title", "") or "")
        chunk_text = str(metadata.get("chunk_text", "") or "")
        item = Precedent(
            case_id=case_id,
            court="",
            date="",
            case_name=title,
            summary=chunk_text,
            key_paragraph=chunk_text,
        )
        score = getattr(match, "score", None)
        if score is not None:
            item.similarity_score = float(score)
        return item
    item = Precedent(
        case_id=str(metadata.get("case_id", "")),
        court=str(metadata.get("court", "")),
        date=str(metadata.get("date", "")),
        case_name=str(metadata.get("case_name", "")),
        summary=str(metadata.get("summary", "")),
        key_paragraph=str(metadata.get("key_paragraph", "")),
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


def ensure_precedent_tables() -> None:
    _get_index()


def upsert_precedents(
    precedents: Iterable[Precedent],
    keywords: Optional[List[str]] = None,
) -> int:
    items = list(precedents)
    if not items:
        return 0

    index = _get_index()
    if index is None:
        return 0

    keyword_tokens = _search_tokens(" ".join(keywords or []))
    vectors: List[Dict] = []
    for precedent in items:
        case_hash = _compute_hash(precedent)
        case_id = _normalize_case_id(precedent.case_id, case_hash)

        embedding = getattr(precedent, "embedding", None)
        if not isinstance(embedding, list) or not embedding:
            # keyword 검색만 가능한 캐시 문서로 저장
            embedding = _zero_vector()

        search_text = _build_search_text(precedent)
        search_tokens = _search_tokens(search_text)
        for token in keyword_tokens:
            if token not in search_tokens:
                search_tokens.append(token)

        metadata = {
            "doc_type": "precedent",
            "case_id": case_id,
            "court": precedent.court or "",
            "date": precedent.date or "",
            "case_name": precedent.case_name or "",
            "summary": precedent.summary or "",
            "key_paragraph": precedent.key_paragraph or "",
            "search_text": search_text,
            "search_tokens": search_tokens,
            "embedding_model": getattr(precedent, "embedding_model", None),
        }
        metadata = {k: v for k, v in metadata.items() if v is not None}
        vectors.append({"id": f"prec:{case_id}", "values": embedding, "metadata": metadata})

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


def search_precedents(
    keyword: str,
    limit: int = 20,
    embedding_manager: Optional["EmbeddingManager"] = None,
) -> List[Precedent]:
    normalized = (keyword or "").strip().lower()
    if not normalized:
        return []

    # 키워드 검색은 query text를 임베딩해 벡터 검색으로 수행
    try:
        from embedding_manager import EmbeddingManager

        manager = embedding_manager or EmbeddingManager()
        query_embedding = manager.generate_embedding(normalized)
        if query_embedding == "api필요":
            return []
    except Exception:
        return []

    matches = _query_by_vector(query_embedding, limit=limit)
    items = [_to_precedent(match) for match in matches]
    must_keywords = [
        term.strip()
        for term in (
            os.getenv("PRECEDENT_MUST_KEYWORDS")
            or "임대차,전세,월세,보증금,임차,차임,보증금반환,차임연체,임차권,전입,임차인,임대인"
        ).split(",")
        if term.strip()
    ]
    exclude_keywords = [
        term.strip()
        for term in (
            os.getenv("PRECEDENT_EXCLUDE_KEYWORDS")
            or "종합부동산세,양도소득세,취득세,농지,조합원입주권,분양권,조세,세법,부가가치세,법인세,종합소득세,선박,해상"
        ).split(",")
        if term.strip()
    ]
    if not must_keywords:
        return items
    filtered: List[Precedent] = []
    for item in items:
        text = " ".join(
            [
                item.case_name or "",
                item.summary or "",
                item.key_paragraph or "",
            ]
        )
        if exclude_keywords and any(k in text for k in exclude_keywords):
            continue
        if any(k in text for k in must_keywords):
            filtered.append(item)
    # Deduplicate by normalized case_name (fallback to case_id)
    seen = set()
    deduped: List[Precedent] = []
    for item in filtered:
        key = (item.case_name or "").strip()
        if not key:
            key = (item.case_id or "").strip()
        if not key:
            continue
        norm = " ".join(key.split())
        if norm in seen:
            continue
        seen.add(norm)
        deduped.append(item)
    return deduped


def search_precedents_by_vector(embedding: List[float], limit: int = 5) -> List[Precedent]:
    matches = _query_by_vector(embedding, limit=limit)
    return [_to_precedent(match) for match in matches]
