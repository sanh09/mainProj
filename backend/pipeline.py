"""
계약서 위험조항 분석 파이프라인 - 메인 파이프라인
"""

import os
import json
import time
from typing import List, Optional
from dataclasses import asdict

from ocr import UpstageDocumentExtractor, get_extracted_text
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
        self.ocr = UpstageDocumentExtractor()
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
        self.embedding_law_max_chars = int(os.getenv("EMBEDDING_MAX_CHARS_LAW", "1200"))
        self.embedding_law_content_max_chars = int(
            os.getenv("EMBEDDING_MAX_CHARS_LAW_CONTENT", "800")
        )
        self.embedding_precedent_max_chars = int(
            os.getenv("EMBEDDING_MAX_CHARS_PRECEDENT", "1200")
        )
        self.embedding_law_limit = int(os.getenv("LAW_EMBED_LIMIT", "15"))
        self.embedding_precedent_limit = int(os.getenv("PRECEDENT_EMBED_LIMIT", "15"))
        self.embedding_clause_max_chars = int(os.getenv("EMBEDDING_MAX_CHARS_CLAUSE", "800"))
        self.generate_ui_payload = (
            os.getenv("GENERATE_UI_PAYLOAD", "true").lower() in ("1", "true", "yes", "y")
        )
        self.debate_snippet_max_chars = int(os.getenv("DEBATE_SNIPPET_MAX_CHARS", "1200"))
    
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
        skip_llm = os.getenv("SKIP_LLM", "false").lower() in ("1", "true", "yes", "y")
        if skip_llm:
            risky_clauses = clauses
            print("     SKIP_LLM 활성화: 모든 조항을 위험 조항으로 간주")
        else:
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
        forced_domain_keywords = [
            kw.strip()
            for kw in (
                os.getenv("LAW_DOMAIN_KEYWORDS_FORCE")
                or "임대차,전세,월세,보증금,주택임대차,주택임대차보호법"
            ).split(",")
            if kw.strip()
        ]
        for clause in risky_clauses:
            category = self.risk_mapper.map_risk_category(clause, all_precedents)
            keywords = forced_domain_keywords + domain_keywords + [clause.title]
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
        total_law_embed_chars = 0
        total_precedent_embed_chars = 0
        total_clause_embed_chars = 0
        self.embedding_manager.attach_embeddings(
            all_laws,
            lambda law: self._format_law_text(
                law,
                max_chars=self.embedding_law_max_chars,
                content_max_chars=self.embedding_law_content_max_chars,
            ),
            max_items=self.embedding_law_limit,
        )
        self.embedding_manager.attach_embeddings(
            all_precedents,
            lambda precedent: self._format_precedent_text(
                precedent,
                max_chars=self.embedding_precedent_max_chars,
            ),
            max_items=self.embedding_precedent_limit,
        )
        for law in all_laws[: max(self.embedding_law_limit, 0) or len(all_laws)]:
            text = self._format_law_text(
                law,
                max_chars=self.embedding_law_max_chars,
                content_max_chars=self.embedding_law_content_max_chars,
            )
            if text:
                total_law_embed_chars += len(text)
        for precedent in all_precedents[
            : max(self.embedding_precedent_limit, 0) or len(all_precedents)
        ]:
            text = self._format_precedent_text(
                precedent,
                max_chars=self.embedding_precedent_max_chars,
            )
            if text:
                total_precedent_embed_chars += len(text)
        for clause in risky_clauses:
            clause_text = self._format_clause_text(
                [clause], max_chars=self.embedding_clause_max_chars
            ) or (
                f"{clause.title or clause.article_num}\n{clause.content}"
            )
            if clause_text:
                total_clause_embed_chars += len(clause_text)
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
        approx_tokens = (
            total_law_embed_chars + total_precedent_embed_chars + total_clause_embed_chars
        ) // 4
        print(
            "     임베딩 문자수 합계: "
            f"laws {total_law_embed_chars}, "
            f"precedents {total_precedent_embed_chars}, "
            f"clauses {total_clause_embed_chars}"
        )
        print(f"     임베딩 토큰(대략): {approx_tokens} (chars/4 기준)")
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
        if skip_llm:
            debate_transcript = [{"speaker": "system", "content": "SKIP_LLM: 토론 생략"}]
            print("     SKIP_LLM 활성화: 토론 생략")
        else:
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

        # UI payload 생성 (조항별 P(L1~L4)) - 토론 스니펫 포함
        if self.generate_ui_payload:
            print("     UI payload 생성...")
            debate_snippet = self._format_debate_transcript(debate_transcript or [])
            if self.debate_snippet_max_chars > 0:
                debate_snippet = debate_snippet[: self.debate_snippet_max_chars]
            for clause in risky_clauses:
                clause_id = clause.id
                title = clause.title or clause.article_num
                clause_text = clause.content or ""
                risk_level = clause.risk_level.value if clause.risk_level else "unknown"
                risk_reason = clause.risk_reason or ""
                precedents = self._format_ref_titles(clause.related_precedents, is_precedent=True)
                laws = self._format_ref_titles(clause.related_laws, is_precedent=False)
                clause.ui_payload = self.llm_summarizer.generate_clause_ui_payload_v2(
                    clause_id=clause_id,
                    title=title,
                    clause_text=clause_text,
                    risk_level=risk_level,
                    risk_reason=risk_reason,
                    precedents=precedents,
                    laws=laws,
                    debate_snippet=debate_snippet,
                )

        # 8단계: LLM 요약 생성
        print("[8/8] LLM 조항 요약 생성...")
        step_start = time.perf_counter()
        if skip_llm:
            llm_summary = "SKIP_LLM: 요약 생략"
            print("     SKIP_LLM 활성화: 요약 생략")
        else:
            llm_summary = self.llm_summarizer.generate_comprehensive_report(
                self._format_clause_text(risky_clauses)
            )
            if debate_transcript:
                debate_text = self._format_debate_transcript(debate_transcript)
                debate_summary = self.llm_summarizer.generate_debate_summary(debate_text)
                if debate_summary and debate_summary != "api필요":
                    llm_summary = f"{llm_summary}\n\n## 토론 요약\n{debate_summary}"
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
    def _format_law_text(law, max_chars: int = 0, content_max_chars: int = 0) -> str:
        title = (law.title or "").strip()
        summary = (law.summary or "").strip()
        content = (law.content or "").strip()
        if content_max_chars > 0:
            content = ContractAnalysisPipeline._truncate_text(content, content_max_chars)

        parts = [p for p in (title, summary, content) if p]
        merged = "\n".join(parts).strip()
        return ContractAnalysisPipeline._truncate_text(merged, max_chars)

    @staticmethod
    def _format_precedent_text(precedent, max_chars: int = 0) -> str:
        title = (precedent.case_name or precedent.case_id or "").strip()
        summary = (precedent.summary or "").strip()
        key_paragraph = (precedent.key_paragraph or "").strip()

        parts = [p for p in (title, summary, key_paragraph) if p]
        merged = "\n".join(parts).strip()
        return ContractAnalysisPipeline._truncate_text(merged, max_chars)

    @staticmethod
    def _format_clause_text(clauses: List[Clause], max_chars: int = 0) -> str:
        if not clauses:
            return ""
        parts = []
        for clause in clauses:
            title = clause.title or clause.article_num
            parts.append(f"{clause.article_num} {title}\n{clause.content}")
        merged = "\n\n".join(parts).strip()
        return ContractAnalysisPipeline._truncate_text(merged, max_chars)

    @staticmethod
    def _truncate_text(text: str, max_chars: int) -> str:
        if not text or max_chars <= 0:
            return text
        return text[:max_chars]

    @staticmethod
    def _format_debate_transcript(transcript: List[dict]) -> str:
        if not transcript:
            return ""
        lines = []
        for turn in transcript:
            speaker = (turn.get("speaker") or "").strip()
            content = (turn.get("content") or "").strip()
            if not content:
                continue
            if speaker:
                lines.append(f"{speaker}: {content}")
            else:
                lines.append(content)
        return "\n".join(lines)

    @staticmethod
    def _format_ref_titles(items: List, is_precedent: bool) -> List[str]:
        if not items:
            return []
        titles: List[str] = []
        for item in items[:3]:
            if is_precedent:
                title = getattr(item, "case_name", "") or getattr(item, "case_id", "") or "판례"
                meta = " ".join(
                    [str(getattr(item, "court", "") or ""), str(getattr(item, "date", "") or "")]
                ).strip()
            else:
                title = getattr(item, "title", "") or getattr(item, "doc_id", "") or "법령"
                meta = str(getattr(item, "date", "") or "").strip()
            if meta:
                titles.append(f"{title} ({meta})")
            else:
                titles.append(title)
        return titles

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
