# Handoff: ChargeMotion macOS frontend

Scope: native SwiftUI frontend in macOS/ChargeMotionApp.
Backend ChargeMotionCore is read-only. Do not touch Windows/.
Do not push to GitHub. No account/login UI is required.

Read first:
- PROGRESS.md
- TASK-6-COMPLETION.md
- BACKEND-API-REVIEW.md
- BACKEND-GAPS-TASKS-4-5.md
- COMPOSITION-ROOT.md
- FRONTEND-README.md

## Architecture
- AppEnvironment owns the backend services.
- StartupGateView displays AppShellView after successful startup.
- AppShellView owns the single ShellContext.
- Settings changes go through SettingsController.
- MediaCatalogController manages frontend media operations.
- Preview playback uses its own controller.

## Next
- Task 6 source is complete; Mac build and runtime validation remain.
- Task 7: Claude creates the original 3D mechanical koi and creator medallion.
- Task 8: app icon, accessibility, final polish, testing checklist and final ZIP.
- Do not modify the backend or Windows app.
- Never claim a successful Mac build until it has actually run on a Mac.
