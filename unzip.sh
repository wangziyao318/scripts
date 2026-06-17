#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

command -v parallel >/dev/null || { echo 'parallel not installed.' >&2; exit 1; }
command -v 7z >/dev/null || { echo '7z not installed.' >&2; exit 1; }

parallel '
    dir={.}
    if [ -d {.} ]; then
        i=1
        while [ -d {.}_\($i\) ]; do
            i=$((i + 1))
        done
        dir+=_\($i\)
    fi
    7z x -y "-o$dir" {} >/dev/null && rm {}
' ::: *.zip
