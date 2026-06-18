#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

for cmd in parallel cjxl; do
    command -v "$cmd" >/dev/null || { echo "$cmd not installed." >&2; exit 1; }
done

parallel --bar 'cjxl --lossless_jpeg=1 {} {.}.jxl 2>/dev/null' ::: *.jpg && rm -f *.jpg
