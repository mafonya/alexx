# SnippetKeyboard

SnippetKeyboard is an open-source iPhone app and custom keyboard for creating,
organizing, and inserting reusable text snippets. Snippets are stored locally
in a shared App Group container so the companion app and keyboard extension can
use the same library.

## Features

- Create, edit, search, favorite, and delete snippets
- Organize snippets into custom categories
- Choose an emoji icon for each snippet
- Insert snippets from a compact custom iOS keyboard
- Local storage with no accounts, analytics, or network access

## Requirements

- Xcode with an iOS SDK that supports the project's deployment target
- An Apple Developer team for running the keyboard extension on a physical device

## Getting started

1. Clone the repository and open `Keyboard.xcodeproj` in Xcode.
2. Select the `MyApp` target and choose your development team under Signing & Capabilities.
3. Select the `SnippetKeyboard` target and choose the same team.
4. Replace the current bundle identifiers with identifiers owned by your team.
5. Create an App Group owned by your team and use the same group in both target entitlement files and the shared-container identifier in the source.
6. Build and run `MyApp` on an iPhone.
7. Open **Settings > General > Keyboard > Keyboards > Add New Keyboard**, add SnippetKeyboard, and allow full access so the extension can read the shared local library.

## Project structure

- `Keyboard/` — companion SwiftUI app for managing snippets
- `SnippetKeyboard/` — custom keyboard extension
- `Keyboard.xcodeproj/` — Xcode project and shared schemes

## Privacy

SnippetKeyboard stores snippets locally. The project does not include accounts,
analytics, advertising, or network requests.

## Contributing

Issues and pull requests are welcome. Keep changes focused, build the app and
extension before submitting, and never commit personal signing profiles or
user-specific Xcode data.

## License

Licensed under the [MIT License](LICENSE).
