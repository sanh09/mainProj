import argparse
import hashlib
import os
from typing import Dict, Iterable, List, Tuple

from pinecone import Pinecone


INDEX_NAME = os.getenv("PINECONE_INDEX_NAME", "law-db")
PINECONE_API_KEY = os.getenv("PINECONE_API_KEY", "")
EMBEDDING_DIM = int(os.getenv("EMBEDDING_DIM", "1536"))

PRECEDENT_NS = os.getenv("PINECONE_NAMESPACE_PRECEDENT", "precedents")
LAW_NS = os.getenv("PINECONE_NAMESPACE_LAW", "laws")
PRECEDENT_CHUNK_NS = os.getenv("PINECONE_NAMESPACE_PRECEDENT_CHUNKS", "precedent_chunks")
LAW_CHUNK_NS = os.getenv("PINECONE_NAMESPACE_LAW_CHUNKS", "law_chunks")


def _chunk_text(text: str, chunk_size: int, overlap: int) -> List[str]:
    normalized = (text or "").strip()
    if not normalized:
        return []
    if chunk_size <= 0:
        return [normalized]

    chunks: List[str] = []
    step = max(1, chunk_size - max(0, overlap))
    start = 0
    while start < len(normalized):
        chunk = normalized[start : start + chunk_size].strip()
        if chunk:
            chunks.append(chunk)
        start += step
    return chunks


def _hash_embedding(text: str, dim: int) -> List[float]:
    # Cheap deterministic embedding surrogate for bulk chunk indexing.
    if dim <= 0:
        return []
    digest = hashlib.sha256(text.encode("utf-8")).digest()
    vec = [0.0] * dim
    for i in range(0, 32, 4):
        block = digest[i : i + 4]
        pos = int.from_bytes(block, "big") % dim
        sign = 1.0 if (block[0] % 2 == 0) else -1.0
        mag = ((block[1] + 1) / 256.0) * 0.75 + 0.25
        vec[pos] = sign * mag
    if all(v == 0.0 for v in vec):
        vec[0] = 1e-3
    return vec


def _iter_ids(index, namespace: str) -> Iterable[str]:
    for page in index.list(namespace=namespace):
        if isinstance(page, list):
            for item in page:
                if item:
                    yield str(item)


def _fetch_metadata_map(index, namespace: str, ids: List[str]) -> Dict[str, dict]:
    if not ids:
        return {}
    out: Dict[str, dict] = {}
    batch_size = 100
    for i in range(0, len(ids), batch_size):
        batch = ids[i : i + batch_size]
        res = index.fetch(ids=batch, namespace=namespace)
        vectors = res.get("vectors", {}) if isinstance(res, dict) else getattr(res, "vectors", {})
        if isinstance(vectors, dict):
            for vid, payload in vectors.items():
                metadata = payload.get("metadata", {}) if isinstance(payload, dict) else getattr(payload, "metadata", {})
                out[str(vid)] = metadata or {}
    return out


def _build_precedent_text(md: dict) -> Tuple[str, str]:
    title = str(md.get("case_name", "")).strip()
    body = "\n".join(
        [
            title,
            str(md.get("summary", "")).strip(),
            str(md.get("key_paragraph", "")).strip(),
        ]
    ).strip()
    return title, body


def _build_law_text(md: dict) -> Tuple[str, str]:
    title = str(md.get("title", "")).strip()
    body = "\n".join(
        [
            title,
            str(md.get("summary", "")).strip(),
            str(md.get("content", "")).strip(),
        ]
    ).strip()
    return title, body


def _upsert_chunks(
    index,
    source_ns: str,
    target_ns: str,
    kind: str,
    chunk_size: int,
    overlap: int,
    limit_docs: int,
) -> Tuple[int, int]:
    ids = list(_iter_ids(index, source_ns))
    if limit_docs > 0:
        ids = ids[:limit_docs]

    metadata_map = _fetch_metadata_map(index, source_ns, ids)
    vectors: List[dict] = []
    doc_count = 0
    chunk_count = 0

    for src_id in ids:
        md = metadata_map.get(src_id, {})
        if kind == "precedent":
            title, text = _build_precedent_text(md)
        else:
            title, text = _build_law_text(md)
        chunks = _chunk_text(text, chunk_size=chunk_size, overlap=overlap)
        if not chunks:
            continue
        doc_count += 1
        for i, chunk in enumerate(chunks):
            chunk_id = f"{kind}_chunk:{src_id}:{i}"
            vec = _hash_embedding(chunk, EMBEDDING_DIM)
            vectors.append(
                {
                    "id": chunk_id,
                    "values": vec,
                    "metadata": {
                        "doc_type": f"{kind}_chunk",
                        "source_namespace": source_ns,
                        "source_id": src_id,
                        "title": title,
                        "chunk_index": i,
                        "chunk_text": chunk,
                    },
                }
            )
            chunk_count += 1

    batch_size = 100
    for i in range(0, len(vectors), batch_size):
        index.upsert(vectors=vectors[i : i + batch_size], namespace=target_ns)

    return doc_count, chunk_count


def _counts(index) -> dict:
    stats = index.describe_index_stats()
    if isinstance(stats, dict):
        ns = stats.get("namespaces", {})
        total = int(stats.get("total_vector_count", 0))
    else:
        ns = getattr(stats, "namespaces", {}) or {}
        total = int(getattr(stats, "total_vector_count", 0) or 0)
    return {"namespaces": ns, "total": total}


def main() -> int:
    parser = argparse.ArgumentParser(description="Expand existing Pinecone docs into chunk vectors.")
    parser.add_argument("--chunk-size", type=int, default=550)
    parser.add_argument("--overlap", type=int, default=120)
    parser.add_argument("--limit-docs", type=int, default=0, help="0 means all docs in each source namespace")
    args = parser.parse_args()

    if not PINECONE_API_KEY:
        print("PINECONE_API_KEY is missing.")
        return 1

    pc = Pinecone(api_key=PINECONE_API_KEY)
    index = pc.Index(INDEX_NAME)

    before = _counts(index)
    print(f"BEFORE total={before['total']} namespaces={before['namespaces']}")

    p_docs, p_chunks = _upsert_chunks(
        index=index,
        source_ns=PRECEDENT_NS,
        target_ns=PRECEDENT_CHUNK_NS,
        kind="precedent",
        chunk_size=args.chunk_size,
        overlap=args.overlap,
        limit_docs=args.limit_docs,
    )
    print(f"precedent chunks: docs={p_docs}, chunks={p_chunks}, target_ns={PRECEDENT_CHUNK_NS}")

    l_docs, l_chunks = _upsert_chunks(
        index=index,
        source_ns=LAW_NS,
        target_ns=LAW_CHUNK_NS,
        kind="law",
        chunk_size=args.chunk_size,
        overlap=args.overlap,
        limit_docs=args.limit_docs,
    )
    print(f"law chunks: docs={l_docs}, chunks={l_chunks}, target_ns={LAW_CHUNK_NS}")

    after = _counts(index)
    print(f"AFTER total={after['total']} namespaces={after['namespaces']}")
    print(f"DELTA total={after['total'] - before['total']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

