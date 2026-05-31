# RecallThat — Task.md

## Role

You are Claude Code acting as a senior professional iOS engineer.

Build RecallThat phase by phase with excellent engineering judgment.
Do not rush. Do not jump ahead. Do not overbuild. Do not add speculative features.
Build a simple, high-quality, local-first iOS app that can evolve later without a rewrite.

---

## Product

RecallThat is an iOS app for **temporary human memory**.

People already save temporary information through screenshots because screenshots are faster than
note-taking. RecallThat turns screenshots into private, searchable memory so users can find things
later and reduce photo clutter when they are ready.

**Core Promise:** Find what you forgot.

**MVP Promise:** Screenshot anything. Find it later. Delete the original when ready.

### Primary User Loop

1. User grants Photos access.
2. RecallThat finds screenshots.
3. RecallThat extracts text locally using Apple Vision OCR.
4. User searches exact or vague remembered text.
5. User finds the screenshot quickly.
6. User may delete the original screenshot only after clear confirmation.

---

## Build Philosophy

- **Local-first:** OCR, indexing, search, persistence — all on device. No uploads in MVP.
- **Cheap by design:** Near-zero backend cost. No server in MVP.
- **Privacy-first:** No cloud upload, no logging of OCR text, explain before requesting Photos access.
- **UX first:** Search must feel magical. First moment: user finds something they thought they lost.

---

## Architecture

```
RecallThat/
  App/
  Models/
  Views/
  ViewModels/
  Services/
    Photos/
    OCR/
    Search/
    Thumbnailing/
  Persistence/
  Utilities/
```

**Layering rules:**
- Views: display UI, bind to VM state, send actions — no OCR/PhotoKit/persistence logic
- ViewModels: own screen state, coordinate services, expose loading/error/empty states
- Services: focused business/platform logic — PhotoLibraryService, OCRService, SearchService, ThumbnailService
- Persistence: MemoryRepository protocol, SwiftData implementation behind it
- Models: stable structs, support future memory types beyond screenshots

---

## Data Model

```swift
struct Memory: Identifiable, Equatable {
    let id: UUID
    let sourceType: MemorySourceType
    let photoAssetIdentifier: String?   // PHAsset localIdentifier
    var localThumbnailPath: String?
    let createdAt: Date                  // when original screenshot was captured
    let importedAt: Date                 // when RecallThat indexed it
    var title: String
    var ocrText: String
    var ocrStatus: OCRStatus
    var searchText: String               // denormalized: title + ocrText, lowercased
    var originalExists: Bool
    var deletedOriginalAt: Date?
}

enum MemorySourceType: String, Codable {
    case screenshot              // MVP
    case sharedText              // Phase 10+
    case sharedURL               // Phase 10+
    case sharedImage             // Phase 10+
}

enum OCRStatus: String, Codable {
    case notStarted
    case pending
    case complete
    case failed
}
```

---

## Phases

### Phase 0 — Project Grounding ← CURRENT

**Goal:** Clean foundation. No real functionality yet.

**Tasks:**
- Create Xcode project: iOS 17+, SwiftUI, Swift 5.9+
- Create folder structure per architecture above
- Define Memory model, MemorySourceType, OCRStatus
- Define MemoryRepository protocol (empty impl for now)
- Define service protocol stubs: PhotoLibraryService, OCRService, SearchService, ThumbnailService
- App must build and launch (blank screen is fine)

**Acceptance:**
- App builds in Xcode without errors
- Project structure matches architecture
- Models compile
- No Photos/OCR/search/delete implemented yet
- No speculative systems added

---

### Phase 1 — App Skeleton

**Goal:** Basic SwiftUI navigation shell.

**Tasks:**
- HomeView with empty feed and placeholder states
- SearchView with placeholder search bar and empty state
- SettingsView placeholder
- MemoryDetailView placeholder (accepts a Memory)
- Tab bar or NavigationSplitView navigation
- Clean empty state copy for each screen

**Acceptance:**
- App launches, all screens navigate correctly
- Clean view/VM separation where useful
- No Photos/OCR/search implementation

---

### Phase 2 — Local Persistence

**Goal:** Store Memory records locally using SwiftData.

**Tasks:**
- Implement MemoryRepository with SwiftData (SwiftDataMemoryRepository)
- Seed mock Memory items at launch (dev convenience only, clearly marked)
- Display mock memory cards in HomeView
- MemoryDetailView opens a real Memory item
- Persistence survives app restart

**Acceptance:**
- Mock memories persist across launches
- Feed reads from SwiftData via repository
- Views never directly touch SwiftData ModelContext
- Detail screen opens a memory item

---

### Phase 3 — Photos Permission + Screenshot Discovery

**Goal:** Find real screenshots from the Photos library.

**Tasks:**
- NSPhotoLibraryUsageDescription in Info.plist
- PhotoLibraryService: request access, fetch screenshots only
- Handle .authorized, .limited, .denied, .notDetermined cleanly
- Filter: only PHAsset items with mediaSubtype containing .photoScreenshot
- Store photoAssetIdentifier for each found screenshot
- Display screenshot thumbnails in feed
- Deduplication: skip already-imported asset identifiers

**Acceptance:**
- Only screenshots appear (not regular photos)
- Denied/limited states handled gracefully with recovery UI
- Asset identifiers stored locally
- No uploads, no deletion

---

### Phase 4 — OCR Pipeline

**Goal:** Extract text from screenshots on-device.

**Tasks:**
- OCRService using VNRecognizeTextRequest (Apple Vision)
- Process screenshots asynchronously — never block the main thread
- Update Memory.ocrStatus: notStarted → pending → complete/failed
- Store ocrText in persistence
- Show ocrText in MemoryDetailView
- Manual retry option for failed OCR

**Acceptance:**
- OCR runs on-device only (no network calls)
- Status transitions correctly
- OCR text visible in detail view
- App stays responsive during OCR
- App never crashes on OCR failure
- OCR text persists after app restart

---

### Phase 5 — Search MVP

**Goal:** Find screenshots by OCR text.

**Tasks:**
- SearchService: keyword search over searchText field (title + ocrText, lowercased)
- Case-insensitive, partial/contains matching
- SearchView shows real results
- Tap result → MemoryDetailView
- No-results empty state

**Acceptance:**
- Keyword search returns correct results fast
- Search works after restart
- No embeddings, no cloud search

---

### Phase 6 — Memory Card UX

**Goal:** Screenshots feel like memory objects, not a photo gallery.

**Tasks:**
- Memory card: thumbnail + title + OCR preview + date + status badge
- Title generation logic: first meaningful OCR line → app/source/date → "Screenshot from [date]"
- originalExists / deleted status indicator on card and detail
- Improved empty, loading, and error states throughout

**Acceptance:**
- Cards are readable without opening each item
- No manual tagging required
- Cards feel like memory objects, not photo tiles

---

### Phase 7 — Delete Original Screenshot

**Goal:** Let users remove photo clutter without losing searchable text.

**Tasks:**
- "Delete Original Screenshot" action — only visible when originalExists = true
- Confirmation sheet explaining exactly what remains (OCR text, title, date, thumbnail)
- Delete via PHAssetChangeRequest.deleteAssets
- Update originalExists = false, set deletedOriginalAt
- Memory remains fully searchable after deletion
- Graceful error handling for PhotoKit authorization errors

**Wording rules:**
- Always use: "Delete Original Screenshot"
- Never use: "Safe Delete"
- Never auto-delete

**Acceptance:**
- Explicit user confirmation always required
- Memory fully searchable after original deleted
- Deleted state visible in card and detail
- Graceful error handling

---

### Phase 8 — Onboarding + Privacy

**Goal:** Build trust before requesting Photos access.

**Tasks:**
- Onboarding flow (3–4 screens): what RecallThat does, local OCR, no uploads, delete behavior
- Show onboarding before Photos permission system prompt
- Privacy section in Settings: what is stored, how to delete all data
- Permission denied recovery instructions

**Acceptance:**
- Onboarding appears on first launch only
- User understands why Photos access is needed
- Privacy copy is honest and matches real app behavior
- User can recover from denied permission

---

### Phase 9 — TestFlight Polish

**Goal:** First beta-quality build.

**Tasks:**
- Fix crashes found on real device testing
- Deduplication of imports (don't re-index already-indexed screenshots)
- Basic indexing/OCR progress indicator
- Improved loading, empty, and error states throughout
- App icon (placeholder acceptable)
- TestFlight description copy
- Privacy audit: no hidden uploads, no API keys, no cloud behavior anywhere

**Acceptance:**
- Full flow on real device: permission → import → OCR → search → detail → delete original → search again
- App stable enough for external testers
- No cloud behavior whatsoever

---

## Post-MVP Phases (do not build until requested)

- **Phase 10 — Share Extension:** Save text, URLs, images from other apps via share sheet
- **Phase 11 — Better Ranking:** Typo tolerance, recency boost, "why this matched" snippets
- **Phase 12 — Optional Premium AI:** Opt-in cloud summarization, semantic search, embeddings

---

## Do Not Build in MVP

User accounts, cloud sync, paid subscriptions, AI chat, automatic deletion, web dashboard,
social sharing, browser extension, OpenAI/Claude/Gemini APIs, backend server,
analytics on screenshot content, embeddings, manual tagging systems.

---

## Response Format After Each Phase

```
Phase Completed: [name]

What Changed:
- ...

Files Changed:
- ...

How To Test:
- ...

Known Issues:
- ...

Next Recommended Phase: [name]

Stopping here for approval before proceeding.
```

Do not continue to the next phase without user approval.

---

## Manual Testing Checklist

### Phase 0
- [ ] App builds in Xcode without errors
- [ ] Project structure matches architecture
- [ ] Memory, MemorySourceType, OCRStatus compile
- [ ] No unused speculative systems added

### Phase 1
- [ ] App launches
- [ ] All screens navigate correctly
- [ ] No crashes

### Phase 2
- [ ] Mock memories appear in feed
- [ ] Memories persist after restart
- [ ] Detail screen opens a memory
- [ ] Views do not directly touch persistence

### Phase 3
- [ ] Permission request appears
- [ ] Denied/limited states handled gracefully
- [ ] Only screenshots imported (not regular photos)
- [ ] No duplicate imports

### Phase 4
- [ ] OCR starts, status updates correctly
- [ ] OCR text appears in detail view
- [ ] App stays responsive during OCR
- [ ] OCR text persists after restart

### Phase 5
- [ ] Keyword search returns correct results
- [ ] Case-insensitive and partial match work
- [ ] No-results state works
- [ ] Results persist after restart

### Phase 6
- [ ] Cards show thumbnail, title, OCR preview, date, status
- [ ] Empty/loading/error states are clear

### Phase 7
- [ ] Delete only appears when original exists
- [ ] Confirmation always required
- [ ] Memory searchable after deletion
- [ ] No auto-delete behavior

### Phase 8
- [ ] Onboarding appears on first launch only
- [ ] Privacy copy is honest
- [ ] Permission recovery instructions are clear

### Phase 9
- [ ] Full end-to-end flow on real device
- [ ] No crashes, no hidden uploads, no API keys
