#!/bin/bash
set -euo pipefail
umask 077
model_dir="$HOME/Library/Application Support/Satz/Models"
mkdir -p "$model_dir"
target="$model_dir/Qwen3-1.7B-Q8_0.gguf"
expected=061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a
if [ -f "$target" ] && [ "$(shasum -a 256 "$target" | cut -d ' ' -f 1)" = "$expected" ]; then
  echo 'Model is already verified.'
else
curl --fail --location --retry 3 --continue-at - \
  'https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q8_0.gguf' \
  --output "$target.partial"
actual=$(shasum -a 256 "$target.partial" | cut -d ' ' -f 1)
if [ "$actual" != "$expected" ]; then
  echo 'Checksum mismatch. The partial file was preserved for inspection.' >&2
  exit 1
fi
mv "$target.partial" "$target"
chmod 600 "$target"
echo 'Official Qwen3 model downloaded and SHA-256 verified.'
fi
balanced="$model_dir/Qwen3-4B-Q4_K_M.gguf"
balanced_sha=7485fe6f11af29433bc51cab58009521f205840f5b4ae3a32fa7f92e8534fdf5
if [ -f "$balanced" ] && [ "$(shasum -a 256 "$balanced" | cut -d ' ' -f 1)" = "$balanced_sha" ]; then
  echo 'Balanced model is already verified.'
  exit 0
fi
curl --fail --location --retry 3 --continue-at - \
  'https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf' \
  --output "$balanced.partial"
actual=$(shasum -a 256 "$balanced.partial" | cut -d ' ' -f 1)
[ "$actual" = "$balanced_sha" ] || { echo 'Balanced model checksum mismatch.' >&2; exit 1; }
mv "$balanced.partial" "$balanced"
chmod 600 "$balanced"
echo 'Balanced Qwen3 4B model downloaded and SHA-256 verified.'
