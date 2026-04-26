# Core

This folder contains the portable transliteration engine used by Bansh.

The engine stays free of AppKit and `InputMethodKit` dependencies so it can be tested in isolation and reused by any future platform adapters.

Files here are expected to be plain C++.
