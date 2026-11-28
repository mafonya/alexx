# Alexx: Snippet Keyboard App Store submission

Version 1.0 (1). Category: Productivity. Price: Free. Age rating: 4+.

The Xcode project is set up for upload. Creating the App Store record, uploading the archive, and submitting for review still happen in Xcode and App Store Connect.

## Already in the project

- Display name Alexx: Snippet Keyboard, version 1.0, build 1, deployment target iOS 17
- Category `public.app-category.productivity`
- 1024×1024 app icon, 8-bit RGB, no transparency
- `ITSAppUsesNonExemptEncryption` is false, so the upload does not stop for an encryption question
- Privacy manifests for the app and the keyboard extension: no tracking, no collected data
- The app declares UserDefaults access (`CA92.1`) because it stores whether the welcome screen has been seen
- In-app privacy policy, support link, and license on the Setup tab
- Setup steps tell the reviewer how to add the keyboard. The Settings button uses the public Settings URL and does not claim to open the keyboard list directly
- The keyboard works without Full Access (built-in examples) and requests Full Access only to read the on-device snippet library

## Signing — done

The project is on the paid `Duke Bear Inc.` team (`C657PSA3Z2`), bundle IDs `com.snippykeyboard.app` and `com.snippykeyboard.app.SnippetKeyboard`, App Group `group.com.snippykeyboard.app`. An Apple Distribution certificate for this team exists in this Mac's keychain. Build 1.0 (1) has been archived, exported, and uploaded to App Store Connect (app id `6838145084`) via `xcodebuild -exportArchive -allowProvisioningUpdates` with `destination: upload` in the export options plist.

Note: if re-exporting on this Mac, set `uploadSymbols: false` in the export options plist — this system's `/usr/bin/rsync` is openrsync, which doesn't support the `-E` flag Xcode's dSYM-copy step uses, and the export fails with a bare "Copy failed" otherwise.

To ship a new build: Product > Archive, then Distribute App > App Store Connect > Upload (or repeat the `xcodebuild -exportArchive` command above after bumping `CURRENT_PROJECT_VERSION`).

## Paste into App Store Connect

**Name:** Alexx: Snippet Keyboard

**Subtitle:** Text snippets, one tap away

**Promotional text:** Save replies, addresses, and messages on your device, then insert them from the Alexx: Snippet Keyboard keyboard.

**Description:**

Save the words you use often and insert them with a tap. Alexx: Snippet Keyboard keeps reusable replies, email addresses, links, and longer messages organized in one place. Search your snippets, group them into categories, and mark favorites. Add the Alexx: Snippet Keyboard keyboard to use your snippets in other apps.

Your snippets stay on your device. Alexx: Snippet Keyboard has no account, analytics, advertising, or network requests. The keyboard offers built-in examples without Full Access. Allow Full Access to share your personal snippet library with the keyboard through storage that stays on the device.

**Keywords:** snippets,keyboard,quick reply,text expander,templates,phrases,shortcuts,canned

**Support URL:** https://github.com/mafonya/alexx/issues

**Marketing URL:** https://github.com/mafonya/alexx

**Privacy Policy URL:** https://github.com/mafonya/alexx/blob/main/PRIVACY.md

Push `PRIVACY.md` to the default branch before entering that URL. The same policy is shown in the app under Setup > Privacy Policy.

**Copyright:** 2026 SnippetKeyboard contributors

**Primary language:** English (U.S.)

**SKU:** snippy-ios

## App Privacy

Answer “No” to tracking and “No” to collecting data. Alexx: Snippet Keyboard does not send snippets, typing, identifiers, or diagnostics off the device. There are no third-party SDKs.

## Age rating

Answer None or No for every content and capability question, including unrestricted web access, user-generated content shared with other people, messaging, and advertising. The expected rating is 4+.

## Export compliance

The app does not use encryption. The Info.plist flag answers the upload question. If App Store Connect still asks, choose that the app does not use non-exempt encryption. No French encryption declaration is required.

## Review notes

Alexx: Snippet Keyboard is a free utility for anyone who repeatedly types the same text, such as replies, addresses, and links. It lets users save and organize text snippets and insert them into other apps using a custom keyboard, reducing repetitive typing.

No account, login, subscription, payment, or sample file is required. To test, open the app and create a snippet using the plus button. Open Setup and use Open Settings, then go to General > Keyboard > Keyboards > Add New Keyboard and add Alexx: Snippet Keyboard. To access user-created snippets from the keyboard, select it in the keyboard list and enable Allow Full Access. Return to Alexx, tap the Try it field on the Setup tab, use the globe key to select the Alexx keyboard, and tap the snippet to insert it. Built-in examples are available without Full Access. The app can also search, favorite, edit, categorize, import, export, and back up snippets.

The app's core functionality uses no external services, data providers, authentication, payment processors, or AI services. Snippets are stored on the device and shared with the keyboard through an App Group. Support and source-code links open GitHub separately.

The app's features and content are the same across regions. It is a general-purpose productivity utility; it does not provide regulated services or include protected third-party content requiring authorization.

Physical-device recording: [Add a review-accessible link after recording and verifying the submitted build on a physical device running the latest iOS.]

## Screenshots

The six local App Store screenshots are in `AppStore/Screenshots/Illustrated/`. Each device set shows Snippets in light mode, Keyboard Setup, and Snippets in dark mode, using actual simulator captures. The frames pair those screens with Foxy kitesurfing, snowboarding, and playing tennis, in that order. The iPhone images are 1320 × 2868 and the iPad images are 2064 × 2752.

Raw simulator captures and the 19-second iPhone demo are in `AppStore/ReviewMedia/`. The demo shows launch and the Snippets library in light and dark mode. Apple requested a separate physical-device recording demonstrating the full keyboard workflow.

## Check before you submit

- First launch, create and edit a snippet, search, categories, favorites, and delete
- Keyboard with Full Access off, then on
- Dark Mode, iPhone, and iPad
- Archive validates in Xcode without signing or privacy errors
