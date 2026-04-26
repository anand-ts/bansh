# Packaging

This folder is for the release and installer workflow for the macOS product.

Initial packaging target:

- direct distribution outside the Mac App Store
- simple direct-download install path
- system-wide install into `/Library/Input Methods`
- admin-password install flow with `xattr -cr` fallback when Gatekeeper blocks the download

Planned artifacts:

- signed input method bundle
- extracted folder containing the app plus install scripts
- zip file for sharing
- release notes and install documentation

## Development Path

Until the full Xcode packaging workflow is in place, the `scripts/` folder includes a lightweight dev path:

- `scripts/build-dev-app.sh` builds and copies a local `BanshInputMethod.app`
- `scripts/test-core.sh` runs the Xcode core test bundle
- `scripts/install-dev-input-method.sh` copies the app into `~/Library/Input Methods`
- `scripts/install-system-input-method.sh` copies the app into `/Library/Input Methods`
- `scripts/debug-input-source.sh bansh` inspects whether the system registered the input source
- `scripts/show-input-method-logs.sh 10m` shows recent HIToolbox and text-input logs
- `scripts/uninstall-dev-input-method.sh` removes the local install and refreshes input services
- `scripts/uninstall-system-input-method.sh` removes the system-wide install and refreshes input services

This is for local iteration only. Proper signing, notarization, installer packaging, and release validation still belong in the final release workflow.

## Release Staging

- `scripts/archive-release.sh` creates a Release `.xcarchive` at `build/release/BanshInputMethod.xcarchive`
- `scripts/package-direct-download.sh` builds the archive, bundles a standalone install helper, and writes `build/direct-download/Bansh-<version>-direct-download.zip`

## Direct Download Flow

- The download contains `BanshInputMethod.app`, `Install Bansh.command`, `Uninstall Bansh.command`, and `README.txt`
- End users install by double-clicking `Install Bansh.command` and entering their administrator password
- If Gatekeeper blocks the downloaded folder, the fallback is `xattr -cr "/path/to/Bansh"` and then rerunning the installer
- The installer copies Bansh into `/Library/Input Methods`, clears quarantine attributes, registers the input source, and restarts text input services

## Expected Release Flow

1. Build a signed Release archive with `scripts/archive-release.sh`
2. Produce the direct-download zip with `scripts/package-direct-download.sh`
3. Validate install, enable, and input-source switching on a clean Mac
4. Share the zip and the short `xattr -cr` fallback instructions
