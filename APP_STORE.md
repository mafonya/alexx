# Snippy App Store submission

Version 1.0 (1). Category: Productivity. Price: Free. Age rating: 4+.

The Xcode project is set up for upload. Creating the App Store record, uploading the archive, and submitting for review still happen in Xcode and App Store Connect.

## Already in the project

- Display name Snippy, version 1.0, build 1, deployment target iOS 17
- Category `public.app-category.productivity`
- 1024×1024 app icon, 8-bit RGB, no transparency
- `ITSAppUsesNonExemptEncryption` is false, so the upload does not stop for an encryption question
- Privacy manifests for the app and the keyboard extension: no tracking, no collected data
- The app declares UserDefaults access (`CA92.1`) because it stores whether the welcome screen has been seen
- In-app privacy policy, support link, and license on the Setup tab
- Setup steps tell the reviewer how to add the keyboard. The Settings button uses the public Settings URL and does not claim to open the keyboard list directly
- The keyboard works without Full Access (built-in examples) and requests Full Access only to read the on-device snippet library

## Signing, before the first upload

This Mac has an Apple Development certificate for Michael Abramov and no Apple Distribution certificate. Team `A39F493A5W` is the team in the project. A free Personal Team cannot upload to App Store Connect.

1. Enroll the Apple Account that should own Snippy in the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Xcode, select the `Keyboard` and `SnippetKeyboard` targets, set Signing & Capabilities to that paid team, and let Automatic signing create the App ID and the App Group.
3. Decide the bundle IDs before creating the app in App Store Connect. The IDs in the project today are `com.michaelabramovpersonalteam.Keyboard` and `com.michaelabramovpersonalteam.Keyboard.SnippetKeyboard`, with App Group `group.com.michaelabramovpersonalteam.Keyboard`. They can ship as-is. They cannot be changed after the first upload. If the paid team should use different IDs, change all three together: both bundle IDs, both entitlement files, and `appGroupIdentifier` in `Keyboard/ContentView.swift` and `SnippetKeyboard/SnippetKeyboard.swift`.
4. Product > Archive, then Distribute App > App Store Connect > Upload.

## Paste into App Store Connect

**Name:** Snippy

**Subtitle:** Text snippets, one tap away

**Promotional text:** Save replies, addresses, and messages on your device, then insert them from the Snippy keyboard.

**Description:**

Save the words you use often and insert them with a tap. Snippy keeps reusable replies, email addresses, links, and longer messages organized in one place. Search your snippets, group them into categories, mark favorites, and choose an emoji for each one. Add the Snippy keyboard to use your snippets in other apps.

Your snippets stay on your device. Snippy has no account, analytics, advertising, or network requests. The keyboard offers built-in examples without Full Access. Allow Full Access to share your personal snippet library with the keyboard through storage that stays on the device.

**Keywords:** snippets,keyboard,quick reply,text expander,templates,phrases,shortcuts,canned

**Support URL:** https://github.com/mafonya/snippy/issues

**Marketing URL:** https://github.com/mafonya/snippy

**Privacy Policy URL:** https://github.com/mafonya/snippy/blob/main/PRIVACY.md

Push `PRIVACY.md` to the default branch before entering that URL. The same policy is shown in the app under Setup > Privacy Policy.

**Copyright:** 2026 SnippetKeyboard contributors

**Primary language:** English (U.S.)

**SKU:** snippy-ios

## App Privacy

Answer “No” to tracking and “No” to collecting data. Snippy does not send snippets, typing, identifiers, or diagnostics off the device. There are no third-party SDKs.

## Age rating

Answer None or No for every content and capability question, including unrestricted web access, user-generated content shared with other people, messaging, and advertising. The expected rating is 4+.

## Export compliance

The app does not use encryption. The Info.plist flag answers the upload question. If App Store Connect still asks, choose that the app does not use non-exempt encryption. No French encryption declaration is required.

## Review notes

Snippy includes a custom keyboard. No account is required.

To test: open the app, go to Setup, and follow the four steps. Settings opens from the button; from there go to General > Keyboard > Keyboards > Add New Keyboard > Snippy. The Try it field on the Setup tab accepts the keyboard. Without Full Access the keyboard inserts built-in examples. With Full Access it reads personal snippets from the shared App Group container. The app and keyboard do not make network requests or collect typing activity.

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
