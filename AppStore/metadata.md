# RecallThat — App Store Metadata

Paste each field directly into App Store Connect.
Character counts shown in brackets [n/max].

---

## App Name
RecallThat [10/30]

## Subtitle  [28/30]
Search your screenshots by text

## Description  [~1400/4000 chars — room to expand]

Find what you screenshot. Instantly.

You screenshot things to remember them — a recipe, a price, a phone number, an address. Then you can never find it again. RecallThat fixes that.

Every time you import a screenshot, RecallThat reads the text inside it using Apple's on-device Vision. Search for any word — or ask a question in plain English — and find it in seconds.

**How it works**
1. Tap the import button and select screenshots from your Photos library.
2. RecallThat extracts all the text on-device using Apple Vision.
3. Search any word, or ask a question to get an AI-generated answer with sources.
4. Once indexed, delete the original from Photos to free up space. The text and title stay in RecallThat forever.

**Share Extension**
Save content from other apps directly to RecallThat. Share images, links, PDFs, text, and videos from Safari, Notes, Files — anywhere.

**Private by design**
- All OCR runs on your device using Apple Vision — your screenshots and thumbnails never leave your device.
- No account required. No developer-owned backend or sync.
- Extracted text may be sent to OpenAI to power semantic search and AI-generated answers (optional, falls back to offline keyword search if unavailable).
- Delete everything at any time from Settings.

**Clean and fast**
- Instant keyword search across all your memories.
- Thumbnail previews so you recognise entries at a glance.
- Portrait-only, no clutter.

RecallThat is for anyone who uses their phone camera as a second brain and wishes they could actually search it.

---

## Keywords  [96/100]
screenshot,search,OCR,memory,text,recall,notes,photo,scan,finder,index,vision,capture,save,find

---

## Promotional Text  [169/170]
Turn your screenshots into a searchable index. On-device OCR, AI-powered answers. No account. Just find what you forgot.

---

## What's New (first release — leave blank or use this)
Initial release.

---

## Support URL
https://github.com/saisun229/recallthat/issues

## Marketing URL (optional)
https://saisun229.github.io/recallthat/

## Privacy Policy URL  ← REQUIRED
https://saisun229.github.io/recallthat/privacy-policy.html

---

## App Information

| Field | Value |
|-------|-------|
| Category | Productivity |
| Secondary category | Utilities |
| Age Rating | 4+ |
| Content rights | Does not use third-party content |
| License Agreement | Standard EULA |

---

## App Review Notes (paste into the "Notes for App Review" field)

RecallThat requires Photos access to import and OCR screenshots.
To test the core flow:
1. Launch the app and complete the 3-page onboarding.
2. Tap "Import from Photos" on the home screen.
3. Grant Photos permission when prompted.
4. Select any screenshot — the app will extract text and create a memory card.
5. Use the Search tab to find the imported text.

The Share Extension can be tested by:
1. Open Safari or Photos and tap the Share button.
2. Select "RecallThat" from the share sheet.
3. The extension will process and save the content, then dismiss automatically.

No account or login is required. No internet connection is needed for the core OCR/import/keyword-search flow. An internet connection is used (via a developer-supplied OpenAI API key) only for the optional semantic search and AI-answer features; these fail gracefully to offline keyword search if unavailable.

Re: Guideline 5.1.1(i)/5.1.2(i) (data sharing disclosure) — Resolved. Onboarding page 2 now requires an explicit choice ("Allow Sharing with OpenAI" or "Keep On-Device Only") before any extracted text is sent to OpenAI. The choice is also changeable anytime via a toggle in Settings → AI Search. No screenshot, photo, or thumbnail is ever sent — only OCR text, and only after this explicit opt-in.

Re: Guideline 5 (China DST/ChatGPT licensing) — Resolved. The China mainland storefront has been deselected in Availability settings; this app is not being distributed in China and the OpenAI-powered functionality remains active everywhere else.

---

## Screenshots Required

Apple requires at least one device family. Minimum: **iPhone 6.5"** (iPhone 14 Plus / 15 Plus / 15 Pro Max Simulator).
Recommended: also add **iPhone 5.5"** (iPhone 8 Plus Simulator) for older device compatibility display.

### Recommended screens to capture (in this order):

1. **Home — populated state**
   - Import a few screenshots so 3-4 memory cards are visible.
   - Shows: card layout, thumbnail, title, date dot.

2. **Search — active with results**
   - Type a word that matches an imported screenshot (e.g. "price" or a brand name).
   - Shows: search bar active, highlighted results.

3. **Memory Detail**
   - Tap any memory card to open the detail view.
   - Shows: full OCR text, thumbnail, delete button.

4. **Onboarding — page 1**
   - Fresh install (or clear UserDefaults in Simulator).
   - Shows: "Find What You Forgot" splash with the animated gradient.

5. **Onboarding — privacy page**
   - Swipe to page 2 "Your Photos Stay Private".
   - Reinforces the privacy angle in the listing.

### Screenshot sizes to export from Simulator:

| Device | Size string | Required? |
|--------|-------------|-----------|
| iPhone 16 Pro Max (or 15 Pro Max) | 6.9" / 1320×2868 | Yes (6.9" replaces 6.5" for 2025 apps) |
| iPhone 14 Plus (or 13 Pro Max) | 6.5" | Yes (still accepted) |
| iPhone 8 Plus | 5.5" | Recommended |
| iPad Pro 12.9" (3rd gen+) | — | Only if you add iPad support |

In Xcode: **Product → Run** on the target Simulator, then use **File → New Screen Shot** (or Cmd+S in the Simulator) to save PNGs to your Desktop.
