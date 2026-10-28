#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
echo 'Local source-publication checks enabled for commits and pushes.'
