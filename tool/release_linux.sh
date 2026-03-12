#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder="${AXICHAT_LINUX_BUILDER:-shorebird}"
flavor="${AXICHAT_LINUX_FLAVOR:-production}"
flutter_version="${AXICHAT_FLUTTER_VERSION:-3.41.4}"
output_dir="${AXICHAT_RELEASE_OUTPUT_DIR:-${repo_root}/dist}"
package_version="${AXICHAT_RELEASE_VERSION:-}"
deb_architecture="${AXICHAT_DEB_ARCH:-amd64}"
declare -a flutter_args=()

usage() {
  cat <<'EOF'
Usage: ./tool/release_linux.sh [options] -- [flutter build args]

This script must run on Linux. It produces:
  - dist/axichat-linux.tar.gz
  - dist/axichat-linux-amd64.deb
  - matching .sha256 files

Requirements:
  - Flutter configured for Linux desktop
  - Shorebird on PATH when --builder shorebird is used
  - dpkg-deb on PATH to package the .deb

Options:
  --builder <shorebird|flutter>  Build with Shorebird (default) or plain Flutter.
  --flavor <name>                Flutter flavor to build. Default: production.
  --flutter-version <version>    Flutter version passed to Shorebird release.
  --output-dir <dir>             Release output directory. Default: dist.
  --version <tag-or-version>     Version passed to the Debian package script.
  -h, --help                     Show this help text.

Examples:
  ./tool/release_linux.sh --version v0.6.1
  ./tool/release_linux.sh --builder flutter --version v0.6.1 -- --dart-define=FOO=bar
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --builder)
      builder="$2"
      shift 2
      ;;
    --flavor)
      flavor="$2"
      shift 2
      ;;
    --flutter-version)
      flutter_version="$2"
      shift 2
      ;;
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --version)
      package_version="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      flutter_args=("$@")
      break
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "tool/release_linux.sh must run on Linux because Flutter Linux desktop builds are Linux-hosted." >&2
  exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "Missing required tool: dpkg-deb. Install Debian packaging tools before running tool/release_linux.sh." >&2
  exit 1
fi

cd "${repo_root}"

flutter config --enable-linux-desktop
flutter pub get
dart run build_runner build --delete-conflicting-outputs

case "${builder}" in
  shorebird)
    shorebird release linux \
      --flavor "${flavor}" \
      --flutter-version="${flutter_version}" \
      -- \
      "${flutter_args[@]}"
    ;;
  flutter)
    flutter build linux \
      --release \
      --flavor "${flavor}" \
      "${flutter_args[@]}"
    ;;
  *)
    echo "Unsupported builder: ${builder}" >&2
    exit 1
    ;;
esac

mkdir -p "${output_dir}"
tar -czf "${output_dir}/axichat-linux.tar.gz" -C "${repo_root}/build/linux/x64/release/bundle" .
"${repo_root}/tool/package_deb.sh" "${repo_root}/build/linux/x64/release/bundle" "${package_version}" "${output_dir}"
"${repo_root}/tool/write_sha256_files.sh" \
  "${output_dir}/axichat-linux.tar.gz" \
  "${output_dir}/axichat-linux-${deb_architecture}.deb"
