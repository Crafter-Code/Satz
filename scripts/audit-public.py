#!/usr/bin/env python3
"""Fail closed on likely private files or identity in the tracked publication set."""
import pathlib
import re
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
listed = subprocess.check_output(["git", "ls-files", "-z"], cwd=root).split(b"\0")
paths = [root / name.decode() for name in listed if name]
if not paths:
    sys.exit("No tracked files. Stage the intended source before auditing.")
errors = []
patterns = [
    re.compile(rb"/" + rb"Users/[^/\s]+/"),
    re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9]{25,})"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(rb"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.I),
]
for path in paths:
    relative = path.relative_to(root)
    if path.is_symlink():
        errors.append(f"Symlink is not allowed: {relative}")
        continue
    if path.suffix.lower() in {".gguf", ".sealed", ".db", ".sqlite", ".sqlite3", ".log", ".p12", ".key"}:
        errors.append(f"Private/runtime extension: {relative}")
    if any(part in {".private", ".local-state", "private", "backups", "Models", "Application Support"} for part in relative.parts):
        errors.append(f"Private/runtime directory: {relative}")
    # Audit the staged bytes, not a possibly different working-tree version.
    blob = subprocess.check_output(["git", "show", ":" + relative.as_posix()], cwd=root)
    if len(blob) > 2_000_000:
        errors.append(f"Unexpectedly large source file: {relative}")
    for pattern in patterns:
        matches = pattern.findall(blob)
        # RFC-reserved example addresses are deliberate negative-test fixtures.
        matches = [value for value in matches if not value.lower().endswith(b"@example.com")]
        if matches:
            errors.append(f"Potential secret or personal identity in {relative}")
    if re.search("[\u0400-\u052f]", blob.decode("utf-8", errors="ignore")):
        errors.append(f"Non-English Cyrillic content: {relative}")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"Public-source audit passed: {len(paths)} tracked files. Manual review is still required.")
