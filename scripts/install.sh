#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test -d dist/Satz.app || { echo 'Run scripts/build.sh first.' >&2; exit 1; }
if pgrep -x Satz >/dev/null; then
  echo 'Quit Satz before installing an update.' >&2
  exit 1
fi
if [ -d /Applications/Satz.app ]; then
  stamp=$(date +%Y%m%d-%H%M%S)
  backup="$HOME/Library/Application Support/Satz/Backups/Satz-$stamp.zip"
  mkdir -p "$(dirname "$backup")"
  ditto -c -k --sequesterRsrc --keepParent /Applications/Satz.app "$backup"
fi
ditto dist/Satz.app /Applications/Satz.app
echo 'Installed /Applications/Satz.app. Cotypist was not modified.'
