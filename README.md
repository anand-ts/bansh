<p align="center">
  <a href="https://www.flaticon.com/free-icon/dumpling_9361828?term=dumpling&page=1&position=29&origin=tag&related_id=9361828">
    <img src="https://cdn-icons-png.flaticon.com/512/9361/9361828.png" alt="Bansh dumpling icon" width="96" height="96">
  </a>
</p>

# Bansh (Банш)

> bansh (банш) = dumpling

<p align="center">
  <img src="docs/bansh.gif" alt="Bansh demonstration" width="720">
</p>

Bansh (банш) is a native macOS input method (input source) that transliterates Latin-keyboard input into Mongolian Cyrillic.
For example, if you type `bansh id'ye`, it appears as `банш идье`.

## Install

Download the latest release:
[Bansh-0.1.1-direct-download.zip](https://github.com/anand-ts/bansh/releases/latest/download/Bansh-0.1.1-direct-download.zip)

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

## License

Bansh is licensed under the Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

> Project inspired by [Buuz](https://github.com/odbayar/buuz) on Windows :)
