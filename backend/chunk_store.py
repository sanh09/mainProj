import os
from typing import Iterable, List

try:
    from pinecone import Pinecone
except ImportError:
    Pinecone = None  # type: ignore[assignment]

from models import Law, Precedent

PINECONE_INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "law-db")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "")
PRECEDENT_CHUNK_NS = os.getenv("PINECONE_NAMESPACE_PRECEDENT_CHUNKS", "precedent_chunks")
LAW_CHUNK_NS = os.getenv("PINECONE_NAMESPACE_LAW_CHUNKS", "law_chunks")


def _get_index():
    if not Pinecone or not PINECONE_API_KEY:
        return None
    pc = Pinecone(api_key=PINECONE_API_KEY)
    return pc.Index(PINECONE_INDEX_NAME)


def _matches(response):
    matches = getattr(response, "matches", None)
    if matches is not None:
        return matches
    if isinstance(response, dict):
        return response.get("matches", [])
    return []


def _to_precedent(match) -> Precedent:
    metadata = getattr(match, "metadata", None) or (match.get("metadata") if isinstance(match, dict) else {})
    case_id = metadata.get("source_id") or metadata.get("case_id") or ""
    title = metadata.get("title") or ""
    content = metadata.get("chunk_text") or ""
    p = Precedent(case_id=str(case_id), court="", date="", case_name=str(title), summary=str(content), key_paragraph="")
    score = getattr(match, "score", None)
    if score is not None:
        p.similarity_score = float(score)
    return p


def _to_law(match) -> Law:
    metadata = getattr(match, "metadata", None) or (match.get("metadata") if isinstance(match, dict) else {})
    doc_id = metadata.get("source_id") or metadata.get("doc_id") or ""
    title = metadata.get("title") or ""
    content = metadata.get("chunk_text") or ""
    l = Law(doc_id=str(doc_id), doc_type=str(metadata.get("doc_type", "law")), title=str(title), summary=str(content), content=str(content))
    score = getattr(match, "score", None)
    if score is not None:
        l.similarity_score = float(score)
    return l


def _query_vector(vector, namespace, top_k):
    index = _get_index()
    if index is None or not vector:
        return []
    response = index.query(vector=vector, top_k=max(int(top_k), 1), include_metadata=True, namespace=namespace)
    return _matches(response)


def search_precedent_chunks_by_vector(vector: List[float], limit: int = 5) -> List[Precedent]:
    matches = _query_vector(vector, PRECEDENT_CHUNK_NS, limit)
    return [_to_precedent(match) for match in matches]


def search_law_chunks_by_vector(vector: List[float], limit: int = 5) -> List[Law]:
    matches = _query_vector(vector, LAW_CHUNK_NS, limit)
    return [_to_law(match) for match in matches]
