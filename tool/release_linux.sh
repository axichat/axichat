#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder="${AXICHAT_LINUX_BUILDER:-shorebird}"
flavor="${AXICHAT_LINUX_FLAVOR:-production}"
flutter_version="${AXICHAT_FLUTTER_VERSION:-3.41.4}"
output_dir="${AXICHAT_RELEASE_OUTPUT_DIR:-${repo_root}/dist}"
package_version="${AXICHAT_RELEASE_VERSION:-}"
deb_architecture="${AXICHAT_DEB_ARCH:-amd64}"
appimage_arch="${AXICHAT_APPIMAGE_ARCH:-x86_64}"
email_public_token="${AXICHAT_EMAIL_PUBLIC_TOKEN:-${EMAIL_PUBLIC_TOKEN:-axichatpublictoken}}"
bundle_dir="${AXICHAT_LINUX_BUNDLE_DIR:-${repo_root}/build/linux/x64/release/bundle}"
flavor_requested=0
package_only=0
declare -a flutter_args=()

usage() {
  cat <<'EOF'
Usage: ./tool/release_linux.sh [options] -- [flutter build args]

This script must run on Linux. It produces:
  - dist/axichat-linux.tar.gz
  - dist/axichat-linux-amd64.deb
  - dist/axichat-x86_64.AppImage
  - matching .sha256 files

Requirements:
  - Flutter configured for Linux desktop
  - Shorebird on PATH when --builder shorebird is used
  - dpkg-deb on PATH to package the .deb
  - linuxdeploy available to package the AppImage

Options:
  --builder <shorebird|flutter>  Build with Shorebird (default) or plain Flutter.
  --flavor <name>                Ignored on Linux desktop. Kept for backward
                                 compatibility with older invocations.
  --flutter-version <version>    Flutter version passed to Shorebird release.
  --output-dir <dir>             Release output directory. Default: dist.
  --version <tag-or-version>     Version passed to the Debian package script.
  --package-only                 Skip Flutter/Shorebird and package the existing
                                 Linux bundle directory.
  --bundle-dir <dir>             Linux bundle directory to package. Default:
                                 build/linux/x64/release/bundle.
  --email-public-token <token>   EMAIL_PUBLIC_TOKEN dart define. Default:
                                 $AXICHAT_EMAIL_PUBLIC_TOKEN, $EMAIL_PUBLIC_TOKEN,
                                 or axichatpublictoken.
  -h, --help                     Show this help text.

Examples:
  ./tool/release_linux.sh --version v0.6.1
  ./tool/release_linux.sh --package-only --version v0.6.1
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
      flavor_requested=1
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
    --package-only)
      package_only=1
      shift
      ;;
    --bundle-dir)
      bundle_dir="$2"
      shift 2
      ;;
    --email-public-token)
      email_public_token="$2"
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

if ! command -v flutter >/dev/null 2>&1; then
  echo "Missing required tool: flutter." >&2
  exit 1
fi

cd "${repo_root}"

if [[ "${package_only}" -eq 0 ]]; then
  flutter config --enable-linux-desktop
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs

  build_args=(
    --dart-define=EMAIL_PUBLIC_TOKEN="${email_public_token}"
  )
  if [[ "${#flutter_args[@]}" -gt 0 ]]; then
    build_args+=("${flutter_args[@]}")
  fi

  if [[ "${flavor_requested}" -eq 1 ]]; then
    echo "Ignoring --flavor=${flavor} for Linux desktop; Flutter and Shorebird desktop releases do not support flavors." >&2
  fi

  case "${builder}" in
    shorebird)
      if ! command -v shorebird >/dev/null 2>&1; then
        echo "Missing required tool: shorebird." >&2
        exit 1
      fi
      shorebird release linux \
        --flutter-version="${flutter_version}" \
        -- \
        "${build_args[@]}"
      ;;
    flutter)
      flutter build linux \
        --release \
        "${build_args[@]}"
      ;;
    *)
      echo "Unsupported builder: ${builder}" >&2
      exit 1
      ;;
  esac
fi

if [[ ! -d "${bundle_dir}" ]]; then
  echo "Linux bundle directory not found: ${bundle_dir}" >&2
  exit 1
fi

mkdir -p "${output_dir}"
tar -czf "${output_dir}/axichat-linux.tar.gz" -C "${bundle_dir}" .
"${repo_root}/tool/package_deb.sh" "${bundle_dir}" "${package_version}" "${output_dir}"

checksum_targets=(
  "${output_dir}/axichat-linux.tar.gz"
  "${output_dir}/axichat-linux-${deb_architecture}.deb"
)

"${repo_root}/tool/package_appimage.sh" \
  "${bundle_dir}" \
  "${package_version}" \
  "${output_dir}"
checksum_targets+=("${output_dir}/axichat-${appimage_arch}.AppImage")

"${repo_root}/tool/write_sha256_files.sh" "${checksum_targets[@]}"
