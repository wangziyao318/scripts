#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

((${#} == 1)) || { echo "Usage: $(basename "${0}") <file.zip>" >&2; exit 1; }

for cmd in file unzip imv; do
    command -v "${cmd}" >/dev/null || { echo "${cmd} not installed." >&2; exit 1; }
done

ZIP_FILE="${1}"
[[ $(file -b --mime-type "${ZIP_FILE}") == 'application/zip' ]] ||
    { echo "Not a zip file: ${ZIP_FILE}." >&2; exit 1; }

IMV_ZIP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/imv-zip.XXXXXX")
trap 'rm -rf "${IMV_ZIP_DIR}"' EXIT

unzip -qq -o -j "${ZIP_FILE}" -d "${IMV_ZIP_DIR}" && imv "${IMV_ZIP_DIR}"
