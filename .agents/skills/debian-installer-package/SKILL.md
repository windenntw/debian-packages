---
name: debian-installer-package
description: >-
  Use this skill when creating a new Debian installer package (or updating an
  existing one) in this repository from an upstream tarball URL, release
  manifest, or `curl | bash` install script.
---

# Creating a Debian Installer Package

Turn an upstream tarball URL, release JSON manifest, or `curl | bash`
installer into a reproducible Debian binary (`.deb`) and `3.0 (quilt)` source
package (`.dsc`, `.debian.tar.xz`, `.orig.tar.xz`) in `dists/windenntw/windenntw/`.

## 1. Inspect the Upstream Installer / Tarball

1. Read the `curl | bash` script or release manifest to extract:
   - Version discovery URL or static `VERSION` + `UPSTREAM_URL`
   - Checksum (`sha512` / `sha256`, if provided)
   - Archive layout (single binary vs. directory) and target install path
     (`/usr/bin/<name>` for CLI tools, `/opt/<App>-${VERSION}-linux-amd64` for apps/IDEs)
   - Required runtime dependencies (`curl, ca-certificates`, etc.)
2. Set `REVISION="1"` and `DEB_VERSION="${VERSION}-${REVISION}"` in `update-<pkg>.sh`.

## 2. Create `src/<pkg>/` Templates

Mirror the target layout cleanly under `src/<pkg>/`:

```text
src/<pkg>/
├── DEBIAN/
│   ├── control       # Version: @DEB_VERSION@, Depends: curl, ca-certificates
│   ├── postinst      # 0755: download, verify checksum, unpack with --no-same-owner
│   └── postrm        # 0755: remove installed files on remove|purge|upgrade
├── debian/
│   ├── source/
│   │   ├── format            # 3.0 (quilt)
│   │   └── include-binaries  # debian/usr/share/pixmaps/<pkg>.png
│   ├── control       # Section: devel, Build-Depends: debhelper-compat (= 13), Rules-Requires-Root: no
│   ├── changelog     # <pkg> (@DEB_VERSION@) windenntw; urgency=medium
│   ├── install       # debian/usr/share/applications/<pkg>.desktop usr/share/applications
│   │                 # debian/usr/share/pixmaps/<pkg>.png usr/share/pixmaps
│   └── rules         # 0755, mandatory `dh $@`
└── usr/share/
    ├── applications/<pkg>.desktop
    └── pixmaps/<pkg>.png     # 1024x1024 RGBA PNG
```

### Rules & Gotchas
- **Placeholders**: Use `@VERSION@` (upstream version), `@DEB_VERSION@`
  (`${VERSION}-${REVISION}`), `@UPSTREAM_URL@`, `@SHA512@`, `@INSTALLDIR@` /
  `@BINARY_PATH@`, and `@DATE@` (`LC_ALL=C date -R`).
- **Template rendering**: In `update-<pkg>.sh`, disable `patsub_replacement`
  (`shopt -u patsub_replacement 2>/dev/null || true`) before `${content//@KEY@/${VAL}}`
  so `&` in URLs is not expanded. Keep runtime variables (`$1`, `${TMPDIR}`)
  unescaped in `postinst`/`postrm`.
- **`.desktop` entry**:
  - GUI apps/IDEs: `Terminal=False`, `Categories=Development;Utility;`
  - CLI tools: `Terminal=true`, `Categories=Development;Utility;ConsoleOnly;`
- **Source format `3.0 (quilt)`**:
  - `3.0 (native)` rejects `-<revision>` versions. Use `3.0 (quilt)` with an
    empty orig tarball: `tar -cJf "<pkg>_${VERSION}.orig.tar.xz" --files-from /dev/null`.
  - Stage `.desktop` and `.png` under `${SRCDIR}/debian/usr/share/...` in the
    source tree and list `debian/usr/share/pixmaps/<pkg>.png` in
    `debian/source/include-binaries`.
- **Mandatory `dh` (`debhelper`)**:
  - `debian/control` must include `Build-Depends: debhelper-compat (= 13)`.
  - `debian/rules` must use `dh`:
    ```makefile
    #!/usr/bin/make -f
    %:
    	dh $@
    ```
  - Use `debian/install` (or `debian/<pkg>.install`) to install `.desktop` and
    `.png` into `usr/share/applications` and `usr/share/pixmaps`.
  - Ensure `debhelper` is installed (`command -v dh`) before building.

## 3. Verify & Publish

1. Run `./update-<pkg>.sh` and check exit code `0`.
2. Inspect the `.deb`:
   - `dpkg -c dists/windenntw/windenntw/binary-amd64/<pkg>_<deb_version>_amd64.deb`
   - `dpkg-deb -e` to a temp dir: verify `0644` `control`, `0755` `postinst`/`postrm`,
     and zero leftover `@...@` placeholders.
3. Verify the source package rebuilds in a temp dir:
   ```bash
   T=$(mktemp -d)
   dpkg-source -x dists/windenntw/windenntw/source/<pkg>_<deb_version>.dsc "$T/src"
   (cd "$T/src" && dpkg-buildpackage -b -us -uc)
   rm -rf "$T"
   ```
4. Regenerate APT indexes with `./make-indexes.sh` and commit piecemeal
   (`src/<pkg>/` + `update-<pkg>.sh`, `dists/` packages, then `dists/` indexes).
