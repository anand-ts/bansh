# InputMethod

This folder contains the native macOS input method target sources for Bansh.

Current contents:

- `main.mm` boots the input method server
- `BanshInputController.mm` bridges macOS text input events to the core engine
- `BanshAppDelegate.mm` creates and holds the `IMKServer`
- `Info.plist` and `BanshInputMethodIcon.tiff` define bundle metadata and icon assets

The implementation should stay thin and delegate composition behavior to `Sources/Core/`.
