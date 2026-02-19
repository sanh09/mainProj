# CanSi Backend API 비용 효율화 계획

## Context

CanSi 8단계 파이프라인이 계약서 1건당 외부 API를 **~430-600회** 호출한다. OpenAI Chat ~43회, OpenAI Embedding ~70회, law.go.kr ~320-480회, Upstage OCR 1회. GoalContract에 따라 **품질 > 비용 > 레이턴시** 우선순위로, 동일 품질을 유지하며 호출 수를 대폭 줄인다.

**기준**: N_clauses=15, N_risky=8, VOTES=2, DEBATE_MAX_ROUNDS=1

---

## Phase 0: 계측 (선행 필수)

### 0A. `api_call_counter.py` 신규 모듈

thread-local 카운터. `ApiCallCounter.track()` context manager로 파이프라인을 감싸고, 각 외부 API 호출 지점에 `record()` 삽입.

**삽입 지점**:
- `openai_client.py:30` → `"openai_chat:{model}"`
- `embedding_manager.py:30` → `"openai_embedding"`
- `risk_assessor.py:105` → `"openai_chat:risk"`
- `precedent_fetcher.py` 검색/상세 요청 → `"lawgokr_precedent_search"`, `"lawgokr_precedent_detail"`
- `law_fetcher.py` 검색/상세 요청 → `"lawgokr_law_search"`, `"lawgokr_law_detail"`

**pipeline.py `analyze()`**: `with ApiCallCounter.track() as counter:` 래핑 후 `counter.summary()` 출력.

---

## Phase 1: 무위험 최적화 (품질 영향 없음)

### 1A. 조항 임베딩 4중 호출 제거

**문제**: `pipeline.py:219-230, 438, 455` — 동일 clause_text가 `find_similar_precedents`, `find_similar_laws`, `_merge_chunk_precedents`, `_merge_chunk_laws`에서 각각 임베딩 생성 = **4회 호출**.

**수정**:
- `embedding_manager.py` — `find_similar_precedents_with_embedding(embedding, items, top_k)`, `find_similar_laws_with_embedding(embedding, items, top_k)` 메서드 추가
- `pipeline.py` step 5 루프 — clause_text 임베딩을 1회 생성 후 4곳에 전달
- `pipeline.py:433-468` — `_merge_chunk_precedents`, `_merge_chunk_laws`에 embedding 파라미터 추가

**절감**: N_risky × 4 → N_risky × 1 = **24 embedding 호출 절감**

### 1B. `attach_embeddings` 배치화

**문제**: `embedding_manager.py:69-84` — 법령/판례 임베딩을 개별 루프로 생성. OpenAI Embedding API는 list input을 지원.

**수정**:
- `embedding_manager.py` — `generate_embeddings_batch(texts: list[str])` 메서드 추가
- `attach_embeddings()` — 텍스트를 모아서 1회 배치 호출로 변경

**절감**: ~30 → 2 호출 = **~28 embedding 호출 절감**

### 1C. 분석 내 임베딩 캐시

**문제**: `generate_embedding()` 호출마다 새 API 요청. store 검색(`precedent_store.py:272`, `law_store.py:259`)에서도 매번 새 `EmbeddingManager` 인스턴스 생성.

**수정**:
- `embedding_manager.py` — `self._cache: dict[str, list[float]]` 추가. `generate_embedding()`에서 캐시 확인 후 hit이면 API 스킵
- `precedent_store.py`, `law_store.py` — `search_*()` 함수에 `embedding_manager` 파라미터 추가 (선택적)
- `precedent_fetcher.py`, `law_fetcher.py` — 파이프라인의 `self.embedding_manager`를 store 함수에 전달

**절감**: **~4-8 embedding 호출 절감** (쿼리 중복도에 따라)

### Phase 1 결과

| 카테고리 | Before | After | 절감 |
|----------|--------|-------|------|
| OpenAI Embedding | 62-78 | 12-18 | **~50-60 (77%)** |
| OpenAI Chat | 43 | 43 | 0 |

---

## Phase 2: 저위험 최적화 (검증 필요, 품질 영향 미미)

### 2A. law.go.kr 페이지네이션 축소

**문제**: `precedent_fetcher.py:27-28`, `law_fetcher.py:43-44` — MAX_PAGES=5, PAGE_SIZE=20 (최대 100건), 실제 사용은 top-3.

**수정**: 기본값 변경 (기존 환경변수로 롤백 가능)
- `precedent_fetcher.py:27-28` → `page_size=10, max_pages=2`
- `law_fetcher.py:43-44` → `page_size=10, max_pages=2`

**절감**: law.go.kr 호출 **~60% 감소** (~190-280 호출)

**검증**: 동일 문서 5건으로 old/new 설정 비교, top-3 판례/법령 overlap률 >= 90% 확인.

### 2B. law.go.kr 쿼리 중복 제거 (스코프 축소)

**문제**: `pipeline.py:133-166` — forced_domain_keywords가 모든 조항에 동일. 같은 카테고리의 조항은 거의 동일 쿼리 생성.

**수정**: `pipeline.py` step 4 — law.go.kr API 호출만 중복 제거. Pinecone 캐시 검색(임베딩 기반)은 조항별 유지.
1. 고유 쿼리 맵 구축 (`query → [clause, ...]`)
2. law.go.kr fetch는 고유 쿼리별 1회만 실행
3. Pinecone 캐시 lookup(`precedent_store.search_precedents`, `law_store.search_laws`)은 기존대로 조항별 수행 — 후보 풀 다양성 유지

**Gap 반영**: 전체 쿼리 중복 제거 시 step 5 후보 풀 축소 → 품질 위험. law.go.kr 호출만 중복 제거하고, 임베딩 기반 검색은 조항별 유지하여 후보 풀 다양성을 보전.

**절감**: law.go.kr API 호출 ~50% 추가 감소 (Pinecone 쿼리는 유지)

**검증**: 결과 조항별 related_precedents/laws 일치 확인.

### 2C. UI payload 생성 병렬화

**문제**: `pipeline.py:275-292` — 순차 루프. 각 호출은 독립적.

**수정**: `ThreadPoolExecutor` 적용 (risk_assessor.py와 동일 패턴). `UI_PAYLOAD_WORKERS` 환경변수.

**절감**: API 호출 수 동일, **레이턴시 ~4배 개선**.

### Phase 2 결과 (누적)

| 카테고리 | Phase 1 후 | Phase 2 후 | 누적 절감 |
|----------|-----------|-----------|----------|
| OpenAI Embedding | 12-18 | 12-18 | ~50-60 |
| OpenAI Chat | 43 | 43 | 0 |
| law.go.kr | 320-480 | 33-50 | **~290-430 (85%)** |

---

## Phase 3: 고영향 변경 (품질 검증 필수)

### 3A. 위험 평가 배치화

**문제**: `risk_assessor.py` — N_clauses × VOTES 개별 호출 (30 calls).

**수정**:
- `risk_assessor.py` — `_assess_batch(clauses, batch_size)` 메서드 추가. 5개 조항을 한 프롬프트에 묶어 JSON 배열로 응답 요청
- `filter_risky_clauses()` — `RISK_BATCH_SIZE` 환경변수로 배치 모드 활성화 (기본 0 = 비활성)
- 기존 heuristic merge는 배치 결과에도 동일 적용

**절감**: 30 → 6 = **24 chat 호출 절감**

**품질 위험**: 중간. 다중 조항 프롬프트에서 상호 오염 가능.
**검증**: 5+ 테스트 문서에서 개별 vs 배치 risk_level 비교. 일치율 >= 95% 및 critical/high 누락 0건 확인.

### 3B. 모델 티어링

**문제**: 모든 LLM이 o4-mini. 일부는 더 저렴한 모델로 충분.

**수정** (환경변수 설정만, 코드 변경 최소):
- `llm_summarizer.py:8` — `OPENAI_REPORT_MODEL` 환경변수 추가. `generate_comprehensive_report()`, `generate_debate_summary()`, `generate_overall_debate_summary()`에 적용
- debate, report → `gpt-4.1-mini` (o4-mini 대비 ~60-70% 저렴)
- risk assessment, UI payload → o4-mini 유지 (품질 민감)

| 호출 | 현재 모델 | 제안 모델 | 이유 |
|------|-----------|-----------|------|
| 위험 평가 | o4-mini | o4-mini 유지 | 핵심 정확도 |
| 토론 (3 calls) | o4-mini | gpt-4.1-mini | 주관적 콘텐츠 |
| UI payload | o4-mini | o4-mini 유지 | 사용자 대면 |
| 리포트/요약 (2-3 calls) | o4-mini | gpt-4.1-mini | 요약 작업 |

**절감**: 호출 수 동일, **단가 ~15% 절감** (5-6 calls에 적용)

**검증**: 토론/요약 품질 side-by-side 비교.

### Phase 3 결과 (최종 누적)

| 카테고리 | Baseline | 최종 | 절감률 |
|----------|----------|------|--------|
| OpenAI Chat | 43 | ~19 | **56%** |
| OpenAI Embedding | 70 | ~14 | **80%** |
| law.go.kr | 400 | ~40 | **90%** |
| **총 외부 호출** | **~513** | **~74** | **~86%** |

---

## 수정 대상 파일

| 파일 | Phase | 변경 내용 |
|------|-------|----------|
| `api_call_counter.py` (신규) | 0 | 카운터 모듈 |
| `embedding_manager.py` | 1A,1B,1C | 배치, 캐시, with_embedding 메서드 |
| `pipeline.py` | 1A,2B,2C | 임베딩 재사용, 쿼리 중복 제거, UI 병렬화 |
| `risk_assessor.py` | 3A | 배치 평가 메서드 |
| `llm_summarizer.py` | 3B | report_model 환경변수 |
| `precedent_fetcher.py` | 1C,2A | embedding_manager 전달, 페이지 기본값 |
| `law_fetcher.py` | 1C,2A | embedding_manager 전달, 페이지 기본값 |
| `precedent_store.py` | 1C | embedding_manager 파라미터 |
| `law_store.py` | 1C | embedding_manager 파라미터 |

## 검증 전략

별도 계획으로 분리. 이 계획은 최적화 구현에 집중하며, Phase 0의 `ApiCallCounter`가 before/after 측정을 담당.

## 향후 검토 (Phase 4 후보)

- **OpenAI Batch API**: 비동기 처리, 동기 대비 50% 저렴. 실시간 파이프라인에는 부적합하나, 배경 pre-computation에 적용 가능. 별도 검토 예정.

## 구현 순서

```
Phase 0 (계측) ──────────────────── 선행 필수
  │
Phase 1A (임베딩 중복 제거) ──┐
Phase 1B (배치 임베딩) ───────├── 병렬 가능
Phase 1C (임베딩 캐시) ───────┘
  │
Phase 2A (페이지네이션 축소) ─┐
Phase 2B (쿼리 중복 제거) ────├── 병렬 가능
Phase 2C (UI 병렬화) ─────────┘
  │
Phase 3A (배치 위험 평가) ────┐
Phase 3B (모델 티어링) ───────┘── Phase 0 카운터로 검증
```

---

## Task Tracker

### Implementation Tasks (pending)

| ID | Phase | Task | 상태 | 파일 |
|----|-------|------|------|------|
| #5 | 1A | Embedding quadruplication: same clause text embedded 4x per risky clause | done | `pipeline.py:219-230,438,455`, `embedding_manager.py` |
| #6 | 1B | attach_embeddings loops item-by-item instead of using batch API | done | `embedding_manager.py:69-84` |
| #7 | 1C | Store search functions create fresh EmbeddingManager and re-embed queries | done | `precedent_store.py:269-273`, `law_store.py:256-260`, `precedent_fetcher.py`, `law_fetcher.py` |
| #8 | 2A,2B | law.go.kr over-fetching: 100 results fetched per search, only top-3 used | done | `precedent_fetcher.py:27-28`, `law_fetcher.py:43-44`, `pipeline.py:133-166` |
| #9 | 2C | UI payload generation is sequential with no batching | done | `pipeline.py:275-292` |
| — | 0 | `ApiCallCounter` 신규 모듈 | done | `api_call_counter.py` (신규), `pipeline.py`, 각 모듈 |
| — | 3A | 위험 평가 배치화 (`RISK_BATCH_SIZE`) | done | `risk_assessor.py` |
| — | 3B | 모델 티어링 (`OPENAI_REPORT_MODEL`) | done | `llm_summarizer.py` |

### Gap Audit (resolved)

| ID | 유형 | Gap | 결정 |
|----|------|-----|------|
| #10 | Consideration | 2B 쿼리 중복 제거가 step 5 후보 풀 축소 | **2B 스코프 축소**: law.go.kr 쿼리만 중복 제거, Pinecone 검색은 조항별 유지 |
| #11 | Procedural | 자동화된 회귀 테스트 인프라 부재 | **별도 계획**: 최적화와 테스트 인프라 분리 |
| #12 | Consideration | 임베딩 캐시와 ThreadPoolExecutor 스레드 안전성 | **비해당**: 현재 구조에서 EmbeddingManager에 대한 동시 접근 없음 |
| #13 | Alternative | OpenAI Batch API (비동기, 50% 할인) 미검토 | **Phase 4 후보**: 실시간 파이프라인에 부적합, 배경 작업에 향후 적용 검토 |
