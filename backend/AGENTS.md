# Repository Guidelines

## Project Structure & Module Organization
This repository is a monorepo with `frontend/`, `backend/`, and `realtime/`. This guide targets `backend/`.
- Core pipeline modules live at the backend root: `pipeline.py`, `ocr.py`, `text_processor.py`, `risk_assessor.py`, `precedent_fetcher.py`, `law_fetcher.py`, `embedding_manager.py`, `risk_mapper.py`, `debate_agents.py`, and `llm_summarizer.py`.
- API entrypoint: `app/main.py`.
- Data support: `db/` for SQL/init assets and `uploads/` for incoming files.
- `tools/` contains maintenance scripts (backfills, seeding, reference cache refresh, debate generation).
- Keep new tests under `backend/tests/` (create if missing).

## Build, Test, and Development Commands
Run from `backend/` unless noted.
- `pip install requests openai pypdf fastapi uvicorn[standard] python-dotenv psycopg[binary] python-multipart email-validator pinecone`: install core dependencies.
- `uvicorn app.main:app --reload --port 8000`: start FastAPI with hot reload.
- `python -c "from pipeline import ContractAnalysisPipeline; p=ContractAnalysisPipeline(); p.analyze(r'file.pdf')"`: run pipeline from CLI.
- Optional Conda setup (used by `Dockerfile`): `conda env create -f environment.yml && conda activate appenv`.

## Coding Style & Naming Conventions
- Python only: 4-space indentation, `snake_case` for functions/variables, `PascalCase` for classes.
- Prefer small, single-purpose modules and explicit return types in public functions.
- Keep imports grouped and stable: standard library, third-party, local modules.
- Use descriptive filenames aligned with responsibility (for example, `*_fetcher.py`, `*_manager.py`).

## Configuration & Environment Variables
Commonly used environment variables (see modules for full list):
- API keys: `OPENAI_API_KEY`, `UPSTAGE_API_KEY`, `PRECEDENT_API_KEY`, `LAW_API_KEY`, `PINECONE_API_KEY`.
- Upstage OCR: `UPSTAGE_OCR_ENDPOINT`, `UPSTAGE_OCR_MODEL`, `UPSTAGE_OCR`, `DOC_EXTRACT_OUTPUT_FORMAT`, `UPSTAGE_OCR_TIMEOUT_SEC`.
- FastAPI storage: `UPLOAD_DIR`, `ANALYSIS_TTL_SECONDS`, `SUMMARY_MAX_CLAUSES`, `SUMMARY_MAX_CHARS`.
- DB (Postgres via `psycopg`): `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SCHEMA`, `DB_SSLMODE`.
- Supabase uploads (optional): `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_STORAGE_BUCKET`.
- Pinecone: `PINECONE_INDEX_NAME`, `PINECONE_NAMESPACE_*`, `PINECONE_CLOUD`, `PINECONE_REGION`, `EMBEDDING_DIM`.
- LLM/pipeline tuning: `OPENAI_*_MODEL`, `OPENAI_MAX_TOKENS`, `SLIM_INPUTS`, `MAX_*_INPUT_CHARS`, `DEBATE_*`, `RISK_*`, `LAW_*`, `PRECEDENT_*`.

## Testing Guidelines
- Backend test framework is not fully standardized yet; use `pytest` for new tests.
- Place tests in `backend/tests/` with names like `test_pipeline.py` and functions `test_<behavior>()`.
- Minimum expectation for changes: add or update tests for modified logic and run `pytest` locally.

## Commit & Pull Request Guidelines
- Prefer concise, imperative commit messages (for example, `Update risk mapping`) and optional prefixes like `feat:`, `fix:`, `chore:`.
- PRs should include: what changed, why, test commands run (or `not run`), and sample request/response for API-impacting changes.
- Attach screenshots only when UI output is affected (typically frontend work).

## Security & Configuration Tips
- Never commit secrets. Use environment variables such as `UPSTAGE_API_KEY` and `OPENAI_API_KEY`.
- Document any new external credentials in `backend/README.md` with required variable names and safe defaults.
