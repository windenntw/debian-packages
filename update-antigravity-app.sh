#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -x

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
UPSTREAM_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.34.0-5887025308631040/linux-x64/Antigravity.tar.gz"
VERSION="2.34.0"
REVISION="2"
DEB_VERSION="${VERSION}-${REVISION}"
DATE=$(LC_ALL=C date -R)

# 1. Make temp staging directory.
TMPDIR=$(mktemp -d)
ROOTDIR="${TMPDIR}/root"
PKG_SRC_DIR="${TMPDIR}/google-antigravity-app-${VERSION}"
INSTALLDIR="/opt/Antigravity-App-${VERSION}-linux-amd64"
DEBNAME="google-antigravity-app_${DEB_VERSION}_amd64.deb"

# 2. Register trap to cleanup.
function cleanup1() {
    rm -rf "${TMPDIR}"
}
trap cleanup1 EXIT

# 3. Stage control file and maintainer scripts for Debian.
shopt -u patsub_replacement 2>/dev/null || true
render_template() {
    local src="$1"
    local dst="$2"
    local content
    content=$(<"${src}")
    content=${content//@VERSION@/${VERSION}}
    content=${content//@DEB_VERSION@/${DEB_VERSION}}
    content=${content//@UPSTREAM_URL@/${UPSTREAM_URL}}
    content=${content//@INSTALLDIR@/${INSTALLDIR}}
    content=${content//@DATE@/${DATE}}
    printf '%s\n' "${content}" > "${dst}"
}

SRC_DIR="${SCRIPT_DIR}/src/google-antigravity-app"
mkdir -p "${ROOTDIR}/DEBIAN"
chmod 0755 "${ROOTDIR}/DEBIAN"

render_template "${SRC_DIR}/DEBIAN/control" "${ROOTDIR}/DEBIAN/control"
chmod 0644 "${ROOTDIR}/DEBIAN/control"

render_template "${SRC_DIR}/DEBIAN/postinst" "${ROOTDIR}/DEBIAN/postinst"
chmod 0755 "${ROOTDIR}/DEBIAN/postinst"

render_template "${SRC_DIR}/DEBIAN/postrm" "${ROOTDIR}/DEBIAN/postrm"
chmod 0755 "${ROOTDIR}/DEBIAN/postrm"

# 4. Stage the desktop entry and icon.
mkdir -p "${ROOTDIR}/usr/share/pixmaps"
cp "${SRC_DIR}/usr/share/pixmaps/google-antigravity-app.png" "${ROOTDIR}/usr/share/pixmaps/google-antigravity-app.png"
chmod 0644 "${ROOTDIR}/usr/share/pixmaps/google-antigravity-app.png"

mkdir -p "${ROOTDIR}/usr/share/applications"
render_template "${SRC_DIR}/usr/share/applications/google-antigravity-app.desktop" \
    "${ROOTDIR}/usr/share/applications/google-antigravity-app.desktop"
chmod 0644 "${ROOTDIR}/usr/share/applications/google-antigravity-app.desktop"

# 5. List files.
find "${ROOTDIR}"

# 6. Make binary package and show the content.
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"
mkdir -p "${OUTDIR}"
dpkg-deb --root-owner-group --build "${ROOTDIR}" "${OUTDIR}/${DEBNAME}"
dpkg -c "${OUTDIR}/${DEBNAME}"

# 7. Stage and build Debian source package.
mkdir -p "${PKG_SRC_DIR}/debian/source" \
         "${PKG_SRC_DIR}/debian/usr/share/pixmaps" \
         "${PKG_SRC_DIR}/debian/usr/share/applications"

cp "${SRC_DIR}/debian/source/format" "${PKG_SRC_DIR}/debian/source/format"
chmod 0644 "${PKG_SRC_DIR}/debian/source/format"

cp "${SRC_DIR}/debian/source/include-binaries" "${PKG_SRC_DIR}/debian/source/include-binaries"
chmod 0644 "${PKG_SRC_DIR}/debian/source/include-binaries"

cp "${SRC_DIR}/debian/control" "${PKG_SRC_DIR}/debian/control"
chmod 0644 "${PKG_SRC_DIR}/debian/control"

render_template "${SRC_DIR}/debian/changelog" "${PKG_SRC_DIR}/debian/changelog"
chmod 0644 "${PKG_SRC_DIR}/debian/changelog"

cp "${SRC_DIR}/debian/rules" "${PKG_SRC_DIR}/debian/rules"
chmod 0755 "${PKG_SRC_DIR}/debian/rules"

cp "${SRC_DIR}/debian/install" "${PKG_SRC_DIR}/debian/install"
chmod 0644 "${PKG_SRC_DIR}/debian/install"

render_template "${SRC_DIR}/DEBIAN/postinst" "${PKG_SRC_DIR}/debian/postinst"
chmod 0755 "${PKG_SRC_DIR}/debian/postinst"

render_template "${SRC_DIR}/DEBIAN/postrm" "${PKG_SRC_DIR}/debian/postrm"
chmod 0755 "${PKG_SRC_DIR}/debian/postrm"

cp "${SRC_DIR}/usr/share/pixmaps/google-antigravity-app.png" "${PKG_SRC_DIR}/debian/usr/share/pixmaps/google-antigravity-app.png"
chmod 0644 "${PKG_SRC_DIR}/debian/usr/share/pixmaps/google-antigravity-app.png"

render_template "${SRC_DIR}/usr/share/applications/google-antigravity-app.desktop" \
    "${PKG_SRC_DIR}/debian/usr/share/applications/google-antigravity-app.desktop"
chmod 0644 "${PKG_SRC_DIR}/debian/usr/share/applications/google-antigravity-app.desktop"

SRC_OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/source"
mkdir -p "${SRC_OUTDIR}"
tar -cJf "${TMPDIR}/google-antigravity-app_${VERSION}.orig.tar.xz" --files-from /dev/null
(cd "${TMPDIR}" && dpkg-source -b "google-antigravity-app-${VERSION}")
mv "${TMPDIR}/google-antigravity-app_${DEB_VERSION}.dsc" \
   "${TMPDIR}/google-antigravity-app_${DEB_VERSION}.debian.tar.xz" \
   "${TMPDIR}/google-antigravity-app_${VERSION}.orig.tar.xz" \
   "${SRC_OUTDIR}/"
