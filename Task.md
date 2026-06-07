# RecallThat — Task.md (v2 Roadmap)

## Status

Post-MVP AI & UX expansion. Core app is TestFlight-ready.

---

## Completed Phases (v2 Expansion)

### Phase 1 — UI Polish + Share Extension Bug Fix ✅
- Logo/title left-aligned in nav bar (was centered)
- Removed "Reindex All" from the ellipsis menu
- OCR disclosure group closed by default in MemoryDetailView
- Share extension → main app visibility fixed via `NSPersistentStoreRemoteChangeNotification` + UserDefaults signal

### Phase 2 — Temporal Grouping in Memories Tab ✅
- Grouped list: Last 7 Days → Previous 2 Weeks → by Year
- `HomeViewModel.groupedMemories` computed property
- Sectioned `List` with headers in HomeView

### Phase 3 — Data Model Upgrade ✅
- Added `EmbeddingStatus` enum (notStarted / pending / complete / failed)
- Added `embedding: [Float]?` and `embeddingStatus` to `Memory` struct
- Added `embeddingStatusRaw: String` and `embeddingData: Data?` to `MemoryItem` SwiftData model
- SwiftData auto-migrates (new fields have defaults)

### Phase 4 — OpenAI Embedding Service + API Key Settings ✅
- `KeychainHelper` stores API key securely (iOS Keychain)
- `OpenAIEmbeddingService` calls `text-embedding-3-small`
- `EmbeddingPipelineService` background-indexes memories after OCR
- SettingsView "AI Search" section: enter/remove key, trigger indexing
- Graceful no-op when key is missing or API fails

### Phase 5 — Hybrid Search + Reranker ✅
- `VectorMath.cosineSimilarity` using Accelerate/vDSP
- `HybridSearchService` replaces `DefaultSearchService`:
  - Keyword search (instant, offline)
  - Query embedding → cosine similarity on stored vectors (when key is set + embeddings exist)
  - Reciprocal Rank Fusion merge + deduplication
  - Falls back to keyword-only silently if API fails
- `SearchServiceProtocol.search()` is now `async`
- `SearchViewModel` uses Task-based cancellable async search

### Phase 6 — RAG Search Response (LLM + Sources) ✅
- `OpenAILLMService` calls `gpt-4o-mini` with top-5 memory excerpts as context
- Question detection in `SearchViewModel` (question words + `?` suffix)
- SearchView shows "AI Answer" card above results when question detected + key set
- Sources list shown below the AI answer
- Silent fallback: if API fails → show results list only

### Phase 7 — Share Extension Expanded Format Support ✅
- Added `MemorySourceType.sharedFile` for generic documents
- `ShareViewController` now handles: Word (.docx/.doc), Excel (.xlsx/.xls), Keynote/PowerPoint, plus any generic data file (catch-all)
- Best-effort text extraction; falls back to filename + label
- `MemoryCardView` shows orange file badge for `.sharedFile` items

---

## Next Steps (suggested priorities)

1. **Xcode project file update** — new Swift files must be added to `RecallThat.xcodeproj/project.pbxproj` manually in Xcode before building. New files:
   - `RecallThat/Models/EmbeddingStatus.swift`
   - `RecallThat/Utilities/KeychainHelper.swift`
   - `RecallThat/Utilities/VectorMath.swift`
   - `RecallThat/Services/Embedding/EmbeddingServiceProtocol.swift`
   - `RecallThat/Services/Embedding/OpenAIEmbeddingService.swift`
   - `RecallThat/Services/Embedding/EmbeddingPipelineService.swift`
   - `RecallThat/Services/Search/HybridSearchService.swift`
   - `RecallThat/Services/LLM/LLMServiceProtocol.swift`
   - `RecallThat/Services/LLM/OpenAILLMService.swift`

2. **Build + test** in Xcode on real device — verify OCR, sharing, search, AI features

3. **Subscription / monetisation** — if hosting API key is preferred over BYOK, add StoreKit 2 subscription and a simple backend proxy

4. **Streaming LLM responses** — replace non-streaming GPT call with server-sent events for snappier AI answer display

5. **App Store re-submission** — update privacy policy to mention optional OpenAI key usage
