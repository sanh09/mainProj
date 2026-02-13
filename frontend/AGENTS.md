# Repository Guidelines

## Project Structure & Module Organization
This repository is a monorepo with three services and shared orchestration.
- `frontend/`: Flutter app. Main code lives in `frontend/main/lib/`; widget tests live in `frontend/main/test/`.
- `backend/`: Python OCR + AI analysis pipeline and FastAPI server.
- `realtime/`: Placeholder for real-time/WebSocket processing (currently `.gitkeep`).
- `docker-compose.yml`: top-level multi-service orchestration.

## Build, Test, and Development Commands
Frontend (run from `frontend/main/`):
- `flutter pub get`: install Flutter dependencies.
- `flutter run`: launch the app on a connected device/emulator.
- `flutter test`: run widget/unit tests.
- `flutter build apk` / `flutter build ios` / `flutter build web`: build deployable artifacts.

Backend (run from `backend/`):
- `pip install requests openai fastapi uvicorn`: install core dependencies.
- `uvicorn api:app --reload --port 8000`: start local API server.
- `python -c "from pipeline import ContractAnalysisPipeline; p=ContractAnalysisPipeline(); p.analyze(r'file.pdf')"`: run the analysis pipeline from CLI.

## Coding Style & Naming Conventions
- Python: 4-space indentation, `snake_case` for functions/variables, `PascalCase` for classes.
- Dart/Flutter: format with `dart format` (2-space indentation), prefer `const` widgets when possible.
- Dart naming: `lowerCamelCase` for members, `PascalCase` for types.
- Dart imports: `dart:` first, then `package:`, then relative imports.

## Testing Guidelines
- Frontend uses `flutter_test`; keep tests under `frontend/main/test/`.
- Name tests by feature/behavior and run with `flutter test` before opening PRs.
- Backend has no standard test framework yet; if adding tests, place them near modules or in `backend/tests/` and document run commands.

## Commit & Pull Request Guidelines
- Use concise, imperative commit messages (e.g., `Update frontend`, `chore: adjust API client`).
- PRs should include a short summary, commands run (or `not run`), and screenshots for UI changes.

## Security & Configuration Tips
- Never commit secrets.
- Backend requires `UPSTAGE_API_KEY` and `OPENAI_API_KEY` environment variables (`backend/README.md`).
- Document any new required env vars in the relevant service README.

## Architecture Overview
Backend flow: OCR -> text cleanup/splitting -> risky clause filtering -> precedent/law lookup -> embedding similarity -> risk mapping -> debate generation -> LLM summary.

## Agent-Specific Instructions
For frontend UI work, follow `frontend/main/AGENTS.md` conventions.
