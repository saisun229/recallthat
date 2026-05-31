# RecallThat — CLAUDE.md

## What This Project Is

RecallThat is a local-first iOS app that turns screenshots into private, searchable memory.
Users screenshot things they want to remember. The app extracts text via on-device OCR (Apple Vision),
stores it locally, and lets users search it later. Users can delete original screenshots once the
text is safely indexed.

**Core promise:** Find what you forgot.

## Environment Note

This repo is edited in a Linux/GitHub Codespace. There is no Xcode or Swift compiler here.
All Swift source files and the Xcode project are created manually and must be opened/built on
macOS with Xcode 15+. Target: iOS 17+, SwiftUI, Swift 5.9+.

## Architecture

Layered MVVM. Clean seams between UI and business logic.

```
RecallThat/
  App/               — @main entry, app-level setup
  Models/            — plain data structs (Memory, enums)
  Views/             — SwiftUI views only, no business logic
  ViewModels/        — @Observable or ObservableObject classes
  Services/
    Photos/          — PhotoKit isolation (PhotoLibraryService)
    OCR/             — Apple Vision isolation (OCRService)
    Search/          — search logic (SearchService)
    Thumbnailing/    — thumbnail generation (ThumbnailService)
  Persistence/       — MemoryRepository protocol + SwiftData impl
  Utilities/         — shared helpers
```

## Key Constraints (non-negotiable in MVP)

- No cloud upload of screenshots or OCR text
- No backend, no accounts, no sync
- No OpenAI / Claude / Gemini API calls in MVP
- No auto-deletion — user must explicitly confirm every delete
- OCR must run on-device using Apple Vision only
- Photos access must handle denied/limited states gracefully
- UI must never block during OCR or indexing

## Build Phase Rules

Work one phase at a time. Each phase must compile before starting the next.
Never add features outside the current phase scope.
After each phase: list changed files, explain how to test, note known issues, stop for approval.
Commit to GitHub at the end of each completed phase.

## Current Phase

Phase 0 — Project Grounding (foundation only, no Photos/OCR/search yet)

## Technology Choices

- SwiftUI (not UIKit)
- SwiftData for persistence (iOS 17+)
- Apple Vision for OCR (VNRecognizeTextRequest) — Phase 4
- PhotoKit for Photos access (PHPhotoLibrary) — Phase 3
- async/await throughout
- No third-party dependencies in MVP

## Do Not Add (until explicitly requested)

- OpenAI or any cloud AI API
- Backend server or cloud sync
- User accounts or subscriptions
- Share extension
- Background tasks / background app refresh
- Embeddings or semantic search
- Analytics on screenshot content
- Auto-delete behavior

## Git Workflow

Commit at end of each completed phase with message:
  "Phase N complete: <phase name>"
Push to: https://github.com/saisun229/recallthat.git
