#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

[ $# -eq 1 ] || { echo "Usage: $0 <command>" >&2; exit 1; }

cmd="$1"
command -v "$cmd" >/dev/null || { echo "$cmd not found." >&2; exit 1; }

for dir in */; do
    [ -d "$dir" ] || continue

    echo "Processing $dir"
    (cd "$dir" && eval "$cmd")
done
