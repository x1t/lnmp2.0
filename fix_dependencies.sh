#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_DIR="${SCRIPT_DIR}/src"

if [ ! -d "${SRC_DIR}" ]; then
    echo "Error: source directory not found: ${SRC_DIR}" >&2
    exit 1
fi

echo "=== LNMP source cache cleanup ==="
echo "Only incomplete download artifacts (*.part, *.tmp) will be removed."

find "${SRC_DIR}" -maxdepth 1 -type f \( -name '*.part' -o -name '*.tmp' \) -print -delete

if [ -x "${SCRIPT_DIR}/include/version_compare" ]; then
    echo "version_compare is executable."
else
    chmod 0755 "${SCRIPT_DIR}/include/version_compare"
    echo "Fixed permissions: include/version_compare"
fi

echo "Cleanup complete. The installer will use the HTTPS allowlist and SHA256 manifest in checksums.sha256."
echo "Run: ${SCRIPT_DIR}/install.sh lnmp"
