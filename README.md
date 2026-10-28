# Satz

**Precision in every word.** A native, local-first writing companion for Apple Silicon Macs.

Satz suggests continuations beside your cursor. Accept the next word with **Tab**, accept the entire suggestion with **Shift–Tab**, or keep typing. Inference runs on your Mac through llama.cpp and Metal. No account or subscription is required.

> **Status: early development.** A working implementation is not a guarantee of compatibility with every Mac application. See [validation](docs/VALIDATION.md) for measured results and unverified scenarios. Satz is an independent implementation, not affiliated with Cotypist.

## Features

- Native AppKit menu bar app and SwiftUI settings.
- Compact, font-matched inline ghost text using macOS Accessibility, with details behind a small ellipsis.
- Snapshot validation before insertion; stale suggestions are discarded.
- Native Unicode input, without reading or overwriting the clipboard.
- Local Qwen3 models: 4B Q4_K_M for balance, 1.7B Q8_0 for speed.
- Writing in English, Czech and Russian, following the current text.
- Per-application instructions, exclusions and global pause.
- Optional spelling suggestions using installed macOS dictionaries.
- Emoji shortcodes, such as `:smile` and `:rocket`.
- Growing local example memory, relevance-based retrieval and a personal dictionary.
- AES-GCM encrypted local settings, memory and statistics; device-local Keychain key.
- Retention controls and review/deletion of learned examples.
- A source-linked fact library, plus explicit checks against supported official sites.
- Shorter completions or on-demand generation on battery power.

## Requirements

- Apple Silicon Mac, macOS 14 or later; 16 GB RAM recommended.
- Xcode with its command line tools for building and testing.
- Homebrew's `llama.cpp` package for inference.
- About 4.4 GB for both downloaded model files, plus working memory and build storage.
- Accessibility permission for use in other applications. The built-in playground works without it.

## Build and install

```sh
brew install llama.cpp
bash scripts/setup-model.sh
bash scripts/test.sh
bash scripts/build.sh
bash scripts/install.sh
open /Applications/Satz.app
```

The setup script downloads official Qwen weights from Hugging Face, verifies pinned SHA-256 checksums, and stores them outside the repository. It does not download or modify Cotypist data. The app currently discovers a Homebrew-installed `llama-server`; its app bundle does not include that engine or its dependencies.

The local build uses an ad-hoc signature. Public distribution with Developer ID signing and notarization is a separate release step; do not describe a local build as notarized.

## Use

1. Open Satz and use the built-in playground to confirm the local model is ready.
2. Grant Satz Accessibility permission in macOS if you want suggestions in other apps.
3. Quit any competing global autocomplete tool. Satz also suspends external suggestions while Cotypist is running.
4. Type in a supported text field and pause briefly.
5. Press Tab for the next word, Shift–Tab for the whole suggestion, or Esc to dismiss.

Control–Option–Space requests a suggestion. Shortcuts currently use these fixed bindings.

Satz must be able to read the field's value, selection and caret bounds. It declines unsupported fields instead of guessing where to insert text. It avoids secure fields, secure input, selected text, configured excluded apps and recognised private-window titles. Private-window detection is not universal; use app exclusions for confidential work. Terminals and code editors are excluded initially; remove an exclusion only when appropriate for your use.

## Learning

By default Satz learns from the text before the cursor when you accept a suggestion. Optional completed-field learning also records eligible recent fields after an acceptance. It does **not** record raw key events and does **not** train model weights. A local retrieval system favours your examples and vocabulary. This memory can improve familiarity, but cannot guarantee perfect stylistic imitation.

All learning preferences, examples, custom facts, app rules and statistics are stored in `~/Library/Application Support/Satz/personalization.sealed`, encrypted with AES-GCM. The key is a separate, non-synchronising Keychain item. Losing the key means the vault cannot be decrypted; the app refuses to overwrite an unreadable vault.

Review the Personalization page and application exclusions. Sensitive-pattern filtering cannot identify every secret or confidential sentence.

## Facts and sources

Prediction is not verification. Open the small ellipsis beside a suggestion to inspect its origin. Ordinary model output is identified there as **Local AI · unverified**; source URLs are hidden from the default inline view.

The initial offline reference library contains two curated examples: Everest's official elevation and the original MacBook's introduction year. The MacBook entry excludes MacBook Pro and Air. Add your own reference records with topic keywords, attribute keywords, an exact answer and a source URL. A match requires both keyword groups and a trailing colon, dash or equals sign.

The Sources page also imports official HTML pages and text-based PDFs into an encrypted local reference library (up to 50 documents, 250,000 characters each). A local keyword index retrieves passages; the local model extracts an answer, and the app accepts it only if it occurs verbatim in a retrieved passage. Questions and documents are not sent to a remote model. An answer span may still be irrelevant or misleading: inspect its evidence and source. Cross-language retrieval and scanned PDFs are limited.

Recognised factual slots ending in a delimiter use the reference library and withhold an answer when no supporting local reference is available. This recognition is heuristic; arbitrary model prose must still be treated as unverified. The source reader does not crawl the web or perform automatic search.

**Check answer text in source** downloads only that reference URL, with no writing history, cookies or account credentials. It checks whether the answer text occurs in the source; it does not prove entailment, freshness or authority. Read the source before relying on a claim. It is not an autonomous general-purpose web fact checker or a search engine.

Supported check hosts: `apple.com`, `nasa.gov`, `noaa.gov`, `nist.gov`, `usgs.gov`, `tourismdepartment.gov.np`, `dos.gov.np`, `gov.uk`, `europa.eu`, `who.int`, `un.org`, `esa.int`, including subdomains. Checks require HTTPS, disallow credentials/query parameters, reject cross-host redirects and cap response size at 20 MB.

## Privacy and publication

Read [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md). Runtime data, models and backups belong outside the repository. No personal profile is included. The project has no telemetry, cloud inference, automatic browser search, clipboard monitoring or background source refresh.

Run `python3 scripts/audit-public.py` before publishing. The export script packages only tracked, audited source. Never upload your Application Support directory or a backup of another typing application.

Enable the repository's local Git safeguards with `bash scripts/install-hooks.sh`. They audit staged source before a commit and require a clean, audited tree before a push. These checks are helpful but are not a substitute for reviewing what you publish.

```sh
git init -b main
git add .
python3 scripts/audit-public.py
bash scripts/export-public.sh
```

## Architecture

`SatzCore` contains text rules, privacy filters, fact matching, preferences and memory retrieval. `Satz` contains the Accessibility adapter, keyboard hook, suggestion panel, encrypted vault, local model process, source reader and settings UI. An active editing timer samples eligible text fields; a debounce gates inference, and every result is tied to a revision and an exact field snapshot. The model server binds to loopback only and requires a random per-session API token. Server output is discarded, not written to logs.

## License

Satz source is MIT licensed. Qwen model weights and llama.cpp retain their own licences and are not relicensed by this project. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
