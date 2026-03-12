#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
input_dir="${1:-${repo_root}/build/flatpak}"
output_dir="${2:-${repo_root}/build/flathub-sources}"
archive_name="${AXICHAT_FLATPAK_INPUTS_ARCHIVE_NAME:-axichat-flatpak-inputs.tar.gz}"
archive_path="${output_dir}/${archive_name}"
snippet_path="${output_dir}/${archive_name%.tar.gz}.source.yml"
placeholder_url="${AXICHAT_FLATPAK_INPUTS_URL:-https://example.invalid/${archive_name}}"

required_paths=(
  "pub-cache"
  "third_party"
  "vendor/cargo"
  "cargo-config.toml"
  "pubspec_overrides.yaml"
)

for relative_path in "${required_paths[@]}"; do
  if [[ ! -e "${input_dir}/${relative_path}" ]]; then
    echo "Missing required Flatpak input: ${input_dir}/${relative_path}" >&2
    exit 1
  fi
done

mkdir -p "${output_dir}"
rm -f "${archive_path}" "${snippet_path}"

tar -C "${input_dir}" -czf "${archive_path}" .
archive_sha256="$(shasum -a 256 "${archive_path}" | awk '{print $1}')"

cat > "${snippet_path}" <<EOF
# Replace the placeholder URL after uploading ${archive_name}
- type: archive
  url: ${placeholder_url}
  sha256: ${archive_sha256}
  dest: flatpak-inputs
EOF

cat <<EOF
Archived Flatpak inputs to ${archive_path}
SHA256: ${archive_sha256}
Manifest snippet: ${snippet_path}
Next step: upload ${archive_name} somewhere stable and replace the local
flatpak-inputs dir source in packaging/flatpak/im.axi.axichat.source.yml
with the printed archive source. The Axichat app source itself still needs a
reviewer-visible git or archive source for Flathub.
EOF
