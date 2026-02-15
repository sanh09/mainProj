"""
계약서 위험조항 분석 파이프라인 - 메인 파이프라인
"""

import os
import json
import time
from typing import List, Optional
from dataclasses import asdict

from ocr import GPTDocumentExtractor, get_extracted_text
from models import ContractAnalysisResult, Clause, Law, Precedent
from text_processor import TextProcessor
from risk_assessor import RiskAssessor
from precedent_fetcher import PrecedentFetcher
from law_fetcher import LawFetcher
from embedding_manager import EmbeddingManager
from chunk_store import (
    search_precedent_chunks_by_vector,
    search_law_chunks_by_vector,
)
from risk_mapper import RiskMapper
from llm_summarizer import LLMSummarizer
from debate_agents import DebateAgents


# ==================== 메인 파이프라인 ====================

class ContractAnalysisPipeline:
    """계약서 분석 전체 파이프라인"""
    
    def __init__(self):
        self.ocr = GPTDocumentExtractor()
        self.text_processor = TextProcessor()
        self.risk_assessor = RiskAssessor()
        self.precedent_fetcher = PrecedentFetcher()
        self.law_fetcher = LawFetcher()
        self.embedding_manager = EmbeddingManager()
        self.risk_mapper = RiskMapper()
        self.llm_summarizer = LLMSummarizer()
        self.debate_agents = DebateAgents()
        self.use_chunk_vector_search = (
            os.getenv("USE_CHUNK_VECTOR_SEARCH", "true").lower() in ("1", "true", "yes", "y")
        )
    
    def analyze(self, file_path: str) -> ContractAnalysisResult:
        """
        계약서 분석 전체 파이프라인 실행
        
        Flow:
        1. GPT 문서 추출 (Markdown/JSON)
        2. 텍스트 정제 / 조항 분리
        3. LLM 기반 위험 조항 후보 필터
        4. 공공 판례 API 호출
        5. 임베딩 생성 & 유사도 검색
        6. 위험 유형 매핑
        7. 갑/을 토론
        8. LLM 조항 요약
        
        Args:
            file_path: 계약서 파일 경로 (PDF 또는 이미지)
            
        Returns:
            분석 결과
        """
        filename = os.path.basename(file_path)
        
        # 1단계: 문서 추출
        print(f"[1/8] 문서 추출 진행 중.. ({filename})")
        step_start = time.perf_counter()
        ocr_result = self.ocr.extract_text_from_file(file_path)
        raw_text = get_extracted_text(ocr_result)
        source_document = ocr_result if isinstance(ocr_result, dict) else None
        print(f"     문서 추출 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 2단계: 텍스트 정제 및 조항 분리
        print("[2/8] 텍스트 정제 및 조항 분리...")
        step_start = time.perf_counter()
        clean_text = self.text_processor.clean_text(raw_text)
        clauses = self.text_processor.split_clauses_with_fallback(clean_text)
        print(f"     총 {len(clauses)}개 조항 추출")
        print(f"     텍스트 정제/분리 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 3단계: 위험 조항 필터링
        print("[3/8] 위험 조항 필터링...")
        step_start = time.perf_counter()
        risky_clauses = self.risk_assessor.filter_risky_clauses(clauses)
        print(f"     위험 조항 {len(risky_clauses)}개 발견")
        print(f"     위험 조항 필터링 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 4단계: 판례 데이터 수집
        print("[4/8] 공공 판례 API 호출...")
        step_start = time.perf_counter()
        all_precedents = []
        all_laws = []
        min_precedent_results = int(os.getenv("PRECEDENT_MIN_RESULTS") or "3")
        min_law_results = int(os.getenv("LAW_MIN_RESULTS") or "3")
        domain_keywords = [
            kw.strip()
            for kw in (
                os.getenv("LAW_DOMAIN_KEYWORDS")
                or "부동산,임대차,임대,임차,주택,전세,월세,보증금"
            ).split(",")
            if kw.strip()
        ]
        for clause in risky_clauses:
            category = self.risk_mapper.map_risk_category(clause, all_precedents)
            keywords = domain_keywords + [clause.title]
            if category and category != "기타":
                keywords.extend(self.risk_mapper.get_keywords_for_category(category))
            query = " ".join([kw for kw in keywords if kw])
            precedents = self.precedent_fetcher.fetch_precedents(query)
            if isinstance(precedents, str):
                precedents = []
            if len(precedents) < min_precedent_results and clause.title:
                fallback = self.precedent_fetcher.fetch_precedents(clause.title)
                if isinstance(fallback, str):
                    fallback = []
                # merge by case_id to avoid duplicates
                seen = {p.case_id for p in precedents}
                for p in fallback:
                    if p.case_id and p.case_id not in seen:
                        precedents.append(p)
                        seen.add(p.case_id)
            all_precedents.extend(precedents)
            laws = self.law_fetcher.fetch_laws(query)
            if isinstance(laws, str):
                laws = []
            if len(laws) < min_law_results and clause.title:
                fallback = self.law_fetcher.fetch_laws(clause.title)
                if isinstance(fallback, str):
                    fallback = []
                seen = {(l.doc_type, l.doc_id) for l in laws}
                for law in fallback:
                    key = (law.doc_type, law.doc_id)
                    if law.doc_id and key not in seen:
                        laws.append(law)
                        seen.add(key)
            all_laws.extend(laws)
        all_laws = self.law_fetcher._dedupe_laws(all_laws)
        print(f"     precedents {len(all_precedents)}, laws {len(all_laws)} collected")
        print(f"     판례/법령 수집 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 5단계: 임베딩 생성 및 유사도 검색
        print("[5/8] 임베딩 생성 및 유사도 검색..")
        step_start = time.perf_counter()
        self.embedding_manager.attach_embeddings(all_laws, self._format_law_text)
        for clause in risky_clauses:
            clause_text = self._format_clause_text([clause]) or (
                f"{clause.title or clause.article_num}\n{clause.content}"
            )
            similar_precedents = self.embedding_manager.find_similar_precedents(
                clause_text, all_precedents
            )
            similar_precedents = self._merge_chunk_precedents(
                clause_text, similar_precedents
            )
            clause.related_precedents = similar_precedents
            similar_laws = self.embedding_manager.find_similar_laws(
                clause_text, all_laws
            )
            similar_laws = self._merge_chunk_laws(clause_text, similar_laws)
            clause.related_laws = similar_laws
        print("     유사도 검색 완료")
        print(f"     임베딩/유사도 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 6단계: 위험 유형 매핑 (카테고리 계산은 4단계 쿼리 생성에 이미 활용)
        print("[6/8] 위험 유형 매핑...")
        step_start = time.perf_counter()
        print("     위험 유형 분류 완료")
        print(f"     위험 유형 매핑 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 7단계: 갑/을 토론 생성
        print("[7/8] 갑/을 토론 생성...")
        step_start = time.perf_counter()
        contract_type = self.debate_agents.detect_contract_type(raw_text)
        debate_transcript = self.debate_agents.run(
            risky_clauses,
            raw_text=raw_text,
            contract_type=contract_type,
        )
        # Align legacy labels with the new judge role name.
        for turn in debate_transcript:
            if turn.get("speaker") in ("mediator", "중재자"):
                turn["speaker"] = "판사"
        print(f"     토론 생성 완료 ({time.perf_counter() - step_start:.2f}s)")

        # 8단계: LLM 요약 생성
        print("[8/8] LLM 조항 요약 생성...")
        step_start = time.perf_counter()
        llm_summary = self.llm_summarizer.generate_comprehensive_report(
            self._format_clause_text(risky_clauses)
        )
        print(f"     요약 생성 완료 ({time.perf_counter() - step_start:.2f}s)")
        
        # 결과 반환
        result = ContractAnalysisResult(
            filename=filename,
            raw_text=raw_text,
            clauses=clauses,
            risky_clauses=risky_clauses,
            precedents=all_precedents,
            laws=all_laws,
            llm_summary=llm_summary,
            debate_transcript=debate_transcript,
            contract_type=contract_type,
            source_document=source_document,
        )
        
        print("\n분석 완료!")
        return result

    def analyze_only(self, file_path: str) -> ContractAnalysisResult:
        """Pipeline-only analysis helper (no negotiation)."""
        return self.analyze(file_path)

    def export_result(self, result: ContractAnalysisResult, output_path: str):
        """분석 결과를 JSON으로 내보내기"""
        output_data = {
            "filename": result.filename,
            "total_clauses": len(result.clauses),
            "risky_clauses_count": len(result.risky_clauses),
            "clauses": [asdict(c) for c in result.clauses],
            "risky_clauses": [asdict(c) for c in result.risky_clauses],
            "precedents": [asdict(p) for p in result.precedents],
            "laws": [asdict(l) for l in result.laws],
            "summary": result.llm_summary,
            "debate_transcript": result.debate_transcript,
            "contract_type": result.contract_type
        }
        
        # dataclass 직렬화 문제 해결
        def serialize(obj):
            if hasattr(obj, 'value'):  # Enum
                return obj.value
            return str(obj)
        
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2, default=serialize)
        
        print(f"결과 저장: {output_path}")

    @staticmethod
    def _format_law_text(law) -> str:
        parts = [law.title, law.summary, law.content]
        return "\n".join([str(p).strip() for p in parts if p and str(p).strip()])

    @staticmethod
    def _format_clause_text(clauses: List[Clause]) -> str:
        if not clauses:
            return ""
        parts = []
        for clause in clauses:
            title = clause.title or clause.article_num
            parts.append(f"{clause.article_num} {title}\n{clause.content}")
        return "\n\n".join(parts)

    def _merge_chunk_precedents(
        self, text: str, base: List[Precedent] | str
    ) -> List[Precedent] | str:
        if not self.use_chunk_vector_search or isinstance(base, str):
            return base
        embedding = self.embedding_manager.generate_embedding(text)
        if embedding == "api필요":
            return base
        matches = search_precedent_chunks_by_vector(embedding, limit=3)
        if isinstance(matches, str):
            return base
        seen = {p.case_id for p in base if p.case_id}
        for chunk in matches:
            if chunk.case_id and chunk.case_id in seen:
                continue
            seen.add(chunk.case_id)
            base.append(chunk)
        return base

    def _merge_chunk_laws(self, text: str, base: List[Law] | str) -> List[Law] | str:
        if not self.use_chunk_vector_search or isinstance(base, str):
            return base
        embedding = self.embedding_manager.generate_embedding(text)
        if embedding == "api필요":
            return base
        matches = search_law_chunks_by_vector(embedding, limit=3)
        if isinstance(matches, str):
            return base
        seen = {f"{law.doc_type}:{law.doc_id}" for law in base if law.doc_id}
        for chunk in matches:
            key = f"{chunk.doc_type}:{chunk.doc_id}"
            if chunk.doc_id and key in seen:
                continue
            seen.add(key)
            base.append(chunk)
        return base


# ==================== 사용 예시 ====================

if __name__ == "__main__":
    # 파이프라인 초기화
    pipeline = ContractAnalysisPipeline()
    
    # 분석 실행
    contract_file = "contract.pdf"  # 또는 .jpg, .png 등
    
    try:
        result = pipeline.analyze(contract_file)
        
        # 결과 출력
        print(f"\n{'='*50}")
        print(f"총 조항 수 {len(result.clauses)}")
        print(f"위험 조항 수 {len(result.risky_clauses)}")
        print(f"{'='*50}\n")
        print(result.llm_summary)
        
        # 결과 저장
        pipeline.export_result(result, "analysis_result.json")
        
    except FileNotFoundError:
        print(f"파일을 찾을 수 없습니다: {contract_file}")
    except Exception as e:
        print(f"오류 발생: {e}")
