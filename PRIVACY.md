# Privacy

Satz has no account system, telemetry service or cloud inference endpoint.

## Information used locally

- The eligible focused text field, its selection and caret rectangle.
- The field's application identifier, for exclusions and per-app instructions.
- Recent accepted writing examples, if learning is enabled.
- Optional completed fields after a recent accepted suggestion.
- User-entered vocabulary, app rules, reference facts and instructions.
- Aggregate accepted-word counts, completion counts and inference timing.

The application does not read the clipboard, capture the screen, record raw keys, import another app's database or synchronise the memory to a cloud service.

## Storage

Runtime data stays in the current user's Application Support/Satz directory, outside the source tree. Settings, memory and statistics are encrypted together with AES-GCM. The key is kept in the user's device-local Keychain. Directory permissions are set to owner-only and the vault file to mode 0600. This is protection at rest, not a claim that a compromised user account or administrator cannot access a running app's memory.

## Network activity

Model setup downloads weights from Hugging Face. The local inference process uses only loopback and an ephemeral API token. Checking a source explicitly downloads its public URL from an allowed official host; no typed sentence or learned example is included in the request. Opening a source link invokes the user's browser and its normal privacy settings. No automatic network source lookup occurs while typing.

## Controls and limits

Disable learning, inspect examples, delete individual examples, clear learned examples, set retention or exclude applications in Settings. Password fields and secure input are rejected. Private-window title detection and sensitive-text patterns are safeguards, not complete secret detection. Exclude an application when confidential content must never be processed. Deleting learned examples does not remove a personal dictionary, settings or copies someone made separately.

The macOS permissions database, Keychain and model download are managed outside Git. Do not publish runtime folders, private exports or backups.
