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

Alexx: Snippet Keyboard includes a custom keyboard. No account is required.

To test: open the app, go to Setup, and follow the four steps. Settings opens from the button; from there go to General > Keyboard > Keyboards > Add New Keyboard > Alexx: Snippet Keyboard. The Try it field on the Setup tab accepts the keyboard. Without Full Access the keyboard inserts built-in examples. With Full Access it reads personal snippets from the shared App Group container. The app and keyboard do not make network requests or collect typing activity.

## Screenshots

These two files are the required sizes, with no transparency. Upload them as the first screenshot for each slot. App Store Connect scales them to the other iPhone and iPad sizes. Add setup or search shots from the Simulator if you want a longer product page. Do not upload the welcome screen by itself.

- [AppStore/Screenshots/iphone-snippets.png](AppStore/Screenshots/iphone-snippets.png) — 1206×2622. iPhone with Dynamic Island, medium display (required).
- [AppStore/Screenshots/ipad-snippets.png](AppStore/Screenshots/ipad-snippets.png) — 2064×2752. iPad 13-inch (required because the app supports iPad).

iPhone Duo screenshots are not required until an app is built with the iOS 27.1 SDK, which this project does not use.

## Check before you submit

- First launch, create and edit a snippet, search, categories, favorites, and delete
- Keyboard with Full Access off, then on
- Dark Mode, iPhone, and iPad
- Archive validates in Xcode without signing or privacy errors
