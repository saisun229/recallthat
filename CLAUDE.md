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
    Search/          — keyword + hybrid semantic search
    Embedding/       — OpenAI embedding service + pipeline
    LLM/             — OpenAI GPT-4o-mini RAG response
    Thumbnailing/    — thumbnail generation (ThumbnailService)
  Persistence/       — MemoryRepository protocol + SwiftData impl
  Utilities/         — KeychainHelper, VectorMath, shared helpers
```

## Key Constraints (non-negotiable)

- No cloud upload of screenshots or OCR text
- No backend, no accounts, no sync
- No auto-deletion — user must explicitly confirm every delete
- OCR must run on-device using Apple Vision only
- Photos access must handle denied/limited states gracefully
- UI must never block during OCR or indexing
- OpenAI calls only when user provides their own API key (BYOK) — stored in Keychain, never leaves device
- Graceful fallback to keyword-only search if API key is missing or OpenAI call fails

## Business Model

**Free**: keyword search, local OCR, unlimited memories, share extension
**Pro (BYOK)**: dense embeddings (semantic search), AI-powered search responses, reranker
User provides their own OpenAI API key in Settings → stored in iOS Keychain → never sent to our servers.
Estimated cost: < $0.03/month per active user.

## Current Phase

Post-MVP AI & UX expansion (completed phases 1–8 of the v2 roadmap)

## Technology Choices

- SwiftUI (not UIKit)
- SwiftData for persistence (iOS 17+)
- Apple Vision for OCR (VNRecognizeTextRequest)
- PhotoKit for Photos access (PHPhotoLibrary)
- OpenAI `text-embedding-3-small` for dense embeddings (BYOK)
- OpenAI `gpt-4o-mini` for RAG responses (BYOK)
- Accelerate/vDSP for cosine similarity (on-device)
- Reciprocal Rank Fusion for hybrid search merging
- iOS Keychain for API key storage
- async/await throughout
- No third-party dependencies

## Do Not Add (until explicitly requested)

- Backend server or cloud sync
- User accounts or StoreKit subscriptions (use BYOK instead)
- Analytics on screenshot content
- Auto-delete behavior
- Background app refresh / push notifications
- OpenAI calls without user-supplied API key

## Git Workflow

Commit at end of each completed phase with message:
  "Phase N complete: <phase name>"
Push to: https://github.com/saisun229/recallthat.git
