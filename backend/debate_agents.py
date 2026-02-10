"""
계약서 위험 조항에 대한 변호사/검사 페르소나 토론 에이전트.
"""

import math
import os
from typing import Dict, List, Optional

from models import Clause
from openai_client import chat_completion


# 임대인 측 변호사 시스템 프롬프트 (부동산 계약서 검토용)
LANDLORD_LAWYER_SYSTEM_PROMPT = (
    "You are a lawyer representing the landlord in a real estate contract review. "  # 임대인 대리 변호사 역할
    "Reduce clauses that excessively increase the landlord's liability or costs, "  # 임대인 책임/비용 과도 조항 축소
    "and propose landlord-favorable revisions. "  # 임대인에게 유리한 수정안 제시
    "Call out core risks such as deposit return conditions, defect liability scope, "  # 보증금 반환, 하자 책임 범위 등 핵심 리스크
    "restoration obligations, late payment/termination, damage caps, and toxic clauses. "  # 원상복구, 연체/해지, 손해배상 한도, 독소조항
    "Respond in Korean."  # 한국어로 응답
)

# 임차인 측 변호사 시스템 프롬프트 (부동산 계약서 검토용)
TENANT_LAWYER_SYSTEM_PROMPT = (
    "You are a lawyer representing the tenant in a real estate contract review. "  # 임차인 대리 변호사 역할
    "Reduce clauses that are unfair or risky for the tenant, "  # 임차인에게 불리/위험한 조항 축소
    "and propose revisions needed for tenant protection. "  # 임차인 보호에 필요한 수정안 제시
    "Call out core risks such as deposit protection, repair duties, landlord notice/termination "  # 보증금 보호, 하자 수리, 통지/해지 요건
    "requirements, brokerage liability, dispute resolution, and toxic clauses. "  # 중개책임, 분쟁해결, 독소조항
    "Respond in Korean."  # 한국어로 응답
)



# 중재자 시스템 프롬프트 (판사 역할)
MEDIATOR_SYSTEM_PROMPT = (
    "You are a judge presiding over a contract clause dispute between landlord and tenant lawyers. "  # 판사 역할: 임대인/임차인 변호사 분쟁 심리
    "Maintain a firm, judicial tone and provide a concise determination-style summary. "  # 판사 톤 유지 + 간결한 결정문 스타일 요약
    "Your job is to (1) list interpretation points by each perspective, "  # 양측 관점별 해석 포인트 나열
    "(2) count the number of distinct interpretation issues, "  # 쟁점(해석 이슈) 개수 집계
    "and (3) list repeated or common interpretation points. "  # 반복/공통 해석 포인트 정리
    "Return ONLY a JSON object with the following keys:\n"
    "perspective_points: {\"landlord\": [..], \"tenant\": [..]},\n"
    "issue_count: <number>,\n"
    "common_points: [..]\n"
    "No extra text. Respond in Korean."  # JSON만 반환, 한국어로 응답
)

class DebateAgents:
    def __init__(self, model: str | None = None) -> None:
        self.model = model or os.getenv("OPENAI_DEBATE_MODEL") or "gpt-5.2"

    def run(
        self,
        clauses: List[Clause],
        raw_text: Optional[str] = None,
        rounds: int = 0,
        max_rounds: int = 3,
        contract_type: Optional[str] = None,
    ) -> List[Dict[str, str]]:
        if not os.getenv("OPENAI_API_KEY"):
            return [{"speaker": "system", "content": "API 키가 필요합니다."}]
        env_max_rounds = os.getenv("DEBATE_MAX_ROUNDS")
        if env_max_rounds:
            try:
                max_rounds = int(env_max_rounds)
            except ValueError:
                pass


        if not contract_type:
            contract_type = self._detect_contract_type(raw_text or "")
        context = self._format_clauses(clauses)
        transcript: List[Dict[str, str]] = []
        # rounds가 주어지면(>0) 그대로 사용하고, 아니면 중재자 기반 루프를 max_rounds까지 수행합니다.
        if rounds and rounds > 0:
            loop_limit = rounds
            use_mediator = False
        else:
            loop_limit = max_rounds
            use_mediator = True

        for _ in range(loop_limit):
            landlord_reply = self._reply(
                "임대인 변호사",
                LANDLORD_LAWYER_SYSTEM_PROMPT,
                contract_type,
                context,
                transcript,
            )
            transcript.append({"speaker": "임대인 변호사", "content": landlord_reply})
            tenant_reply = self._reply(
                "임차인 변호사",
                TENANT_LAWYER_SYSTEM_PROMPT,
                contract_type,
                context,
                transcript,
            )
            transcript.append({"speaker": "임차인 변호사", "content": tenant_reply})
            if use_mediator:
                mediator_reply = self._mediator_reply(
                    contract_type,
                    context,
                    transcript,
                )
                transcript.append({"speaker": "판사", "content": mediator_reply})
                if self._should_terminate(mediator_reply):
                    break
        return transcript

    def _reply(
        self,
        role: str,
        system_prompt: str,
        contract_type: str,
        context: str,
        transcript: List[Dict[str, str]],
    ) -> str:
        history = self._format_history(transcript)
        prompt = (
            f"Contract type: {contract_type}\n"
            "Below is a summary of risky clauses in a real estate contract.\n"
            f"{context}\n\n"
            "Conversation so far:\n"
            f"{history}\n\n"
            f"You are speaking as the '{role}' party. "
            "Address or refute the other side and propose concrete revisions in 3-5 sentences. "
            "If precedents or laws are provided, you MUST cite at least one precedent and one law when available. "
            "If only one type is provided, cite at least one item from that type. "
            "Include a '근거:' line listing cited items by title (and court/date if available). "
            "Respond in Korean."
        )
        return chat_completion(prompt=prompt, model=self.model, system_prompt=system_prompt)

    def _mediator_reply(
        self,
        contract_type: str,
        context: str,
        transcript: List[Dict[str, str]],
    ) -> str:
        history = self._format_history(transcript)
        prompt = (
            f"Contract type: {contract_type}\n"
            "Below is a summary of risky clauses in a real estate contract.\n"
            f"{context}\n\n"
            "Conversation so far:\n"
            f"{history}\n\n"
            "Analyze the debate and return the JSON only. "
            "If precedents or laws are provided, include at least one precedent and one law in common_points when available."
        )
        return chat_completion(
            prompt=prompt,
            model=self.model,
            system_prompt=MEDIATOR_SYSTEM_PROMPT,
        )

    @staticmethod
    def _should_terminate(mediator_reply: str) -> bool:
        # 종료 기준: issue_count <= 0이면 종료, common_points 길이가 기준 이상이면 종료
        # JSON 파싱 실패 시에는 계속 진행
        try:
            import json

            data = json.loads(mediator_reply)
            issue_count = data.get("issue_count")
            common_points = data.get("common_points") or []
            min_common = int(os.getenv("DEBATE_MIN_COMMON_POINTS", "2"))
            common_ratio = float(os.getenv("DEBATE_COMMON_RATIO", "0.5"))
            if isinstance(issue_count, int) and issue_count <= 0:
                return True
            if isinstance(issue_count, int) and issue_count > 0:
                try:
                    if issue_count <= 1:
                        return True
                    if len(common_points) >= issue_count:
                        return True
                    threshold = max(min_common, math.ceil(issue_count * common_ratio))
                    return len(common_points) >= threshold
                except Exception:
                    return False
            if common_points and len(common_points) >= min_common:
                return True
            return False
        except Exception:
            return False

    @staticmethod
    def _format_clauses(clauses: List[Clause]) -> str:
        if not clauses:
            return "- 위험 조항이 발견되지 않았습니다."
        top_k = int(os.getenv("DEBATE_REF_TOP_K", "2"))
        snippet_len = int(os.getenv("DEBATE_REF_SNIPPET_LEN", "160"))
        lines = []
        for clause in clauses:
            risk_level = clause.risk_level.value if clause.risk_level else "unknown"
            title = clause.title or "제목 없음"
            content = (clause.content or "").strip()
            snippet = content[:300] + ("..." if len(content) > 300 else "")
            lines.append(
                f"- {clause.article_num} {title} (risk={risk_level}): {snippet}"
            )
            refs = DebateAgents._format_references(
                clause,
                top_k=top_k,
                snippet_len=snippet_len,
            )
            if refs:
                lines.append(refs)
        return "\n".join(lines)

    @staticmethod
    def _format_references(
        clause: Clause,
        top_k: int = 2,
        snippet_len: int = 160,
    ) -> str:
        def _trim(text: str) -> str:
            text = (text or "").strip()
            return text[:snippet_len] + ("..." if len(text) > snippet_len else "")

        parts: List[str] = []
        precedents = clause.related_precedents or []
        laws = clause.related_laws or []

        if precedents:
            p_lines = []
            for p in precedents[:top_k]:
                title = p.case_name or p.case_id or "판례"
                summary = _trim(p.summary or p.key_paragraph or "")
                meta = f"{p.court} {p.date}".strip()
                if meta:
                    title = f"{title} ({meta})"
                if summary:
                    p_lines.append(f"  - {title}: {summary}")
                else:
                    p_lines.append(f"  - {title}")
            parts.append("  [판례]\n" + "\n".join(p_lines))

        if laws:
            l_lines = []
            for l in laws[:top_k]:
                title = l.title or l.doc_id or "법령"
                summary = _trim(l.summary or l.content or "")
                meta = l.date or ""
                if meta:
                    title = f"{title} ({meta})"
                if summary:
                    l_lines.append(f"  - {title}: {summary}")
                else:
                    l_lines.append(f"  - {title}")
            parts.append("  [법령]\n" + "\n".join(l_lines))

        if not parts:
            return ""
        return "  근거:\n" + "\n".join(parts)

    @staticmethod
    def _format_history(transcript: List[Dict[str, str]]) -> str:
        if not transcript:
            return "- (없음)"
        recent = transcript[-4:]
        lines = [f"{turn['speaker']}: {turn['content']}" for turn in recent]
        return "\n".join(lines)

    @staticmethod
    def _detect_contract_type(text: str) -> str:
        if not text:
            return "unknown"
        normalized = text.lower()
        if any(keyword in normalized for keyword in ["전세", "보증금"]):
            return "jeonse"
        if any(keyword in normalized for keyword in ["월세", "임대료", "차임"]):
            return "monthly_rent"
        if any(keyword in normalized for keyword in ["매매", "매도", "매수", "분양", "중도금"]):
            return "sale"
        if any(keyword in normalized for keyword in ["임차", "임대", "임차인"]):
            return "lease"
        return "real_estate_general"

    def detect_contract_type(self, raw_text: str) -> str:
        return self._detect_contract_type(raw_text)
