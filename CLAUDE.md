# RecallThat — CLAUDE.md

## What This Project Is

RecallThat is a photo-memory iOS app that turns screenshots into private, searchable memory.
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
  Utilities/         — KeychainHelper, VectorMath, APIConfig, shared helpers
```

## Privacy Model

Photos never leave the device. Extracted OCR text may be sent to OpenAI's servers to power
semantic search (text-embedding-3-small) and AI-powered answers (gpt-4o-mini). The developer
supplies the OpenAI API key at build time via Xcode Cloud environment variable — users do not
provide a key and are not billed directly.

Key facts for App Store review:
- Screenshots and thumbnails: always on-device only
- OCR text: sent to OpenAI when AI features are available (embedding + chat)
- No backend server owned by the developer
- No user accounts, no sync, no analytics on content

## Key Constraints (non-negotiable)

- Screenshots and photos are never uploaded to any server
- OCR text is sent to OpenAI only (for embedding/RAG) — no other third parties
- No auto-deletion — user must explicitly confirm every delete
- OCR must run on-device using Apple Vision only
- Photos access must handle denied/limited states gracefully
- UI must never block during OCR or indexing
- Graceful fallback to keyword-only search if OpenAI call fails
- Pre-permission UI buttons must use neutral labels ("Continue", "Next") per App Store guidelines

## Business Model

**Hosted AI (developer-controlled key):** Developer pays OpenAI for all users.
- OpenAI `text-embedding-3-small` for semantic indexing
- OpenAI `gpt-4o-mini` for AI answers
- API key is NOT in source code — stored as Xcode Cloud secret env var (`OPENAI_API_KEY`)
- `APIConfig.openAIKey` reads from `Info.plist["OpenAIAPIKey"]` injected at build time
- Estimated cost: ~$0.015/month per active user

## Current Phase

Post-MVP AI & UX expansion (completed phases 1–10 of the v2 roadmap + App Store resubmission fixes)

## Technology Choices

- SwiftUI (not UIKit)
- SwiftData for persistence (iOS 17+)
- Apple Vision for OCR (VNRecognizeTextRequest)
- PhotoKit for Photos access (PHPhotoLibrary)
- OpenAI `text-embedding-3-small` for dense embeddings (developer-hosted key)
- OpenAI `gpt-4o-mini` for RAG responses (developer-hosted key)
- Accelerate/vDSP for cosine similarity (on-device)
- Reciprocal Rank Fusion for hybrid search merging
- iOS Keychain for internal storage (not used for API key)
- async/await throughout
- No third-party dependencies

## Do Not Add (until explicitly requested)

- Backend server owned by the developer
- User accounts or StoreKit subscriptions
- Analytics on screenshot content
- Auto-delete behavior
- Background app refresh / push notifications
- Additional third-party AI providers beyond OpenAI

## Git Workflow

Commit at end of each completed phase with message:
  "Phase N complete: <phase name>"
Push to: https://github.com/saisun229/recallthat.git
