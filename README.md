# Bansh (Банш)

Bansh is a native macOS input method for Mongolian Cyrillic transliteration.

The codebase keeps the transliteration engine in portable C++ and the macOS `InputMethodKit` layer thin, so text behavior is deterministic and covered by tests.

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

> Project inspired by [Buuz](https://github.com/odbayar/buuz) on Windows :)
