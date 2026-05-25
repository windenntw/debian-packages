
# windenntw debian packages

## Usage

To enable a debian machine to use this local package repo:

```bash
cat <<EOF >/etc/apt/sources.list.d/windenntw-debian-packages.list 
deb     [trusted=yes] https://windenntw.github.io/debian-packages binaries/
deb-src [trusted=yes] https://windenntw.github.io/debian-packages source/
EOF
```

## Maintenance

To regenerate the indexes after modifying the files.

```
./make-indexes.sh
```

