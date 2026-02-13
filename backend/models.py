"""
데이터 모델 정의
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional
from enum import Enum


class RiskType(str, Enum):
    """위험 유형 분류"""
    CRITICAL = "critical"   # 매우 높음
    HIGH = "high"           # 높음
    MEDIUM = "medium"       # 중간
    LOW = "low"             # 낮음


@dataclass
class Clause:
    """계약 조항"""
    id: str
    article_num: str                    # 조항 번호 (예: "제1조", "제2조")
    title: str                          # 조항 제목
    content: str                        # 조항 내용
    risk_level: Optional[RiskType] = None
    risk_reason: Optional[str] = None
    related_precedents: List = field(default_factory=list)
    related_laws: List = field(default_factory=list)


@dataclass
class Precedent:
    """판례 정보"""
    case_id: str
    court: str                          # 법원
    date: str                           # 판결일
    case_name: str                      # 사건명
    summary: str                        # 요약
    key_paragraph: str                  # 문제 문단
    similarity_score: Optional[float] = None


@dataclass
class Law:
    """법령/행정규칙/자치법규 정보"""
    doc_id: str
    doc_type: str                       # law | admrul | ordin
    title: str
    summary: str = ""
    content: str = ""
    date: str = ""
    org: str = ""
    url: str = ""
    similarity_score: Optional[float] = None


@dataclass
class ContractAnalysisResult:
    """계약서 분석 결과"""
    filename: str
    raw_text: str                       # OCR 추출 텍스트
    clauses: List[Clause]
    risky_clauses: List[Clause]
    precedents: List[Precedent]
    laws: List[Law]
    raw_html: Optional[str] = None      # Document Parse HTML (table-preserving)
    llm_summary: Optional[str] = None
    debate_transcript: Optional[List[dict]] = None
    contract_type: Optional[str] = None
    source_document: Optional[Dict] = None
