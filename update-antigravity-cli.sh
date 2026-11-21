#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -x

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json"

parse_json_key() {
    local payload="$1"
    local key="$2"
    echo "$payload" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

MANIFEST_JSON=$(curl -fsSL "${MANIFEST_URL}")
VERSION=$(parse_json_key "${MANIFEST_JSON}" "version")
UPSTREAM_URL=$(parse_json_key "${MANIFEST_JSON}" "url")
SHA512=$(parse_json_key "${MANIFEST_JSON}" "sha512")

if [ -z "${VERSION}" ] || [ -z "${UPSTREAM_URL}" ] || [ -z "${SHA512}" ]; then
    echo "Failed to parse release manifest from ${MANIFEST_URL}" >&2
    exit 1
fi

# 1. Make temp staging directory.
TMPDIR=$(mktemp -d)
ROOTDIR="${TMPDIR}/root"
BINARY_PATH="/usr/bin/agy"
DEBNAME="google-antigravity-cli_${VERSION}_amd64.deb"

# 2. Register trap to cleanup.
function cleanup1() {
    rm -rf "${TMPDIR}"
}
trap cleanup1 EXIT

# 3. Create control file and maintainer scripts for Debian.
mkdir -p "${ROOTDIR}/DEBIAN"
chmod 0755 "${ROOTDIR}/DEBIAN"
cat <<EOF > "${ROOTDIR}/DEBIAN/control"
Package: google-antigravity-cli
Version: ${VERSION}
Architecture: amd64
Maintainer: windenntw <windenntw@gmail.com>
Depends: curl, ca-certificates
Description: Antigravity CLI from Google (installer).
 Downloads and installs Antigravity CLI (agy) from Google during package installation.
EOF
chmod 0644 "${ROOTDIR}/DEBIAN/control"

cat <<EOF > "${ROOTDIR}/DEBIAN/postinst"
#!/bin/sh
set -e

case "\$1" in
    configure)
        TMPDIR=\$(mktemp -d)
        trap 'rm -rf "\$TMPDIR"' EXIT

        echo "Downloading Antigravity CLI ${VERSION}..."
        PAYLOAD="\${TMPDIR}/payload"
        curl -fSL "${UPSTREAM_URL}" -o "\${PAYLOAD}"

        ACTUAL_HASH=\$(sha512sum "\${PAYLOAD}" | cut -d' ' -f1)
        if [ "\${ACTUAL_HASH}" != "${SHA512}" ]; then
            echo "Checksum verification failed for Antigravity CLI ${VERSION}" >&2
            exit 1
        fi

        case "${UPSTREAM_URL}" in
            *.tar.gz*)
                tar --no-same-owner -xzf "\${PAYLOAD}" -C "\${TMPDIR}" antigravity
                install -d -m 0755 "$(dirname "${BINARY_PATH}")"
                install -m 0755 -o root -g root "\${TMPDIR}/antigravity" "${BINARY_PATH}"
                ;;
            *)
                install -d -m 0755 "$(dirname "${BINARY_PATH}")"
                install -m 0755 -o root -g root "\${PAYLOAD}" "${BINARY_PATH}"
                ;;
        esac
        ;;
esac
EOF
chmod 0755 "${ROOTDIR}/DEBIAN/postinst"

cat <<EOF > "${ROOTDIR}/DEBIAN/postrm"
#!/bin/sh
set -e

case "\$1" in
    remove|purge|upgrade)
        rm -f "${BINARY_PATH}"
        ;;
esac
EOF
chmod 0755 "${ROOTDIR}/DEBIAN/postrm"

# 4. List files.
find "${ROOTDIR}"

# 5. Make package and show the content.
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"
mkdir -p "${OUTDIR}"
dpkg-deb --root-owner-group --build "${ROOTDIR}" "${OUTDIR}/${DEBNAME}"
dpkg -c "${OUTDIR}/${DEBNAME}"
