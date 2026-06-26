#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

for cmd in parallel cjxl; do
    command -v "${cmd}" >/dev/null || { echo "${cmd} not installed." >&2; exit 1; }
done

f=(*.jpg *.png)
if ((${#f[@]})); then
    duplicates=$(printf '%s\n' "${f[@]%.*}" | sort | uniq -d)
    [[ -z "${duplicates}" ]] || {
        echo "Skip ${PWD} due to basename collision:" >&2
        while IFS= read -r base; do
            printf '%s %s\n' "${base}".{jpg,png} >&2
        done <<< "${duplicates}"
        exit 0
    }

    parallel --unsafe '
        cjxl --quiet -j 1 {} {.}.jxl
    ' ::: "${f[@]}" && rm -f -- "${f[@]}"
fi
