📄 CanSi — Can I Sign This?

AI 기반 계약서 분석 서비스
“사인하기 전에, AI에게 한 번 더 묻다”

🧩 1. 문제 정의 (Problem)

일반 사용자는 계약서의 복잡한 법률 용어와 구조로 인해
불리한 조건을 인지하지 못한 채 서명하는 문제가 발생합니다.

정보 비대칭 → 불공정 계약
법률 지식 부족 → 리스크 판단 어려움
전문가 의존 → 비용 부담
💡 2. 해결 방법 (Solution)

CanSi는 OCR + AI를 활용하여 계약서를 분석하고
사용자가 이해 가능한 형태로 재구성합니다.

🔍 위험 조항 자동 탐지
📖 쉬운 언어로 설명
💬 협상 질문 및 수정 문구 제공
📊 리스크 요약 제공
👤 3. 사용자 흐름 (User Flow)
계약서 업로드
    ↓
텍스트 추출 (OCR)
    ↓
조항 분리 및 구조화
    ↓
위험 조항 분석
    ↓
설명 + 협상 정보 생성
    ↓
결과 저장 및 조회
🏗 4. 시스템 아키텍처
[User]
   ↓
[Flutter Frontend]
   ↓
[FastAPI Backend]
   ↓
 ┌────────────────────────────┐
 │   AI Pipeline              │
 │  - OCR                     │
 │  - Clause Split            │
 │  - Risk Detection          │
 │  - Summarization           │
 │  - Suggestion Generation   │
 └────────────────────────────┘
   ↓
[PostgreSQL / Supabase Storage]
⚙️ 5. AI 분석 파이프라인
1. 문서 추출
PDF/이미지 → 텍스트 변환
2. 조항 분리
계약서를 조항 단위로 구조화
3. 위험 조항 탐지
리스크 수준 분류
4. 위험 사유 생성
자연어 설명 생성
5. 사용자 액션 생성
협상 질문
대체 문구
요약
🔌 6. API
Method	Endpoint	설명
POST	/analyze/file	계약서 분석
GET	/history	분석 이력
GET	/analysis/{id}	분석 상세
GET	/files	파일 목록
GET	/profile	사용자 조회
PUT	/profile	사용자 수정
🗄 7. 데이터 구조
users
user_files
analysis_history
User → Files → Analysis History
🛠 8. 기술 스택
영역	기술
Frontend	Flutter
Backend	FastAPI (Python 3.11)
AI	OpenAI API
OCR	Upstage OCR
DB	PostgreSQL
Storage	Supabase
Infra	Docker
Env	WSL2
🐳 9. 실행 방법
docker compose up -d --build
⚡ 10. 핵심 구현 포인트
계약서를 조항 단위로 구조화하여 분석
단순 결과가 아닌 사용자 행동(협상/판단)을 돕는 정보 제공
FastAPI + DB + Storage를 연결한 실서비스 구조
Docker 기반 실행 환경 구축
🔥 11. 트러블슈팅
OCR 결과 없음 → fallback 처리 필요
파일명 깨짐 → UTF-8 보정
DB 컬럼 변경 → 런타임 자동 처리
분석 속도 → 캐싱 구조 적용
⚠️ 12. 한계
OCR 품질에 의존
법률 도메인 특화 부족
리스크 판단 기준 정량화 필요
🚀 13. 개선 방향
JWT 인증 추가
비밀번호 해시 적용
비동기 분석 처리 (Queue)
RAG 기반 법령 연동
성능 평가 지표 추가
👨‍💻 14. 기여
AI 분석 파이프라인 설계 및 구현
FastAPI 백엔드 개발
DB 구조 설계
Docker 환경 구축
✨ 15. 프로젝트 가치

단순한 문서 분석이 아니라
사용자가 실제로 판단하고 행동할 수 있도록 돕는 AI 시스템을 목표로 합니다.
