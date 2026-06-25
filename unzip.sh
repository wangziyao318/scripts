#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

for cmd in parallel 7z; do
    command -v "${cmd}" >/dev/null || { echo "${cmd} not installed." >&2; exit 1; }
done

parallel --unsafe '
    dir={.}
    if [ -d {.} ]; then
        i=1
        while [ -d {.}_\(${i}\) ]; do
            i=$((i + 1))
        done
        dir+=_\(${i}\)
    fi
    7z x -y "-o${dir}" {} >/dev/null && rm -f -- {}
' ::: *.zip
