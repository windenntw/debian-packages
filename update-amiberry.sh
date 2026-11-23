#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
API_URL="https://api.github.com/repos/BlitterStudio/amiberry/releases/latest"
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"

RELEASE_JSON=$(curl -fsSL "${API_URL}")
TAG_NAME=$(printf '%s' "${RELEASE_JSON}" | jq -r '.tag_name // empty')
ZIP_URL=$(printf '%s' "${RELEASE_JSON}" | jq -r '.assets[] | select(.name | test("^amiberry-.*-debian-trixie-amd64\\.zip$")) | .browser_download_url' | head -n 1)
SHA256SUMS_URL=$(printf '%s' "${RELEASE_JSON}" | jq -r '.assets[] | select(.name == "SHA256SUMS") | .browser_download_url' | head -n 1)

if [ -z "${ZIP_URL}" ]; then
    echo "Failed to find debian-trixie-amd64.zip asset in latest release (${TAG_NAME:-unknown})" >&2
    exit 1
fi

TMPDIR=$(mktemp -d)
cleanup() {
    rm -rf "${TMPDIR}"
}
trap cleanup EXIT

ZIP_NAME=$(basename "${ZIP_URL}")
echo "Downloading ${ZIP_NAME} (${TAG_NAME})..."
curl -fsSL -o "${TMPDIR}/${ZIP_NAME}" "${ZIP_URL}"

if [ -n "${SHA256SUMS_URL}" ]; then
    curl -fsSL -o "${TMPDIR}/SHA256SUMS" "${SHA256SUMS_URL}"
    EXPECTED_LINE=$(grep -E "[[:space:]](\./)?${ZIP_NAME}$" "${TMPDIR}/SHA256SUMS" || true)
    if [ -n "${EXPECTED_LINE}" ]; then
        EXPECTED_SHA=$(printf '%s' "${EXPECTED_LINE}" | awk '{print $1}')
        echo "${EXPECTED_SHA}  ${TMPDIR}/${ZIP_NAME}" | sha256sum -c -
    fi
fi

mkdir -p "${TMPDIR}/extract"
unzip -q "${TMPDIR}/${ZIP_NAME}" -d "${TMPDIR}/extract"

DEB_PATH=$(find "${TMPDIR}/extract" -type f -name '*_amd64.deb' | head -n 1)
if [ -z "${DEB_PATH}" ]; then
    echo "No *_amd64.deb found inside ${ZIP_NAME}" >&2
    exit 1
fi

DEB_NAME=$(basename "${DEB_PATH}")
mkdir -p "${OUTDIR}"

for existing in "${OUTDIR}"/amiberry_*_amd64.deb; do
    [ -e "${existing}" ] || continue
    if [ "$(basename "${existing}")" != "${DEB_NAME}" ]; then
        rm -f "${existing}"
    fi
done

cp -f "${DEB_PATH}" "${OUTDIR}/${DEB_NAME}"
chmod 0644 "${OUTDIR}/${DEB_NAME}"
dpkg-deb -I "${OUTDIR}/${DEB_NAME}"

(cd "${SCRIPT_DIR}" && ./make-indexes.sh)
