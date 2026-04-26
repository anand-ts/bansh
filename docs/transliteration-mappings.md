# Transliteration Mappings

Mongolian version: [transliteration-mappings.mn.md](./transliteration-mappings.mn.md)

This document mirrors the rules currently defined in `Sources/Core/TransliterationSession.cpp`.

## Notes

- The tables use canonical uppercase inputs for readability. Alphabetic rules are case-aware in code, so lowercase and mixed-case variants also work.
- The engine uses longest-match wins. For example, `CH` matches before `C`, and `III` matches before `II` or `I`.
- Each new composition starts in a masculine harmony state.
- Some mappings change the current harmony state:
  - masculine setters: `A`, `AI`, `YA`, `YO`, `YU`, and the forced `O`/`U` forms with `"`
  - feminine setters: `E`, `EI`, `Q`, `QI`, `W`, `WI`, `YE`, and the forced `O`/`U` forms with `'`
- The ambiguous vowel mappings `O` / `OI` and `U` / `UI` depend on the current harmony state.
- The mixed-script rules near the bottom of the implementation exist so already-converted Cyrillic text can continue to compose correctly when the user edits inside an active composition.

## Base Latin Mappings

| Input | Output | Notes |
| --- | --- | --- |
| `A` | `А` | Sets masculine harmony |
| `AI` | `АЙ` | Sets masculine harmony |
| `B` | `Б` |  |
| `C` | `Ц` |  |
| `CH` | `Ч` |  |
| `D` | `Д` |  |
| `E` | `Э` | Sets feminine harmony |
| `EI` | `ЭЙ` | Sets feminine harmony |
| `F` | `Ф` |  |
| `G` | `Г` |  |
| `H` | `Х` |  |
| `I` | `И` |  |
| `II` | `ИЙ` |  |
| `III` | `Ы` |  |
| `J` | `Ж` |  |
| `K` | `К` |  |
| `KH` | `Х` |  |
| `L` | `Л` |  |
| `M` | `М` |  |
| `N` | `Н` |  |
| `P` | `П` |  |
| `Q` | `Ө` | Sets feminine harmony |
| `QI` | `ӨЙ` | Sets feminine harmony |
| `R` | `Р` |  |
| `S` | `С` |  |
| `SH` | `Ш` |  |
| `SXC` | `Щ` |  |
| `T` | `Т` |  |
| `V` | `В` |  |
| `W` | `Ү` | Sets feminine harmony |
| `WI` | `ҮЙ` | Sets feminine harmony |
| `X` | `Х` |  |
| `Y` | `Ы` |  |
| `YA` | `Я` | Sets masculine harmony |
| `YE` | `Е` | Sets feminine harmony |
| `YO` | `Ё` | Sets masculine harmony |
| `YU` | `Ю` | Sets masculine harmony |
| `Z` | `З` |  |

## Context-Sensitive Vowel Mappings

| Input | Masculine Output | Feminine Output | Notes |
| --- | --- | --- | --- |
| `O` | `О` | `Ө` | Depends on current harmony state |
| `OI` | `ОЙ` | `ӨЙ` | Depends on current harmony state |
| `U` | `У` | `Ү` | Depends on current harmony state |
| `UI` | `УЙ` | `ҮЙ` | Depends on current harmony state |

## Forced Vowel Forms

These forms bypass the current harmony state and force a specific vowel.

| Input | Output | Notes |
| --- | --- | --- |
| `O"` | `О` | Sets masculine harmony |
| `O"I` | `ОЙ` | Sets masculine harmony |
| `"O` | `О` | Sets masculine harmony |
| `"OI` | `ОЙ` | Sets masculine harmony |
| `O'` | `Ө` | Sets feminine harmony |
| `O'I` | `ӨЙ` | Sets feminine harmony |
| `'O` | `Ө` | Sets feminine harmony |
| `'OI` | `ӨЙ` | Sets feminine harmony |
| `U"` | `У` | Sets masculine harmony |
| `U"I` | `УЙ` | Sets masculine harmony |
| `"U` | `У` | Sets masculine harmony |
| `"UI` | `УЙ` | Sets masculine harmony |
| `U'` | `Ү` | Sets feminine harmony |
| `U'I` | `ҮЙ` | Sets feminine harmony |
| `'U` | `Ү` | Sets feminine harmony |
| `'UI` | `ҮЙ` | Sets feminine harmony |

## Literal Quote Mappings

| Input | Output |
| --- | --- |
| `"` | `ъ` |
| `""` | `Ъ` |
| `'` | `ь` |
| `''` | `Ь` |

## Mixed-Script Continuation Rules

These rules are present in the engine so an active composition can keep behaving correctly after some text has already been transliterated into Cyrillic.

| Input | Output | Notes |
| --- | --- | --- |
| `А` | `А` | Sets masculine harmony |
| `АI` | `АЙ` | Sets masculine harmony |
| `О` | `О` | Sets masculine harmony |
| `ОI` | `ОЙ` | Sets masculine harmony |
| `У` | `У` | Sets masculine harmony |
| `УI` | `УЙ` | Sets masculine harmony |
| `Э` | `Э` | Sets feminine harmony |
| `ЭI` | `ЭЙ` | Sets feminine harmony |
| `Ө` | `Ө` | Sets feminine harmony |
| `ӨI` | `ӨЙ` | Sets feminine harmony |
| `Ү` | `Ү` | Sets feminine harmony |
| `ҮI` | `ҮЙ` | Sets feminine harmony |
| `ИI` | `ИЙ` |  |
