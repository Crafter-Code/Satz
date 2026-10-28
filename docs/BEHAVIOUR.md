# Behaviour reference

The reference installation was Cotypist 2026.5 on macOS with Apple Silicon. Inspection was read-only, followed by an ordinary Quit action. No preferences were changed. No private text, account identity or statistics are copied into this document.

## Observed settings

- General: launch at login, menu bar icon, accessory button, local model selection, default enablement, mid-line completion, length, anonymous diagnostics and spelling controls.
- Context: screen context, appearance assistance and optional clipboard context.
- Personalization: writing history, broader recording, strength, deletion and custom instructions.
- Emoji: shortcode search, emoticons, tone and gender preferences.
- Shortcuts: next word, whole completion, Escape behaviour, activation and pause.
- Battery: on-demand suggestions, smaller models and shorter suggestions.
- Applications: application/domain rules and instructions.
- Labs: alternative words, selected-word synonyms and sync.
- Statistics and subscription controls.

Satz reproduces the requested core workflow independently, rather than reusing proprietary code or assets. Screen capture, clipboard context, cloud sync, domain-level browser adapters, alternate-word pickers and configurable shortcut recording are not implemented in this version. Their absence must not be hidden in release notes.

## Required acceptance scenarios

| Scenario | Expected behaviour |
| --- | --- |
| Start in an eligible text field | A suggestion appears after the configured pause |
| Press Tab | Accept the next word; normal Tab passes through without a valid suggestion |
| Press Shift–Tab | Accept the full valid suggestion |
| Press Esc | Dismiss the visible suggestion and pause briefly |
| Keep typing or delete text | Cancel the prior suggestion and regenerate against the new state |
| Move the cursor or select text | Never insert a suggestion from the old selection |
| Switch application or window | Hide old suggestions; never insert into the previous field |
| Change language | Follow the current writing, without changing a global language switch |
| Scroll | Dismiss the overlay rather than leave it anchored to stale coordinates |
| Secure field or secure input | No prediction or learning |
| Cotypist running | Suspend external Satz suggestions |
| Undo | The host application should undo accepted Unicode input; confirm per app |
| Source-linked fact | Display source provenance, distinct from an unverified model prediction |

The settings inspection does not establish that all original runtime scenarios were executed. Runtime checks belong in VALIDATION.md with their actual outcome.
