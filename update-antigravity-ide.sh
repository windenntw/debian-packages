#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -x

UPSTREAM_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.0.4-6381998290370560/linux-x64/Antigravity%20IDE.tar.gz"
VERSION="2.0.4"

# 1. Make temp directory and target directory inside.
TMPDIR=$(mktemp -d)
ROOTDIR="${TMPDIR}/root"
TARGETDIR="${ROOTDIR}/opt/Antigravity-IDE-${VERSION}-linux-amd64"
DEBNAME="google-antigravity-ide_${VERSION}_amd64.deb"

# 2. Register trap to cleanup

function cleanup1() {
    rm -rf "${TMPDIR}"
}
trap cleanup1 EXIT

# 3. Download using CURL into temp directory with fixed name.
curl -L "${UPSTREAM_URL}" -o "${TMPDIR}/antigravity-ide-linux-amd64.tar.gz"

# 4. Unpack
tar -xf "${TMPDIR}/antigravity-ide-linux-amd64.tar.gz" -C "${TMPDIR}"

# 5. List files
find "${TMPDIR}"

# 6. Move unpacked to target dir.
mkdir -p "${TARGETDIR}"
mv "${TMPDIR}/Antigravity IDE" "${TARGETDIR}"

# 7. Create new control file for debian.
mkdir -p "${ROOTDIR}/DEBIAN"
cat <<EOF > ${ROOTDIR}/DEBIAN/control
Package: google-antigravity-ide
Version: ${VERSION}
Architecture: amd64
Maintainer: windenntw <windenntw@gmail.com>
Description: Antigravity IDE from Google.
EOF

# 8. Create the desktop entry.
mkdir -p "${ROOTDIR}/usr/share/applications"
cat <<EOF > "${ROOTDIR}/usr/share/applications/google-antigravity-ide.desktop"
[Desktop Entry]
Name=Antigravity IDE
Comment=Experience liftoff
GenericName=Text Editor
Exec="/opt/Antigravity-IDE-${VERSION}-linux-amd64/Antigravity IDE/bin/antigravity-ide" "%F"
Icon=/opt/Antigravity-IDE-${VERSION}-linux-amd64/Antigravity IDE/resources/app/resources/linux/code.png
Type=Application
StartupNotify=false
StartupWMClass=Antigravity IDE
Categories=TextEditor;Development;IDE;
Terminal=False
MimeType=application/x-antigravity-workspace;
EOF

# 9. List files.
find "${ROOTDIR}"

# 9. Make package and show the content.
dpkg-deb --root-owner-group --build "${ROOTDIR}" "/tmp/${DEBNAME}"
dpkg -c "/tmp/${DEBNAME}"
