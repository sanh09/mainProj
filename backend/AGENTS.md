# Repository Guidelines

## Project Structure & Module Organization
This repository is a monorepo with `frontend/`, `backend/`, and `realtime/`. This guide targets `backend/`.
- Core pipeline modules live at the backend root: `pipeline.py`, `ocr.py`, `text_processor.py`, `risk_assessor.py`, `precedent_fetcher.py`, `law_fetcher.py`, `embedding_manager.py`, `risk_mapper.py`, `debate_agents.py`, and `llm_summarizer.py`.
- API entrypoints: `api.py` and `app/main.py`.
- Data support: `db/` for persistence-related code and `uploads/` for incoming files.
- Keep new tests under `backend/tests/` (create if missing).

## Build, Test, and Development Commands
Run from `backend/` unless noted.
- `pip install requests openai fastapi uvicorn python-dotenv psycopg[binary] python-multipart email-validator`: install core dependencies.
- `uvicorn api:app --reload --port 8000`: start FastAPI with hot reload.
- `python -c "from pipeline import ContractAnalysisPipeline; p=ContractAnalysisPipeline(); p.analyze(r'file.pdf')"`: run pipeline from CLI.
- Optional Conda setup: `conda env create -f environment.yml && conda activate appenv`.

## Coding Style & Naming Conventions
- Python only: 4-space indentation, `snake_case` for functions/variables, `PascalCase` for classes.
- Prefer small, single-purpose modules and explicit return types in public functions.
- Keep imports grouped and stable: standard library, third-party, local modules.
- Use descriptive filenames aligned with responsibility (for example, `*_fetcher.py`, `*_manager.py`).

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
