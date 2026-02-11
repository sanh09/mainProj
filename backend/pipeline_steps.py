"""
Pipeline step implementations for contract analysis.
"""

import os
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List

from models import Clause
from ocr import get_extracted_text


class PipelineSteps:
    def __init__(
        self,
        ocr,
        text_processor,
        risk_assessor,
        precedent_fetcher,
        law_fetcher,
        embedding_manager,
        risk_mapper,
        llm_summarizer,
        debate_agents,
    ) -> None:
        self.ocr = ocr
        self.text_processor = text_processor
        self.risk_assessor = risk_assessor
        self.precedent_fetcher = precedent_fetcher
        self.law_fetcher = law_fetcher
        self.embedding_manager = embedding_manager
        self.risk_mapper = risk_mapper
        self.llm_summarizer = llm_summarizer
        self.debate_agents = debate_agents

    def run_ocr(self, file_path: str) -> str:
        ocr_result = self.ocr.extract_text_from_file(file_path)
        return get_extracted_text(ocr_result)

    def prepare_clauses(self, raw_text: str) -> List[Clause]:
        clean_text = self.text_processor.clean_text(raw_text)
        return self.text_processor.split_clauses_with_fallback(clean_text)

    def filter_risky_clauses(self, clauses: List[Clause]) -> List[Clause]:
        return self.risk_assessor.filter_risky_clauses(clauses)

    def collect_references(self, risky_clauses: List[Clause]):
        all_precedents: list = []
        all_laws: list = []
        if not risky_clauses:
            return all_precedents, all_laws

        min_precedent_results = int(os.getenv("PRECEDENT_MIN_RESULTS") or "3")
        min_law_results = int(os.getenv("LAW_MIN_RESULTS") or "3")
        domain_keywords = self._get_domain_keywords()
        workers = int(os.getenv("REFERENCE_FETCH_WORKERS", "4"))

        def _fetch_for_clause(clause: Clause):
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
                seen = {p.case_id for p in precedents}
                for p in fallback:
                    if p.case_id and p.case_id not in seen:
                        precedents.append(p)
                        seen.add(p.case_id)

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
            return precedents, laws

        if workers <= 1:
            for clause in risky_clauses:
                precedents, laws = _fetch_for_clause(clause)
                all_precedents.extend(precedents)
                all_laws.extend(laws)
        else:
            with ThreadPoolExecutor(max_workers=workers) as executor:
                futures = [executor.submit(_fetch_for_clause, clause) for clause in risky_clauses]
                for future in as_completed(futures):
                    precedents, laws = future.result()
                    all_precedents.extend(precedents)
                    all_laws.extend(laws)

        all_laws = self.law_fetcher._dedupe_laws(all_laws)
        return all_precedents, all_laws

    def attach_similarities(
        self,
        risky_clauses: List[Clause],
        all_precedents: list,
        all_laws: list,
    ) -> None:
        use_db_vector = self.embedding_manager.use_db_vector_search
        if not use_db_vector:
            self.embedding_manager.attach_embeddings(all_laws, self._format_law_text)
        for clause in risky_clauses:
            clause_text = self._format_clause_text([clause]) or (
                f"{clause.title or clause.article_num}\n{clause.content}"
            )
            if use_db_vector:
                similar_precedents = self.embedding_manager.find_similar_precedents_db(
                    clause_text
                )
            else:
                similar_precedents = self.embedding_manager.find_similar_precedents(
                    clause_text, all_precedents
                )
            clause.related_precedents = similar_precedents
            if use_db_vector:
                similar_laws = self.embedding_manager.find_similar_laws_db(clause_text)
            else:
                similar_laws = self.embedding_manager.find_similar_laws(
                    clause_text, all_laws
                )
            clause.related_laws = similar_laws

    def map_risk_types(self, risky_clauses: List[Clause], all_precedents: list) -> None:
        for clause in risky_clauses:
            category = self.risk_mapper.map_risk_category(clause, all_precedents)
            keywords = self.risk_mapper.get_keywords_for_category(category)
            clause.highlight_keywords = [kw for kw in keywords if kw]
            clause.highlight_sentences = self.risk_mapper.find_highlight_sentences(
                clause.content, clause.highlight_keywords
            )

    def generate_debate(self, risky_clauses: List[Clause], raw_text: str):
        contract_type = self.debate_agents.detect_contract_type(raw_text)
        debate_transcript = self.debate_agents.run(
            risky_clauses,
            raw_text=raw_text,
            contract_type=contract_type,
        )
        for turn in debate_transcript:
            if turn.get("speaker") in ("mediator", "중재자"):
                turn["speaker"] = "판사"

        debate_by_clause = None
        if os.getenv("DEBATE_BY_CLAUSE", "").lower() in ("1", "true", "yes", "y"):
            debate_by_clause = self.debate_agents.run_by_clause(
                risky_clauses,
                raw_text=raw_text,
                contract_type=contract_type,
            )
        return contract_type, debate_transcript, debate_by_clause

    def generate_summary(self, risky_clauses: List[Clause]) -> str:
        return self.llm_summarizer.generate_comprehensive_report(
            self._format_clause_text(risky_clauses)
        )

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

    @staticmethod
    def _get_domain_keywords() -> List[str]:
        return [
            kw.strip()
            for kw in (
                os.getenv("LAW_DOMAIN_KEYWORDS")
                or "부동산,임대차,임대,임차,주택,전세,월세,보증금"
            ).split(",")
            if kw.strip()
        ]
