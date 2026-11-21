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
REVISION="2"
DEB_VERSION="${VERSION}-${REVISION}"
DEBNAME="google-antigravity-cli_${DEB_VERSION}_amd64.deb"

# 2. Register trap to cleanup.
function cleanup1() {
    rm -rf "${TMPDIR}"
}
trap cleanup1 EXIT

# 3. Stage control file and maintainer scripts for Debian.
DATE=$(LC_ALL=C date -R)
shopt -u patsub_replacement 2>/dev/null || true
render_template() {
    local src="$1"
    local dst="$2"
    local content
    content=$(<"${src}")
    content=${content//@VERSION@/${VERSION}}
    content=${content//@DEB_VERSION@/${DEB_VERSION}}
    content=${content//@UPSTREAM_URL@/${UPSTREAM_URL}}
    content=${content//@SHA512@/${SHA512}}
    content=${content//@BINARY_PATH@/${BINARY_PATH}}
    content=${content//@DATE@/${DATE}}
    printf '%s\n' "${content}" > "${dst}"
}

SRC_DIR="${SCRIPT_DIR}/src/google-antigravity-cli"
mkdir -p "${ROOTDIR}/DEBIAN"
chmod 0755 "${ROOTDIR}/DEBIAN"

render_template "${SRC_DIR}/DEBIAN/control" "${ROOTDIR}/DEBIAN/control"
chmod 0644 "${ROOTDIR}/DEBIAN/control"

render_template "${SRC_DIR}/DEBIAN/postinst" "${ROOTDIR}/DEBIAN/postinst"
chmod 0755 "${ROOTDIR}/DEBIAN/postinst"

render_template "${SRC_DIR}/DEBIAN/postrm" "${ROOTDIR}/DEBIAN/postrm"
chmod 0755 "${ROOTDIR}/DEBIAN/postrm"

# 4. Install desktop entry and icon.
mkdir -p "${ROOTDIR}/usr/share/pixmaps"
cp "${SRC_DIR}/usr/share/pixmaps/google-antigravity-cli.png" "${ROOTDIR}/usr/share/pixmaps/google-antigravity-cli.png"
chmod 0644 "${ROOTDIR}/usr/share/pixmaps/google-antigravity-cli.png"

mkdir -p "${ROOTDIR}/usr/share/applications"
render_template "${SRC_DIR}/usr/share/applications/google-antigravity-cli.desktop" \
    "${ROOTDIR}/usr/share/applications/google-antigravity-cli.desktop"
chmod 0644 "${ROOTDIR}/usr/share/applications/google-antigravity-cli.desktop"

# 5. List files.
find "${ROOTDIR}"

# 6. Make package and show the content.
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"
mkdir -p "${OUTDIR}"
dpkg-deb --root-owner-group --build "${ROOTDIR}" "${OUTDIR}/${DEBNAME}"
dpkg -c "${OUTDIR}/${DEBNAME}"

# 7. Stage and build Debian source package.
SRCDIR="${TMPDIR}/google-antigravity-cli-${VERSION}"
mkdir -p "${SRCDIR}/debian/source" "${SRCDIR}/debian/usr/share/pixmaps" "${SRCDIR}/debian/usr/share/applications"
chmod 0755 "${SRCDIR}" "${SRCDIR}/debian" "${SRCDIR}/debian/source"

render_template "${SRC_DIR}/debian/control" "${SRCDIR}/debian/control"
chmod 0644 "${SRCDIR}/debian/control"

render_template "${SRC_DIR}/debian/changelog" "${SRCDIR}/debian/changelog"
chmod 0644 "${SRCDIR}/debian/changelog"

cp "${SRC_DIR}/debian/source/format" "${SRCDIR}/debian/source/format"
chmod 0644 "${SRCDIR}/debian/source/format"

cp "${SRC_DIR}/debian/source/include-binaries" "${SRCDIR}/debian/source/include-binaries"
chmod 0644 "${SRCDIR}/debian/source/include-binaries"

cp "${SRC_DIR}/debian/rules" "${SRCDIR}/debian/rules"
chmod 0755 "${SRCDIR}/debian/rules"

cp "${SRC_DIR}/debian/install" "${SRCDIR}/debian/install"
chmod 0644 "${SRCDIR}/debian/install"

cp "${ROOTDIR}/DEBIAN/postinst" "${SRCDIR}/debian/postinst"
chmod 0755 "${SRCDIR}/debian/postinst"

cp "${ROOTDIR}/DEBIAN/postrm" "${SRCDIR}/debian/postrm"
chmod 0755 "${SRCDIR}/debian/postrm"

cp "${SRC_DIR}/usr/share/pixmaps/google-antigravity-cli.png" "${SRCDIR}/debian/usr/share/pixmaps/google-antigravity-cli.png"
chmod 0644 "${SRCDIR}/debian/usr/share/pixmaps/google-antigravity-cli.png"

cp "${ROOTDIR}/usr/share/applications/google-antigravity-cli.desktop" "${SRCDIR}/debian/usr/share/applications/google-antigravity-cli.desktop"
chmod 0644 "${SRCDIR}/debian/usr/share/applications/google-antigravity-cli.desktop"

SOURCE_OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/source"
mkdir -p "${SOURCE_OUTDIR}"
tar -cJf "${TMPDIR}/google-antigravity-cli_${VERSION}.orig.tar.xz" --files-from /dev/null
(cd "${TMPDIR}" && dpkg-source -b "google-antigravity-cli-${VERSION}")
mv "${TMPDIR}/google-antigravity-cli_${DEB_VERSION}.dsc" \
   "${TMPDIR}/google-antigravity-cli_${DEB_VERSION}.debian.tar.xz" \
   "${TMPDIR}/google-antigravity-cli_${VERSION}.orig.tar.xz" \
   "${SOURCE_OUTDIR}/"
