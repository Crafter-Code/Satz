#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/audit-public.py
if [ -n "$(git status --porcelain)" ]; then
  echo 'Commit the audited source before exporting. Working-tree changes are not included.' >&2
  exit 1
fi
mkdir -p dist
git archive --format=zip --prefix=Satz/ --output=dist/Satz-source.zip HEAD
echo 'Exported tracked source only: dist/Satz-source.zip'
