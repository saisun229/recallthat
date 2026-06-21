# RecallThat

**Find what you forgot.**

RecallThat turns your screenshots into a private, searchable memory. Import a screenshot, get the text extracted on-device via Apple Vision OCR, and search it any time — or ask a question and get an AI-generated answer. No account. No developer-owned backend.

---

## Features

- **On-device OCR** — Apple Vision reads text from your screenshots. Screenshots and thumbnails never leave your phone.
- **Instant search** — keyword search across all indexed memories in real time, works fully offline.
- **Semantic search + AI answers** — extracted text is sent to OpenAI (`text-embedding-3-small`, `gpt-4o-mini`) to power meaning-based search and AI-generated answers with citations. Falls back to offline keyword search if unavailable.
- **Share Extension** — save images, links, PDFs, and text from any app via the iOS share sheet.
- **Delete originals** — once indexed, delete the screenshot from Photos to free up space. The text and thumbnail stay in RecallThat.
- **No account, no developer-owned server, no analytics** on your content.

---

## Requirements

| | |
|---|---|
| Platform | iOS 17+ |
| Build environment | macOS with Xcode 15+ |
| Dependencies | None (no third-party packages) |

> This repo is developed in a Linux/GitHub Codespace. All Swift source is edited there and built on macOS with Xcode.

---

## Architecture

Layered MVVM with clean seams between UI and business logic.

```
RecallThat/
  App/               — @main entry, app-level setup
  Models/            — plain data structs (Memory, enums)
  Views/             — SwiftUI views, no business logic
  ViewModels/        — @Observable classes
  Services/
    Photos/          — PhotoKit isolation (PhotoLibraryService)
    OCR/             — Apple Vision isolation (OCRService)
    Search/          — search logic (SearchService)
    Thumbnailing/    — thumbnail generation (ThumbnailService)
  Persistence/       — MemoryRepository protocol + SwiftData impl
  Utilities/         — shared helpers

RecallThatShareExtension/
  — iOS Share Extension target
```

**Technology choices:** SwiftUI · SwiftData · Apple Vision (VNRecognizeTextRequest) · PhotoKit · async/await

---

## Building

1. Clone the repo and open `RecallThat.xcodeproj` in Xcode 15+.
2. Select the **RecallThat** scheme and an iOS 17+ simulator or device.
3. Press **Cmd+R** to build and run.

No package resolution needed — there are no third-party dependencies.

---

## Privacy

- All OCR runs on-device using Apple's Vision framework. Screenshots and thumbnails are never uploaded.
- Extracted text may be sent to OpenAI to power optional semantic search and AI-generated answers, using a developer-supplied API key.
- No account required. No internet connection required for core import/OCR/keyword-search.
- Users can delete all stored memories at any time from Settings.

[Privacy Policy](https://saisun229.github.io/recallthat/privacy-policy.html)

---

## Links

- **App Store:** *(pending)*
- **Support / Issues:** https://github.com/saisun229/recallthat/issues
- **Privacy Policy:** https://saisun229.github.io/recallthat/privacy-policy.html
