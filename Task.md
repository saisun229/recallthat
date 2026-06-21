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

### Phase 3 — Commit + increment build number
- [ ] Commit the three changed files with message: `fix: use neutral "Continue" button for Photos pre-permission screen (App Store 5.1.1iv)`
- [ ] In Xcode → project settings → bump CFBundleVersion from 8 → 9
- [ ] Archive and upload via Xcode Organizer

---

### Phase 4 — Resubmission checklist
- [ ] In App Store Connect, select build 9 for the existing 1.0 version
- [ ] Reply to the App Review thread confirming the button label is now "Continue"
- [ ] Submit for review

---

## Nothing Else to Change

The rest of the app is unaffected. No new features, no model changes, no UI rework needed for
this resubmission.
