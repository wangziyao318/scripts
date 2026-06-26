#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

for cmd in parallel ffmpeg; do
    command -v "${cmd}" >/dev/null || { echo "${cmd} not installed." >&2; exit 1; }
done

f=(*.wav)
if ((${#f[@]})); then
    parallel --unsafe '
        ffmpeg -y -v error -hide_banner -nostdin -i {} -c:a flac {.}.flac
    ' ::: "${f[@]}" && rm -f -- "${f[@]}"
fi
