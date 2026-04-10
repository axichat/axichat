#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-${repo_root}/build/flatpak}"
pub_cache_root="${PUB_CACHE:-${HOME}/.pub-cache}"
pub_cache_dir="${output_dir}/pub-cache"
third_party_dir="${output_dir}/third_party"
cargo_vendor_dir="${output_dir}/vendor/cargo"

usage() {
  cat <<'EOF'
Usage: ./tool/prepare_flatpak_inputs.sh [output-dir]

This script stages the pinned third-party inputs needed for Axichat's Linux
desktop packaging work:

- Hosted pub.dev packages from the local pub cache
- Git dependencies used by Axichat's pubspec.lock
- Vendored Rust crates for packages/delta_ffi/rust
- The Flatpak source manifest fetches Flutter, SQLCipher, and PDFium directly
EOF
}

git_dependency_resolved_ref() {
  local package_name="$1"

  ruby -ryaml -e '
    lockfile_path = ARGV.fetch(0)
    package_name = ARGV.fetch(1)
    lockfile = YAML.load_file(lockfile_path)
    package = lockfile.fetch("packages").fetch(package_name) do
      abort "Missing package #{package_name} in #{lockfile_path}"
    end
    unless package["source"] == "git"
      abort "Package #{package_name} is not a git dependency in #{lockfile_path}"
    end

    description = package.fetch("description")
    resolved_ref = description["resolved-ref"] || description["ref"]
    if resolved_ref.nil? || resolved_ref.empty?
      abort "Missing resolved-ref for #{package_name} in #{lockfile_path}"
    end

    puts resolved_ref
  ' "${repo_root}/pubspec.lock" "${package_name}"
}

copy_hosted_package() {
  local package_name="$1"
  local package_version="$2"
  local source_package_dir
  local relative_package_dir
  local source_hash_file=""
  local relative_hash_file

  source_package_dir="$(find "${pub_cache_root}/hosted" -maxdepth 2 -mindepth 2 -type d -name "${package_name}-${package_version}" -print -quit)"
  if [[ -z "${source_package_dir}" ]]; then
    echo "Unable to locate hosted package ${package_name} ${package_version} in ${pub_cache_root}/hosted" >&2
    exit 1
  fi

  relative_package_dir="${source_package_dir#${pub_cache_root}/hosted/}"
  mkdir -p "${pub_cache_dir}/hosted/$(dirname "${relative_package_dir}")"
  cp -R "${source_package_dir}" "${pub_cache_dir}/hosted/${relative_package_dir}"

  if [[ ! -d "${pub_cache_root}/hosted-hashes" ]]; then
    return
  fi

  source_hash_file="$(find "${pub_cache_root}/hosted-hashes" -maxdepth 2 -mindepth 2 -type f -name "${package_name}-${package_version}.sha256" -print -quit)"
  if [[ -z "${source_hash_file}" ]]; then
    return
  fi

  relative_hash_file="${source_hash_file#${pub_cache_root}/hosted-hashes/}"
  mkdir -p "${pub_cache_dir}/hosted-hashes/$(dirname "${relative_hash_file}")"
  cp "${source_hash_file}" "${pub_cache_dir}/hosted-hashes/${relative_hash_file}"
}

copy_git_checkout() {
  local package_prefix="$1"
  local expected_rev="$2"
  local destination="$3"
  local candidate
  local candidate_rev
  local source_checkout=""

  while IFS= read -r candidate; do
    candidate_rev="$(git -C "${candidate}" rev-parse HEAD 2>/dev/null || true)"
    if [[ "${candidate_rev}" == "${expected_rev}" ]]; then
      source_checkout="${candidate}"
      break
    fi
  done < <(find "${pub_cache_root}/git" -maxdepth 1 -mindepth 1 -type d -name "${package_prefix}-*" -print)

  if [[ -z "${source_checkout}" ]]; then
    echo "Unable to locate ${package_prefix} at ${expected_rev} in ${pub_cache_root}/git" >&2
    exit 1
  fi

  rm -rf "${destination}"
  mkdir -p "$(dirname "${destination}")"
  cp -R "${source_checkout}" "${destination}"
  rm -rf "${destination}/.git"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ ! -d "${pub_cache_root}/hosted" ]]; then
  echo "Missing pub cache hosted directory: ${pub_cache_root}/hosted" >&2
  exit 1
fi

rm -rf "${pub_cache_dir}"
mkdir -p "${pub_cache_dir}/hosted"
if [[ -d "${pub_cache_root}/hosted-hashes" ]]; then
  mkdir -p "${pub_cache_dir}/hosted-hashes"
fi

while IFS=$'\t' read -r package_name package_version; do
  copy_hosted_package "${package_name}" "${package_version}"
done < <(
  ruby -ryaml -e '
    lockfile = YAML.load_file(ARGV.fetch(0))
    lockfile.fetch("packages").each_value do |package|
      next unless package["source"] == "hosted"

      description = package.fetch("description")
      puts "#{description.fetch("name")}\t#{package.fetch("version")}"
    end
  ' "${repo_root}/pubspec.lock"
)

moxlib_rev="$(git_dependency_resolved_ref "moxlib")"
moxxmpp_rev="$(git_dependency_resolved_ref "moxxmpp")"
moxxmpp_socket_tcp_rev="$(git_dependency_resolved_ref "moxxmpp_socket_tcp")"
omemo_dart_rev="$(git_dependency_resolved_ref "omemo_dart")"

if [[ "${moxxmpp_rev}" != "${moxxmpp_socket_tcp_rev}" ]]; then
  echo "moxxmpp and moxxmpp_socket_tcp resolved refs differ in pubspec.lock." >&2
  echo "moxxmpp: ${moxxmpp_rev}" >&2
  echo "moxxmpp_socket_tcp: ${moxxmpp_socket_tcp_rev}" >&2
  exit 1
fi

copy_git_checkout "moxlib" "${moxlib_rev}" "${third_party_dir}/moxlib"
copy_git_checkout "moxxmpp" "${moxxmpp_rev}" "${third_party_dir}/moxxmpp"
copy_git_checkout "omemo_dart" "${omemo_dart_rev}" "${third_party_dir}/omemo_dart"

cat > "${output_dir}/pubspec_overrides.yaml" <<'EOF'
dependency_overrides:
  pinenacl: ^0.6.0
  intl: ^0.20.2
  moxlib:
    path: flatpak-third_party/moxlib
  moxxmpp:
    path: flatpak-third_party/moxxmpp/packages/moxxmpp
  moxxmpp_socket_tcp:
    path: flatpak-third_party/moxxmpp/packages/moxxmpp_socket_tcp
  omemo_dart:
    path: flatpak-third_party/omemo_dart
EOF

mkdir -p "$(dirname "${cargo_vendor_dir}")"
tmp_cargo_config="$(mktemp)"
rm -rf "${cargo_vendor_dir}"
cargo vendor --locked --versioned-dirs \
  --manifest-path "${repo_root}/packages/delta_ffi/rust/Cargo.toml" \
  "${cargo_vendor_dir}" > "${tmp_cargo_config}"

{
  cat "${repo_root}/packages/delta_ffi/rust/.cargo/config.toml"
  printf '\n'
  sed 's|directory = \".*\"|directory = \"flatpak-cargo-vendor\"|' "${tmp_cargo_config}"
} > "${output_dir}/cargo-config.toml"

rm -f "${tmp_cargo_config}"

cat <<EOF
Prepared Flatpak inputs under ${output_dir}
- Pub cache: ${pub_cache_dir}
- Git dependencies: ${third_party_dir}
- Cargo vendor dir: ${cargo_vendor_dir}
- Manifest-fetched sources: Flutter SDK, SQLCipher, PDFium
EOF
