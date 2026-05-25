
# windenntw debian packages

## Usage

To enable a debian machine to use this local package repo:

```
$ cat <<EOF >/etc/apt/sources.list.d/windenntw-debian-packages.list 
deb [trusted=yes] http://windenntw.github.io/debian-packages binaries/
EOF
```

## Maintenance

To regenerate the indexes after modifying the files.

```
./make-indexes.sh
```

