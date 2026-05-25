#!/bin/bash

# Function to generate indexes and Release file for a given directory
generate_repo_info() {
    local dir_name="$1"

    local scan_cmd
    local index_name
    local arch

    if [ "$dir_name" = "binaries" ]; then
        scan_cmd="dpkg-scanpackages"
        index_name="Packages.gz"
        arch="amd64"
    elif [ "$dir_name" = "source" ]; then
        scan_cmd="dpkg-scansources"
        index_name="Sources.gz"
        arch="source"
    else
        echo "Error: Unknown type '$dir_name'" >&2
        return 1
    fi

    echo "Generating index for $dir_name..."

    # 1. Generate only the compressed list
    "$scan_cmd" "$dir_name" /dev/null | gzip -9c > "$dir_name/$index_name"

    # 2. Generate Release file header
    cat <<EOF > "$dir_name/Release"
Origin: windenntw
Label: windenntw
Suite: $dir_name/
Codename: $dir_name/
Architectures: $arch
Date: $(date -Ru)
SHA256:
EOF

    # 3. Append only index hash and size
    (
        cd "$dir_name" || exit 1
        echo " $(sha256sum "$index_name" | cut -d' ' -f1) $(stat -c%s "$index_name") $index_name" >> Release
    )
}

# Generate info for both directories
generate_repo_info binaries
generate_repo_info source
