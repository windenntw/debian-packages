#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -x

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
UPSTREAM_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.8.0-6733682917113856/linux-x64/Antigravity%20IDE.tar.gz"
VERSION="2.8.0"
DATE=$(LC_ALL=C date -R)

# 1. Make temp staging directory.
TMPDIR=$(mktemp -d)
ROOTDIR="${TMPDIR}/root"
SRCDIR="${TMPDIR}/src/google-antigravity-ide-${VERSION}"
INSTALLDIR="/opt/Antigravity-IDE-${VERSION}-linux-amd64"
DEBNAME="google-antigravity-ide_${VERSION}_amd64.deb"

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
    content=${content//@UPSTREAM_URL@/${UPSTREAM_URL}}
    content=${content//@INSTALLDIR@/${INSTALLDIR}}
    content=${content//@DATE@/${DATE}}
    printf '%s\n' "${content}" > "${dst}"
}

SRC_DIR="${SCRIPT_DIR}/src/google-antigravity-ide"
mkdir -p "${ROOTDIR}/DEBIAN"
chmod 0755 "${ROOTDIR}/DEBIAN"

render_template "${SRC_DIR}/DEBIAN/control" "${ROOTDIR}/DEBIAN/control"
chmod 0644 "${ROOTDIR}/DEBIAN/control"

render_template "${SRC_DIR}/DEBIAN/postinst" "${ROOTDIR}/DEBIAN/postinst"
chmod 0755 "${ROOTDIR}/DEBIAN/postinst"

render_template "${SRC_DIR}/DEBIAN/postrm" "${ROOTDIR}/DEBIAN/postrm"
chmod 0755 "${ROOTDIR}/DEBIAN/postrm"

# 4. Stage the desktop entry and install the icon.
mkdir -p "${ROOTDIR}/usr/share/pixmaps"
cp "${SCRIPT_DIR}/icons/google-antigravity-ide.png" "${ROOTDIR}/usr/share/pixmaps/google-antigravity-ide.png"
chmod 0644 "${ROOTDIR}/usr/share/pixmaps/google-antigravity-ide.png"

mkdir -p "${ROOTDIR}/usr/share/applications"
render_template "${SRC_DIR}/usr/share/applications/google-antigravity-ide.desktop" "${ROOTDIR}/usr/share/applications/google-antigravity-ide.desktop"
chmod 0644 "${ROOTDIR}/usr/share/applications/google-antigravity-ide.desktop"

# 5. List files.
find "${ROOTDIR}"

# 6. Make binary package and show the content.
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"
mkdir -p "${OUTDIR}"
dpkg-deb --root-owner-group --build "${ROOTDIR}" "${OUTDIR}/${DEBNAME}"
dpkg -c "${OUTDIR}/${DEBNAME}"

# 7. Build native Debian source package.
mkdir -p "${SRCDIR}/debian/source" "${SRCDIR}/usr/share/applications" "${SRCDIR}/usr/share/pixmaps"
cp "${SRC_DIR}/debian/source/format" "${SRCDIR}/debian/source/format"
chmod 0644 "${SRCDIR}/debian/source/format"

render_template "${SRC_DIR}/debian/control" "${SRCDIR}/debian/control"
chmod 0644 "${SRCDIR}/debian/control"

render_template "${SRC_DIR}/debian/changelog" "${SRCDIR}/debian/changelog"
chmod 0644 "${SRCDIR}/debian/changelog"

cp "${SRC_DIR}/debian/rules" "${SRCDIR}/debian/rules"
chmod 0755 "${SRCDIR}/debian/rules"

cp "${ROOTDIR}/DEBIAN/postinst" "${SRCDIR}/debian/postinst"
chmod 0755 "${SRCDIR}/debian/postinst"

cp "${ROOTDIR}/DEBIAN/postrm" "${SRCDIR}/debian/postrm"
chmod 0755 "${SRCDIR}/debian/postrm"

cp "${ROOTDIR}/usr/share/applications/google-antigravity-ide.desktop" "${SRCDIR}/usr/share/applications/google-antigravity-ide.desktop"
chmod 0644 "${SRCDIR}/usr/share/applications/google-antigravity-ide.desktop"

cp "${SCRIPT_DIR}/icons/google-antigravity-ide.png" "${SRCDIR}/usr/share/pixmaps/google-antigravity-ide.png"
chmod 0644 "${SRCDIR}/usr/share/pixmaps/google-antigravity-ide.png"

(cd "${TMPDIR}/src" && dpkg-source -b "google-antigravity-ide-${VERSION}")

SRC_OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/source"
mkdir -p "${SRC_OUTDIR}"
cp "${TMPDIR}/src/google-antigravity-ide_${VERSION}.dsc" "${SRC_OUTDIR}/"
cp "${TMPDIR}/src/google-antigravity-ide_${VERSION}.tar.xz" "${SRC_OUTDIR}/"
