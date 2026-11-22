#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -x

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
RELEASE_API_URL="https://api.github.com/repos/ollama/ollama/releases/latest"

RELEASE_JSON=$(curl -fsSL "${RELEASE_API_URL}")
eval "$(python3 -c '
import json, shlex, sys
data = json.load(sys.stdin)
tag = data.get("tag_name", "")
version = tag.lstrip("v")
assets = {a["name"]: a for a in data.get("assets", [])}
amd64 = assets.get("ollama-linux-amd64.tar.zst", {})
rocm = assets.get("ollama-linux-amd64-rocm.tar.zst", {})
def sha256(a):
    d = a.get("digest", "")
    return d.split(":", 1)[1] if d.startswith("sha256:") else d
for k, v in [
    ("VERSION", version),
    ("UPSTREAM_URL", amd64.get("browser_download_url", "")),
    ("SHA256", sha256(amd64)),
    ("ROCM_URL", rocm.get("browser_download_url", "")),
    ("ROCM_SHA256", sha256(rocm)),
]:
    print(f"{k}={shlex.quote(v)}")
' <<< "${RELEASE_JSON}")"

if [ -z "${VERSION}" ] || [ -z "${UPSTREAM_URL}" ] || [ -z "${SHA256}" ]; then
    echo "Failed to parse release metadata from ${RELEASE_API_URL}" >&2
    exit 1
fi

# 1. Make temp staging directory.
TMPDIR=$(mktemp -d)
ROOTDIR="${TMPDIR}/root"
BINARY_PATH="/usr/bin/ollama"
REVISION="1"
DEB_VERSION="${VERSION}-${REVISION}"
DEBNAME="ollama_${DEB_VERSION}_amd64.deb"

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
    content=${content//@SHA256@/${SHA256}}
    content=${content//@ROCM_URL@/${ROCM_URL}}
    content=${content//@ROCM_SHA256@/${ROCM_SHA256}}
    content=${content//@BINARY_PATH@/${BINARY_PATH}}
    content=${content//@DATE@/${DATE}}
    printf '%s\n' "${content}" > "${dst}"
}

SRC_DIR="${SCRIPT_DIR}/src/ollama"
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
cp "${SRC_DIR}/usr/share/pixmaps/ollama.png" "${ROOTDIR}/usr/share/pixmaps/ollama.png"
chmod 0644 "${ROOTDIR}/usr/share/pixmaps/ollama.png"

mkdir -p "${ROOTDIR}/usr/share/applications"
render_template "${SRC_DIR}/usr/share/applications/ollama.desktop" \
    "${ROOTDIR}/usr/share/applications/ollama.desktop"
chmod 0644 "${ROOTDIR}/usr/share/applications/ollama.desktop"

# 5. List files.
find "${ROOTDIR}"

# 6. Make package and show the content.
OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/binary-amd64"
mkdir -p "${OUTDIR}"
dpkg-deb --root-owner-group --build "${ROOTDIR}" "${OUTDIR}/${DEBNAME}"
dpkg -c "${OUTDIR}/${DEBNAME}"

# 7. Stage and build Debian source package.
SRCDIR="${TMPDIR}/ollama-${VERSION}"
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

cp "${SRC_DIR}/usr/share/pixmaps/ollama.png" "${SRCDIR}/debian/usr/share/pixmaps/ollama.png"
chmod 0644 "${SRCDIR}/debian/usr/share/pixmaps/ollama.png"

cp "${ROOTDIR}/usr/share/applications/ollama.desktop" "${SRCDIR}/debian/usr/share/applications/ollama.desktop"
chmod 0644 "${SRCDIR}/debian/usr/share/applications/ollama.desktop"

SOURCE_OUTDIR="${SCRIPT_DIR}/dists/windenntw/windenntw/source"
mkdir -p "${SOURCE_OUTDIR}"
tar -cJf "${TMPDIR}/ollama_${VERSION}.orig.tar.xz" --files-from /dev/null
(cd "${TMPDIR}" && dpkg-source -b "ollama-${VERSION}")
mv "${TMPDIR}/ollama_${DEB_VERSION}.dsc" \
   "${TMPDIR}/ollama_${DEB_VERSION}.debian.tar.xz" \
   "${TMPDIR}/ollama_${VERSION}.orig.tar.xz" \
   "${SOURCE_OUTDIR}/"
