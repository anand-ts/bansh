# InputMethod

This folder contains the native macOS input method target sources for Bansh.

Current contents:

- `main.mm` boots the input method server
- `BanshInputController.mm` bridges macOS text input events to the core engine
- `BanshMappingCatalog.mm` provides the mapping reference displayed by the native help panel
- `BanshAppDelegate.mm` creates and holds the `IMKServer`
- `Info.plist` defines the bundle metadata
- `BanshAppIcon.icns` is the application icon; `BanshInputMethodIcon.tiff` is the monochrome input-source menu icon; their editable sources live in `Brand/`

The implementation should stay thin and delegate composition behavior to `Sources/Core/`.
