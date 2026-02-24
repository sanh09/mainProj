# CanSi - 계약서 독소조항 분석 시스템 (Backend)

## 개요
CanSi는 계약서(PDF/이미지)의 텍스트를 추출하고, 위험(독소) 조항을 분석해 요약/토론 결과를 제공합니다.

## 주요 기능
- GPT API 기반 문서 추출 (Markdown/JSON)
- 조항 분리 및 위험 조항 판별 (Rule-based + LLM)
- 판례 검색 연동 (법령정보 Open API DRF)
- 임대인/임차인 변호사 토론 생성
- LLM 기반 요약 리포트 생성

---

## 파이프라인 흐름
```
1) GPT 문서 추출 -> Markdown/JSON + 메타데이터
2) 텍스트 정제 / 조항 분리
3) 위험 조항 필터링 (LLM)
4) 판례 검색 (law.go.kr DRF)
5) 임베딩 유사도 검색
6) 위험 유형 매핑
7) 변호사 토론 생성
8) LLM 요약 리포트 생성
```

---

## 설치
```bash
pip install requests openai pypdf
pip install fastapi uvicorn  # API 사용 시
```

---

## 환경변수
### 필수
- `OPENAI_API_KEY`: OpenAI API 키
- `UPSTAGE_API_KEY`: Upstage OCR API key
- `UPSTAGE_API_KEY`: Upstage OCR API 키

### 선택 (문서 추출)
- `DOC_EXTRACT_OUTPUT_FORMAT`: `markdown` 또는 `json` (기본 `markdown`)
- `DOC_EXTRACT_MAX_INPUT_CHARS`: 텍스트 입력 상한 (기본 `50000`)

### 선택 (판례)
- `PRECEDENT_API_URL`: `https://www.law.go.kr/DRF/lawSearch.do`
- `PRECEDENT_API_KEY`: 법령정보 Open API 발급 OC 값
- `LAW_API_URL`: `https://www.law.go.kr/DRF/lawSearch.do` (기본값: `PRECEDENT_API_URL`)
- `LAW_API_KEY`: 법령정보 Open API OC 값 (기본값: `PRECEDENT_API_KEY`)
- `LAW_TARGETS`: `law,ordin` (현행법령, 자치법규)
- `LAW_MIN_RESULTS`: clause 당 최소 결과 수 (기본 3)
- `LAW_DETAIL_LIMIT`: 상세 본문 호출 제한 (기본 10)
- `LAW_DOMAIN_KEYWORDS`: 법령 결과 필터 키워드 (기본: 부동산,임대차,임대,임차,주택,전세,월세,보증금)
- `LAW_TITLE_MUST_KEYWORDS`: 법령명에 반드시 포함될 키워드 (기본: 주택임대차보호법)
- `LAW_BASE_QUERY`: 법령 기본 조회어 (기본: 주택임대차보호법)

#### Windows (PowerShell)
```powershell
$env:OPENAI_API_KEY = "your-openai-key"
$env:UPSTAGE_API_KEY = "your-upstage-key"
$env:DOC_EXTRACT_OUTPUT_FORMAT = "markdown"
$env:PRECEDENT_API_URL = "https://www.law.go.kr/DRF/lawSearch.do"
$env:PRECEDENT_API_KEY = "your-oc"
$env:LAW_API_URL = "https://www.law.go.kr/DRF/lawSearch.do"
$env:LAW_API_KEY = "your-oc"
$env:LAW_TARGETS = "law,ordin"
$env:LAW_DOMAIN_KEYWORDS = "부동산,임대차,임대,임차,주택,전세,월세,보증금"
$env:LAW_TITLE_MUST_KEYWORDS = "주택임대차보호법"
$env:LAW_BASE_QUERY = "주택임대차보호법"
```

#### Windows (cmd)
```cmd
set OPENAI_API_KEY=your-openai-key
set UPSTAGE_API_KEY=your-upstage-key
set DOC_EXTRACT_OUTPUT_FORMAT=markdown
set PRECEDENT_API_URL=https://www.law.go.kr/DRF/lawSearch.do
set PRECEDENT_API_KEY=your-oc
set LAW_API_URL=https://www.law.go.kr/DRF/lawSearch.do
set LAW_API_KEY=your-oc
set LAW_TARGETS=law,ordin
set LAW_DOMAIN_KEYWORDS=부동산,임대차,임대,임차,주택,전세,월세,보증금
set LAW_TITLE_MUST_KEYWORDS=주택임대차보호법
set LAW_BASE_QUERY=주택임대차보호법
```

> 주의: 키 값에 따옴표(`'`, `"`)가 포함되면 인증이 실패합니다.

---

## 빠른 실행 (CLI)
> `backend` 폴더에서 실행
```bash
python -c "from pipeline import ContractAnalysisPipeline; p=ContractAnalysisPipeline(); r=p.analyze(r'부동산_임대차_계약서_독소조항_상세_한글정상.pdf'); print(r.contract_type); print(len(r.clauses), len(r.risky_clauses)); print(r.llm_summary)"
```

결과 JSON 저장:
```bash
python -c "from pipeline import ContractAnalysisPipeline; p=ContractAnalysisPipeline(); r=p.analyze(r'부동산_임대차_계약서_독소조항_상세_한글정상.pdf'); p.export_result(r, r'analysis_result.json')"
```

---

## FastAPI 실행
```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

### API 예시
```bash
curl http://127.0.0.1:8000/health
curl -X POST "http://127.0.0.1:8000/analyze/file" ^
  -H "accept: application/json" ^
  -H "Content-Type: multipart/form-data" ^
  -F "file=@contract.pdf"
```

---

## 결과 형식 (pipeline.export_result)
```json
{
  "filename": "contract.pdf",
  "total_clauses": 10,
  "risky_clauses_count": 4,
  "clauses": [],
  "risky_clauses": [],
  "precedents": [],
  "laws": [],
  "summary": "...",
  "debate_transcript": [],
  "contract_type": "jeonse"
}
```

---

## 판례 API (law.go.kr DRF)
이 시스템은 `law.go.kr` DRF API를 사용합니다.
- `PRECEDENT_API_URL`에는 기본 엔드포인트만 넣고,
- 요청 시 코드에서 `OC/target/type/query` 파라미터를 자동으로 추가합니다.

직접 테스트:
```
https://www.law.go.kr/DRF/lawSearch.do?OC=YOUR_OC&target=prec&type=JSON&query=임대차
```

---

## 디버깅 팁
- **문서 추출 실패**: `OPENAI_API_KEY` 확인, `openai/pypdf` 설치 여부 확인
- **판례 응답이 HTML**: URL이 API 엔드포인트가 아니거나 파라미터 누락
- **조항 분리 0개**: OCR 텍스트 확인 및 `text_processor.py`의 패턴 검토

---

## 파일 구조
```
backend/
  app/main.py
  pipeline.py
  ocr.py
  text_processor.py
  risk_assessor.py
  precedent_fetcher.py
  law_fetcher.py
  embedding_manager.py
  risk_mapper.py
  debate_agents.py
  llm_summarizer.py
  openai_client.py
  models.py
```

---

## Debate settings
- `DEBATE_MAX_ROUNDS`: maximum debate rounds (default now 2)

### Windows (PowerShell)
```powershell
$env:DEBATE_MAX_ROUNDS = "2"
```

### Windows (cmd)
```cmd
set DEBATE_MAX_ROUNDS=2
```

