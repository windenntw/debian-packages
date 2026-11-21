#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -x

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
UPSTREAM_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.34.0-5887025308631040/linux-x64/Antigravity.tar.gz"
VERSION="2.34.0"

# 1. Make temp staging directory.
TMPDIR=$(mktemp -d)
ROOTDIR="${TMPDIR}/root"
INSTALLDIR="/opt/Antigravity-App-${VERSION}-linux-amd64"
DEBNAME="google-antigravity-app_${VERSION}_amd64.deb"

# 2. Register trap to cleanup
function cleanup1() {
    rm -rf "${TMPDIR}"
}
trap cleanup1 EXIT

# 3. Create control file and maintainer scripts for Debian.
mkdir -p "${ROOTDIR}/DEBIAN"
chmod 0755 "${ROOTDIR}/DEBIAN"
cat <<EOF > "${ROOTDIR}/DEBIAN/control"
Package: google-antigravity-app
Version: ${VERSION}
Architecture: amd64
Maintainer: windenntw <windenntw@gmail.com>
Depends: curl, ca-certificates
Description: Antigravity App from Google (installer).
 Downloads and installs Antigravity App from Google during package installation.
EOF
chmod 0644 "${ROOTDIR}/DEBIAN/control"

cat <<EOF > "${ROOTDIR}/DEBIAN/postinst"
#!/bin/sh
set -e

case "\$1" in
    configure)
        TMPDIR=\$(mktemp -d)
        trap 'rm -rf "\$TMPDIR"' EXIT

        echo "Downloading Antigravity App ${VERSION}..."
        curl -fSL "${UPSTREAM_URL}" -o "\${TMPDIR}/antigravity-linux-amd64.tar.gz"

        mkdir -p "\${TMPDIR}/unpack"
        tar --no-same-owner -xf "\${TMPDIR}/antigravity-linux-amd64.tar.gz" -C "\${TMPDIR}/unpack"

        rm -rf "${INSTALLDIR}"
        if [ -x "\${TMPDIR}/unpack/antigravity" ]; then
            mv "\${TMPDIR}/unpack" "${INSTALLDIR}"
        else
            set -- "\${TMPDIR}/unpack"/*
            if [ "\$#" -eq 1 ] && [ -d "\$1" ]; then
                mv "\$1" "${INSTALLDIR}"
            else
                mv "\${TMPDIR}/unpack" "${INSTALLDIR}"
            fi
        fi
        ;;
esac
EOF
chmod 0755 "${ROOTDIR}/DEBIAN/postinst"

cat <<EOF > "${ROOTDIR}/DEBIAN/postrm"
#!/bin/sh
set -e

case "\$1" in
    remove|purge|upgrade)
        rm -rf "${INSTALLDIR}"
        ;;
esac
EOF
chmod 0755 "${ROOTDIR}/DEBIAN/postrm"

# 4. Create the desktop entry and install the icon.
mkdir -p "${ROOTDIR}/usr/share/pixmaps"
cp "${SCRIPT_DIR}/icons/google-antigravity-app.png" "${ROOTDIR}/usr/share/pixmaps/google-antigravity-app.png"
chmod 0644 "${ROOTDIR}/usr/share/pixmaps/google-antigravity-app.png"

mkdir -p "${ROOTDIR}/usr/share/applications"
cat <<EOF > "${ROOTDIR}/usr/share/applications/google-antigravity-app.desktop"
[Desktop Entry]
Name=Antigravity App
Comment=Experience liftoff
Exec="${INSTALLDIR}/antigravity" "%F"
Icon=/usr/share/pixmaps/google-antigravity-app.png
Type=Application
StartupNotify=false
StartupWMClass=Antigravity
Categories=Development;Utility;
Terminal=False
EOF
chmod 0644 "${ROOTDIR}/usr/share/applications/google-antigravity-app.desktop"

# 5. List files.
find "${ROOTDIR}"

# 6. Make package and show the content.
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"
mkdir -p "${OUTDIR}"
dpkg-deb --root-owner-group --build "${ROOTDIR}" "${OUTDIR}/${DEBNAME}"
dpkg -c "${OUTDIR}/${DEBNAME}"
