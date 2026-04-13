# CanSi — Can I Sign This?

AI 기반 계약서 분석 서비스  
“사인하기 전에, AI에게 한 번 더 묻다”

---

## 1. Problem

일반 사용자는 계약서의 복잡한 법률 용어로 인해  
불리한 조건을 인지하지 못한 채 서명하는 문제가 발생합니다.

- 정보 비대칭 → 불공정 계약
- 법률 지식 부족 → 리스크 판단 어려움
- 전문가 의존 → 비용 부담

---

## 2. Solution

CanSi는 OCR과 AI를 활용하여 계약서를 분석하고  
사용자가 이해 가능한 형태로 정보를 제공합니다.

- 위험 조항 자동 탐지
- 쉬운 언어 설명
- 협상 질문 및 수정 문구 제공
- 계약 리스크 요약

---

## 3. User Flow

Upload Contract
↓
Text Extraction (OCR)
↓
Clause Structuring
↓
Risk Detection
↓
Explanation & Suggestion
↓
Result Storage

---

## 4. Architecture

User
↓
Frontend (Flutter)
↓
Backend (FastAPI)
↓
AI Pipeline

OCR
Clause Split
Risk Detection
Summarization
Suggestion Generation
↓
PostgreSQL / Supabase Storage

---

## 5. AI Pipeline

1. Document Extraction  
   - PDF / Image → Text

2. Clause Structuring  
   - 계약서를 조항 단위로 분리

3. Risk Detection  
   - 위험 수준 분류

4. Reason Generation  
   - 위험 사유 설명 생성

5. Action Generation  
   - 협상 질문  
   - 대체 문구  
   - 요약

---

## 6. API

| Method | Endpoint | Description |
|--------|--------|------------|
| POST | /analyze/file | 계약서 분석 |
| GET | /history | 분석 이력 조회 |
| GET | /analysis/{id} | 분석 상세 |
| GET | /files | 파일 목록 |
| GET | /profile | 사용자 조회 |
| PUT | /profile | 사용자 수정 |

---

## 7. Data Structure

- users
- user_files
- analysis_history
User → Files → Analysis History

---

## 8. Tech Stack

- Frontend: Flutter
- Backend: FastAPI (Python 3.11)
- AI: OpenAI API
- OCR: Upstage OCR
- Database: PostgreSQL
- Storage: Supabase
- Infra: Docker
- Environment: WSL2

---

## 9. Run

docker compose up -d --build

---

## 10. Key Points

- 계약서를 조항 단위로 구조화하여 분석
- 단순 결과가 아닌 사용자 행동을 돕는 정보 제공
- FastAPI + DB + Storage 기반 서비스 구조
- Docker 기반 개발 환경 구축

---

## 11. Troubleshooting

- OCR 결과 없음 → fallback 처리 필요
- 파일명 깨짐 → UTF-8 보정
- DB 컬럼 변경 → 런타임 대응
- 분석 속도 → 캐싱 구조 적용

---

## 12. Limitations

- OCR 품질에 의존
- 법률 도메인 특화 부족
- 리스크 판단 기준 정량화 필요

---

## 13. Roadmap

- JWT 인증 적용
- 비밀번호 해시 처리
- 비동기 분석 구조 (Queue)
- RAG 기반 법령 연동
- 성능 평가 지표 추가

---

## 14. Contribution

- AI 분석 파이프라인 설계 및 구현
- FastAPI 백엔드 개발
- DB 구조 설계
- Docker 환경 구축

---

## 15. Summary

이 프로젝트는 단순한 문서 분석이 아니라  
사용자가 실제로 판단하고 행동할 수 있도록 돕는 AI 시스템을 목표로 합니다.
