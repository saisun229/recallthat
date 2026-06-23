# RecallThat — App Store Submission Checklist

Work through each section in order. Each step must be done before the next.

---

## Step 1 — Apple Developer Account  (do once, skip if enrolled)

1. Go to https://developer.apple.com/programs/enroll/
2. Enroll in the **Apple Developer Program** ($99/year).
   - When asked entity type: choose **Individual** (not Organization).
   - Individual enrollment does not require a D-U-N-S number.
   - Your legal name will appear as the seller name on the App Store (e.g. "Sai Krishna Reddy Mudhiganti"). You can set a display name like "RecallThat" as a separate "doing business as" field in App Store Connect later.
3. Approval is usually instant or within a few hours for individuals.

---

## Step 2 — Register the App ID & App Group  (do once, in Apple Developer portal)

1. Sign in at https://developer.apple.com/account/
2. **Identifiers → App IDs → "+"**
   - Platform: iOS
   - Type: App
   - Bundle ID: `com.recallthat.app` (Explicit)
   - Description: RecallThat
   - Capabilities: check **App Groups**
3. **Identifiers → App Groups → "+"**
   - Description: RecallThat Shared Container
   - Identifier: `group.com.recallthat.app`
4. Go back to the `com.recallthat.app` App ID → Edit → App Groups → select `group.com.recallthat.app` → Save.
5. Create a second App ID for the Share Extension:
   - Bundle ID: `com.recallthat.app.ShareExtension`
   - Capabilities: check **App Groups** → select `group.com.recallthat.app`

---

## Step 3 — Add PrivacyInfo.xcprivacy to the Xcode project  (macOS, Xcode)

Two files already exist in the repo — they just need to be added to the correct targets.

1. Open `RecallThat.xcodeproj` in Xcode.
2. In the Project Navigator, right-click the **RecallThat** folder (yellow) → **Add Files to "RecallThat"…**
   - Select `RecallThat/PrivacyInfo.xcprivacy`
   - "Add to targets": check **RecallThat** only → Add.
3. Right-click the **RecallThatShareExtension** folder → **Add Files to "RecallThat"…**
   - Select `RecallThatShareExtension/PrivacyInfo.xcprivacy`
   - "Add to targets": check **RecallThatShareExtension** only → Add.
4. Select the `PrivacyInfo.xcprivacy` file in each target. In the File Inspector (right panel) confirm **Target Membership** is checked for the correct target only.

---

## Step 4 — Configure Signing in Xcode  (macOS, Xcode)

1. Select the root **RecallThat** project in the navigator.
2. Select the **RecallThat** target → **Signing & Capabilities**.
   - Team: select your Apple Developer team.
   - Bundle Identifier: `com.recallthat.app`
   - "Automatically manage signing": check it.
3. Click **+ Capability** → add **App Groups** → click "+" and enter `group.com.recallthat.app`.
4. Select the **RecallThatShareExtension** target → Signing & Capabilities.
   - Team: same team.
   - Bundle Identifier: `com.recallthat.app.ShareExtension`
   - Add **App Groups** capability → select `group.com.recallthat.app`.
5. Build once (**Cmd+B**) to confirm signing succeeds with no errors.

---

## Step 5 — Enable GitHub Pages for the Privacy Policy

1. In the repo on GitHub: **Settings → Pages**.
2. Source: **Deploy from a branch**.
3. Branch: `master`, folder: `/docs` → Save.
4. After ~1 minute, the privacy policy will be live at:
   `https://saisun229.github.io/recallthat/privacy-policy.html`
5. Test the URL in a browser before proceeding.

---

## Step 6 — Create the app in App Store Connect

1. Go to https://appstoreconnect.apple.com/
2. **My Apps → "+" → New App**
   - Platforms: iOS
   - Name: `RecallThat`
   - Primary language: English (U.S.)
   - Bundle ID: `com.recallthat.app` (select from dropdown — appears after Step 2)
   - SKU: `recallthat-ios-1` (any unique string)
3. Fill in metadata from `AppStore/metadata.md`:
   - Subtitle, description, keywords, promotional text.
   - Privacy Policy URL: `https://saisun229.github.io/recallthat/privacy-policy.html`
   - Support URL: `https://github.com/saisun229/recallthat/issues`
4. **App Information → Category**: Productivity / Utilities.
5. **App Privacy (Data Collection)**: answer the questionnaire:
   - "Do you collect data from this app?" → **Yes**. Declare **User Content** (text extracted from screenshots): not linked to identity, not used for tracking, purpose **App Functionality**, shared with a third party (OpenAI) for semantic search and AI-generated answers. Screenshots/photos themselves and thumbnails are not collected — they stay on-device.
6. **Age Rating**: complete the questionnaire → should result in **4+**.

---

## Step 7 — Take App Store Screenshots  (macOS, Xcode + Simulator)

See `AppStore/metadata.md` → "Screenshots Required" section for which screens to capture.

1. In Xcode, select the **iPhone 16 Pro Max** Simulator (or 15 Pro Max).
2. Run the app (**Cmd+R**).
3. Navigate to each screen described in the metadata file.
4. Press **Cmd+S** in the Simulator window to save each PNG to Desktop.
5. Repeat with **iPhone 8 Plus** Simulator for 5.5" screenshots.
6. Upload all screenshots in App Store Connect under **iOS App → 6.9-inch Display** and **5.5-inch Display**.

---

## Step 8 — Archive and Upload  (macOS, Xcode)

1. In Xcode, select **Any iOS Device (arm64)** as the run destination (not a Simulator).
2. **Product → Archive** — wait for the build to complete.
3. The **Organizer** window opens automatically with the archive.
4. Click **Distribute App** → **App Store Connect** → **Upload** → follow prompts.
   - Strip Swift symbols: Yes
   - Include bitcode: leave default (No for iOS 17+)
5. Xcode uploads the build. It appears in App Store Connect under **TestFlight** within ~15 minutes.

---

## Step 9 — TestFlight (optional but recommended before full release)

1. In App Store Connect → **TestFlight** tab → find the new build.
2. Add a test group and invite yourself (and any testers) by email.
3. Install the app via the TestFlight iOS app.
4. Test the full flow: onboarding → import → OCR → search → delete → share extension.
5. Fix any issues, increment the build number in Xcode (**CURRENT_PROJECT_VERSION**), re-archive, re-upload.

---

## Step 10 — Submit for App Review

1. In App Store Connect, go to your app's **iOS App** page.
2. Select the uploaded build from the dropdown under "Build".
3. Fill in **App Review Information**:
   - Notes: paste the block from `AppStore/metadata.md` → "App Review Notes".
   - Sign-in required: **No**.
4. Pricing: Free.
5. Release: **Manually release this version** (safer for first release — lets you release at a time of your choosing after approval).
6. **Availability**: under **App Availability**, deselect **China mainland** (required — the app uses OpenAI/ChatGPT-adjacent functionality that isn't licensed for distribution there; see App Review Notes).
7. Click **Submit for Review**.

**Average review time for new apps: 1–3 days.**

---

## Quick Reference — Checklist

- [ ] Apple Developer Program enrolled
- [ ] App ID `com.recallthat.app` registered
- [ ] App Group `group.com.recallthat.app` registered and linked to both IDs
- [ ] `PrivacyInfo.xcprivacy` added to both Xcode targets
- [ ] Signing configured in Xcode (both targets)
- [ ] Project builds clean on device (arm64)
- [ ] GitHub Pages live at `saisun229.github.io/recallthat/privacy-policy.html`
- [ ] App created in App Store Connect
- [ ] Metadata filled (name, subtitle, description, keywords)
- [ ] Privacy Policy URL set in App Store Connect
- [ ] App Privacy questionnaire complete (User Content shared with OpenAI declared)
- [ ] Age rating questionnaire complete (4+)
- [ ] Screenshots uploaded (6.9" required)
- [ ] Archive uploaded from Xcode Organizer
- [ ] Build selected in App Store Connect
- [ ] App Review notes filled
- [ ] China mainland deselected in Availability settings
- [ ] Submitted for review
