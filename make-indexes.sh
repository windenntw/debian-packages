#!/bin/bash

set -x +

generate_index() {
    local index_type="$1"
    local dir_path="$2"
    local output_file="$3"

    echo "Generating ${output_file}..."
    apt-ftparchive "${index_type}" "${dir_path}" \
    | tee "${dir_path}/${output_file}" \
    | gzip -9c > "${dir_path}/${output_file}.gz"
}

# Generate Packages and Sources
generate_index packages dists/windenntw/windenntw/binary-amd64 Packages
generate_index sources dists/windenntw/windenntw/source Sources

echo "Generating Release file..."
# Generate the top-level Release file
apt-ftparchive -c apt-release.conf release dists/windenntw > dists/windenntw/Release

echo "Done!"
