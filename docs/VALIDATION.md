# Validation

This file records the current evidence, not a compatibility promise.

## Automated

Twelve core checks passed locally. They cover bounded native Unicode payloads, Unicode word acceptance, hidden reasoning removal, maximum word counts, sensitive-pattern filtering, relevant memory retrieval, reference matching, URL rejection, emoji parsing, app exclusions, data serialization, older-vault migration, grounded answer validation and HTML script removal. Run `bash scripts/test.sh` for the current result.

## Local model

Qwen3-1.7B Q8_0 and Qwen3-4B Q4_K_M were downloaded from official Qwen repositories and SHA-256 checked. Synthetic English, Russian and Czech requests ran through llama.cpp and Metal on an M4 Mac with 16 GB RAM. The first 1.7B Czech output was weak. Qwen3 4B was selected as the balanced default after prompt comparisons. Small warm synthetic requests took roughly 0.3–0.9 seconds depending on prompt and language. These measurements do not include the typing debounce and are not a latency guarantee.

## Native app

The release app was built, ad-hoc signed, verified, installed and launched. Accessibility was granted through macOS with the owner's authentication. A source-linked height completion was accepted into a TextEdit document using Tab; the resulting field text and accepted-word counter were observed. A learned example persisted across restarts. The default overlay was then changed to small, font-matched inline ghost text, with provenance hidden behind an ellipsis popover; its appearance was accepted in a local usability check.

A local Safari textarea was recognised as eligible, including caret bounds. An ordinary Tab without a valid visible suggestion moved focus normally, and the password field activated the secure-input exclusion. Full Safari completion acceptance remains unverified by this automated session.

The Sources UI downloaded an official Apple announcement into encrypted local storage. The local model extracted the original MacBook introduction year, 2006, with a supporting source passage. This is an integration check of download, indexing, extraction and presentation, not a general factual-accuracy benchmark.

The vault was present with mode 0600; a known test phrase was absent from plaintext bytes. Original Cotypist data was retained separately. These checks do not constitute a comprehensive security audit.

Undo grouping, Notes insertion, multiple displays, full-screen behaviour, long-duration battery use, screen-reader behaviour and broad application compatibility still require dedicated validation. No parity claim is made for these scenarios.

## Privacy boundary

The local source audit checks tracked files for runtime extensions, large files, common token patterns, home-directory paths, email addresses, symlinks and non-English Cyrillic content. It is a safeguard, not a complete data-loss prevention system. Private runtime checks and backup manifests are kept outside this repository.
