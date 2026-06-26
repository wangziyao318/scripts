#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

((${#})) || { echo "Usage: $(basename "${0}") <command> [args...]" >&2; exit 1; }
command -v "${1}" >/dev/null || { echo "Not a command: ${1}." >&2; exit 1; }

dirs=(*/)
n=${#dirs[@]}
((n)) || exit 0

i=0
for dir in "${dirs[@]}"; do
    [ -d "${dir}" ] || continue

    ((++i))
    width=$((${COLUMNS:-80} - 7))
    bar=$(printf '%*s' $((i * width / n)) '')
    printf '\r[%-*s] %3d%%' "${width}" "${bar// /#}" "$((i * 100 / n))"

    (cd "${dir}" && eval "${@}")
done
echo
