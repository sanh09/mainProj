# Repository Guidelines

## Project Structure & Module Organization
- Repo root contains `frontend/`, `backend/`, `realtime/`, and `docker-compose.yml`.
- Flutter app lives in `frontend/main/`.
- App source: `frontend/main/lib/`.
- Widget tests: `frontend/main/test/`.
- Platform targets: `frontend/main/android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- Backend OCR + AI pipeline and FastAPI server live in `backend/`.

## Build, Test, and Development Commands
Run frontend commands from `frontend/main/`.
- `flutter pub get`: install dependencies.
- `flutter analyze`: run analyzer with `flutter_lints`.
- `dart format .`: format Dart code (2-space indent).
- `flutter test`: run all widget tests.
- `flutter test test/widget_test.dart`: run one test file.
- `flutter test test/widget_test.dart --name "Login screen renders"`: run a single test by name (regex).
- `flutter run -d <device_id>`: run on a device/emulator.
- `flutter build apk` | `flutter build ios` | `flutter build web`: build targets.

Backend (run from `backend/`).
- `pip install requests openai fastapi uvicorn`: install deps.
- `uvicorn app.main:app --reload --port 8000`: start API server.

## Coding Style & Naming Conventions
- Dart: single quotes, trailing commas for multiline widgets/collections.
- Import order: `dart:` then `package:` then relative; keep groups separated by a blank line.
- Prefer `final`; use `late final` for `initState` values; use `const` widgets where possible.
- Naming: `PascalCase` for classes, `lowerCamelCase` for vars/methods, leading `_` for private.
- Python: 4-space indent, `snake_case` for functions/vars, `PascalCase` for classes.

## Testing Guidelines
- Frontend uses `flutter_test` with `*_test.dart` files in `frontend/main/test/`.
- Prefer user-visible assertions; use `pumpWidget(const App())` for top-level tests.
- Backend currently has no test runner configured; if added, keep tests in `backend/tests/` and document the command.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative; optional type prefixes (e.g., `chore: Update deps`).
- PRs should include a summary, tests run (or "not run"), and UI screenshots for visual changes.

## Security & Configuration Tips
- Never commit secrets or API keys.
- Backend requires `UPSTAGE_API_KEY` and `OPENAI_API_KEY`.
- Keep dependencies declared in `frontend/main/pubspec.yaml` and run `flutter pub get` after changes.
