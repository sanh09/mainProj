import argparse
import os
import sys

from pipeline import ContractAnalysisPipeline


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate debate transcript + summary for a single file.",
    )
    parser.add_argument("file", help="Path to contract file (pdf/image).")
    parser.add_argument(
        "--clause-id",
        help="Optional clause id/article/title to target. Defaults to first risky clause.",
    )
    args = parser.parse_args()

    file_path = args.file
    if not os.path.exists(file_path):
        print(f"[error] file not found: {file_path}")
        return 1

    pipeline = ContractAnalysisPipeline()
    result = pipeline.analyze(file_path)
    if not result.risky_clauses:
        print("[error] no risky clauses detected.")
        return 2

    clause = None
    if args.clause_id:
        target = str(args.clause_id).strip()
        for item in result.risky_clauses:
            if (
                str(getattr(item, "id", "")) == target
                or str(getattr(item, "article_num", "")) == target
                or str(getattr(item, "title", "")) == target
            ):
                clause = item
                break
    if clause is None:
        clause = result.risky_clauses[0]

    transcript = pipeline.debate_agents.run(
        [clause],
        raw_text=result.raw_text,
        contract_type=result.contract_type,
    )
    transcript_text = "\n".join(
        f"{turn.get('speaker', '')}: {turn.get('content', '')}".strip()
        for turn in transcript
    )
    summary = pipeline.llm_summarizer.generate_debate_summary(transcript_text)

    print("\n=== Clause ===")
    print(f"article_num: {clause.article_num}")
    print(f"title: {clause.title}")
    print(f"id: {clause.id}")
    print("\n=== Debate Summary ===")
    print(summary)
    print("\n=== Debate Transcript ===")
    print(transcript_text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
