# RecallThat — App Store Rejection Fix (Build 9)

## Rejection Reason (Build 8, June 10 2026)

**Guideline 5.1.1(iv) — Pre-permission button label**  
App Review saw a "Allow Access" button on the custom screen shown before the Photos permission
dialog. Apple requires neutral labels like "Continue" or "Next" on pre-permission buttons.

---

## Fix Phases

### Phase 1 — Button label fix ✅ (already done in working tree)
File: `RecallThat/Views/PhotoPermissionView.swift`  
Change: `Button("Allow Access")` → `Button("Continue")` for the `.notDetermined` state.

**Verify:** Open the app fresh (no Photos permission granted). The screen before the iOS
permission dialog must show a "Continue" button, not "Allow Access".

---

### Phase 2 — Privacy copy accuracy ✅ (already done in working tree)
Three files updated to reflect that extracted text goes to OpenAI (not "stays on device"):

- `RecallThat/Views/OnboardingView.swift` — page 2 body updated
- `RecallThat/Views/PhotoPermissionView.swift` — description updated
- `RecallThat/Views/SettingsView.swift` — Privacy section footnote updated

**Verify:** Read each of those three descriptions and confirm they mention OpenAI for semantic
search / AI answers, without claiming everything stays on-device.

---

### Phase 3 — Commit + increment build number ✅ (done, pushed to master)
- [x] Committed button/privacy-copy fix: `fix: use neutral "Continue" button for Photos pre-permission screen (App Store 5.1.1iv)`
- [x] Bumped `CURRENT_PROJECT_VERSION` 1 → 9 in `RecallThat.xcodeproj/project.pbxproj`
- [ ] Archive and upload via Xcode Organizer (requires macOS/Xcode — not possible from this Codespace)

---

### Phase 4 — Privacy doc accuracy ✅ (done, pushed to master)
Docs previously claimed "no cloud" / "nothing uploaded" / "no data collected" — false now that OCR
text is sent to OpenAI for semantic search + AI answers. Fixed: `docs/privacy-policy.html`,
`AppStore/metadata.md`, `AppStore/submission-checklist.md`, `Readme.md`,
`RecallThat/PrivacyInfo.xcprivacy` (now declares `NSPrivacyCollectedDataTypeOtherUserContent`).

---

### Phase 5 — Bug: OpenAI calls not working in shipped builds ✅ (fix added, needs Xcode Cloud config + verification)

**Root cause:** `RecallThat/Resources/Info.plist` has `OpenAIAPIKey = $(OPENAI_API_KEY)`. This
`$(...)` syntax only resolves against actual Xcode **build settings**/xcconfig values — it does
NOT pick up Xcode Cloud workflow environment variables, which are shell-only and visible solely
inside `ci_scripts/*.sh`. With no `ci_scripts` directory in the repo, the key was never injected;
`APIConfig.swift`'s `hasPrefix("$(")` guard then silently returned an empty key, disabling all AI
features (embeddings, RAG chat) with no visible error.

**Fix:** Added `ci_scripts/ci_post_clone.sh` (required location: same level as
`RecallThat.xcodeproj`). It reads the `OPENAI_API_KEY` shell env var that Xcode Cloud injects into
the script, and uses `PlistBuddy` to write the real value into `Info.plist` before the build runs.

- [x] Added `ci_scripts/ci_post_clone.sh`, made executable (verified `git ls-files` shows mode `100755`)
- [ ] Confirm in App Store Connect → Xcode Cloud → Workflow → Environment that `OPENAI_API_KEY` is
      set as an **Environment Variable** (not a "Secret" misconfigured some other way) on the
      workflow used for builds
- [ ] Trigger a new Xcode Cloud build and check the build log for the `ci_post_clone.sh` step —
      should print `OpenAIAPIKey injected into Info.plist` (or the warning if the var is still unset)
- [ ] Install that build and verify AI search / chat answers actually return results (not silent
      keyword-only fallback)

---

## Nothing Else to Change

No new features, no model changes, no UI rework needed beyond the items above.
