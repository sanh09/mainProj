# API 비용 효율화 — 구현 태스크

> `cost-optimization-plan.md`의 구현 항목을 태스크로 구조화. Deferred 상태로 관리.

## Phase 0: 계측

- [x] **0A. ApiCallCounter 모듈 신규 생성**
  - `api_call_counter.py` 신규, `pipeline.py` 래핑, 각 모듈에 `record()` 삽입
  - 선행 필수 — 이후 모든 Phase의 before/after 측정 기반

## Phase 1: 무위험 최적화

- [x] **1A. 조항 임베딩 4중 호출 제거** (#5)
  - `embedding_manager.py` — `find_similar_*_with_embedding()` 메서드 추가
  - `pipeline.py:219-230, 438, 455` — clause embedding 1회 생성 후 4곳에 전달
  - 절감: N_risky × 4 → N_risky × 1 (24 embedding 호출)

- [x] **1B. attach_embeddings 배치화** (#6)
  - `embedding_manager.py:69-84` — `generate_embeddings_batch()` 추가, 루프를 1회 배치 호출로 변경
  - 절감: ~30 → 2 호출 (28 embedding 호출)

- [x] **1C. 분석 내 임베딩 캐시** (#7)
  - `embedding_manager.py` — `self._cache` dict 추가
  - `precedent_store.py:269-273`, `law_store.py:256-260` — `embedding_manager` 파라미터 추가
  - `precedent_fetcher.py`, `law_fetcher.py` — 파이프라인의 embedding_manager 전달
  - 절감: ~4-8 embedding 호출

## Phase 2: 저위험 최적화

- [x] **2A. law.go.kr 페이지네이션 축소** (#8)
  - `precedent_fetcher.py:27-28` → `page_size=10, max_pages=2`
  - `law_fetcher.py:43-44` → `page_size=10, max_pages=2`
  - 절감: law.go.kr 호출 ~60%

- [x] **2B. law.go.kr 쿼리 중복 제거** (#8)
  - `pipeline.py:133-166` — 고유 쿼리 맵 기반 law.go.kr fetch (Pinecone 검색은 조항별 유지)
  - 절감: law.go.kr 호출 추가 ~50%

- [x] **2C. UI payload 생성 병렬화** (#9)
  - `pipeline.py:275-292` — `ThreadPoolExecutor` 적용, `UI_PAYLOAD_WORKERS` 환경변수
  - 절감: 레이턴시 ~4배 개선 (호출 수 동일)

## Phase 3: 고영향 변경

- [x] **3A. 위험 평가 배치화**
  - `risk_assessor.py` — `_assess_batch()` 메서드, `RISK_BATCH_SIZE` 환경변수
  - 절감: 30 → 6 chat 호출 (품질 검증 필수)

- [x] **3B. 모델 티어링**
  - `llm_summarizer.py` — `OPENAI_REPORT_MODEL` 환경변수 추가
  - debate/report → `gpt-4.1-mini`, risk/UI payload → o4-mini 유지
  - 절감: 단가 ~15%

## Gap Audit 결과

| Gap | 결정 |
|-----|------|
| 2B 후보 풀 축소 위험 | law.go.kr 쿼리만 중복 제거, Pinecone 검색은 조항별 유지 |
| 회귀 테스트 인프라 부재 | 별도 계획으로 분리 |
| 임베딩 캐시 스레드 안전성 | 현재 구조에서 비해당 |
| OpenAI Batch API | Phase 4 후보로 보류 |
