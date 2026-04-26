<p align="center">
  <a href="https://www.flaticon.com/free-icon/dumpling_9361828?term=dumpling&page=1&position=29&origin=tag&related_id=9361828">
    <img src="https://cdn-icons-png.flaticon.com/512/9361/9361828.png" alt="Bansh dumpling icon" width="96" height="96">
  </a>
</p>

# Bansh (Банш)

Bansh is a native macOS input method for Mongolian Cyrillic transliteration.

The codebase keeps the transliteration engine in portable C++ and the macOS `InputMethodKit` layer thin, so text behavior is deterministic and covered by tests.

## Install

Download the latest release:
[Bansh-0.1.0-direct-download.zip](https://github.com/anand-ts/bansh/releases/latest/download/Bansh-0.1.0-direct-download.zip)

1. Extract the zip.
2. Double-click `Install Bansh.command`.
3. Enter your administrator password when macOS asks.
4. Open System Settings > Keyboard > Text Input > Input Sources and select Bansh.

If macOS blocks the installer because it was downloaded from the internet, open Terminal and run:

```zsh
xattr -cr "/path/to/Bansh"
```

Then open `Install Bansh.command` again.

To uninstall Bansh, double-click `Uninstall Bansh.command` from the extracted folder.

## Layout

- `Sources/Core/`: transliteration engine
- `Sources/InputMethod/`: macOS input method target
- `Tests/CoreTests/`: core regression tests
- `scripts/`: build, install, debug, package, and uninstall helpers
- `docs/`: transliteration reference docs
- `Packaging/`: release packaging notes and helper sources

## Commands

- `./scripts/test-core.sh`: run the macOS core test bundle
- `./scripts/install-dev-input-method.sh`: build and install locally into `~/Library/Input Methods`
- `./scripts/debug-input-source.sh bansh`: inspect registered Bansh input sources
- `./scripts/show-input-method-logs.sh 10m`: show recent input-method logs
- `./scripts/uninstall-dev-input-method.sh`: remove the local development install
- `./scripts/package-direct-download.sh`: build the direct-download zip

## Signing

The checked-in project does not include a personal Apple development team ID. Local install and packaging scripts use `BANSH_DEVELOPMENT_TEAM` or `DEVELOPMENT_TEAM` when provided, otherwise they infer a team from the Apple Development certificate available on the current Mac. Build outputs stay under `build/`.

## License

Bansh is licensed under the Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

The README dumpling icon links to [Flaticon icon 9361828](https://www.flaticon.com/free-icon/dumpling_9361828?term=dumpling&page=1&position=29&origin=tag&related_id=9361828).

> Project inspired by [Buuz](https://github.com/odbayar/buuz) on Windows :)
