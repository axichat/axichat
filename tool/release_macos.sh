#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_info_xcconfig="${repo_root}/macos/Runner/Configs/AppInfo.xcconfig"
product_name="$(sed -n 's/^PRODUCT_NAME[[:space:]]*=[[:space:]]*//p' "${app_info_xcconfig}" | head -n 1)"
product_name="${product_name:-axichat}"
bundle_dir_default="${repo_root}/build/macos/export/${product_name}.app"
output_dir="${AXICHAT_RELEASE_OUTPUT_DIR:-${repo_root}/dist}"
bundle_dir="${AXICHAT_MACOS_BUNDLE_DIR:-${bundle_dir_default}}"
archive_name="${AXICHAT_MACOS_ARCHIVE_NAME:-}"
email_public_token="${AXICHAT_EMAIL_PUBLIC_TOKEN:-${EMAIL_PUBLIC_TOKEN:-axichatpublictoken}}"
notary_profile="${AXICHAT_MACOS_NOTARY_PROFILE:-}"
apple_id="${AXICHAT_MACOS_APPLE_ID:-}"
app_password="${AXICHAT_MACOS_APP_PASSWORD:-}"
team_id="${AXICHAT_MACOS_TEAM_ID:-}"
target_arch="${AXICHAT_MACOS_TARGET_ARCH:-universal}"
archive_name_overridden=0
package_only=0
skip_notarize=0
declare -a flutter_args=()
declare -a notary_credentials_args=()

usage() {
  cat <<'EOF'
Usage: ./tool/release_macos.sh [options] -- [flutter build args]

This script must run on macOS. It produces:
  - dist/axichat-macos.zip
  - dist/axichat-macos.zip.sha256

The emitted macOS app is intended for direct distribution outside the Mac App
Store. It archives the app, exports a Developer ID build, notarizes it,
staples the ticket, then packages the final app as a zip.

Options:
  --output-dir <dir>             Release output directory. Default: dist.
  --bundle-dir <dir>             Existing .app bundle to package. Default:
                                 build/macos/export/<PRODUCT_NAME>.app
  --target-arch <universal|arm64|x64>
                                 Architecture lane to package. Default: universal.
                                 Use arm64 for a smaller Apple Silicon-only build.
  --archive-name <name.zip>      Zip filename to emit. Default:
                                 axichat-macos.zip for universal,
                                 axichat-macos-arm64.zip for arm64,
                                 axichat-macos-x64.zip for x64.
  --email-public-token <token>   EMAIL_PUBLIC_TOKEN dart define. Default:
                                 $AXICHAT_EMAIL_PUBLIC_TOKEN, $EMAIL_PUBLIC_TOKEN,
                                 or axichatpublictoken.
  --notary-profile <name>        notarytool keychain profile created with:
                                 xcrun notarytool store-credentials <name> ...
  --apple-id <email>             Apple ID for direct notarytool auth.
  --app-password <password>      App-specific password for direct notarytool auth.
  --team-id <id>                 Apple Developer Team ID. Required when direct
                                 notarytool auth is used. Also used for export.
  --skip-notarize                Skip notarization/stapling and only export +
                                 package the signed app.
  --package-only                 Skip the Flutter/Xcode archive + export and use
                                 the existing app bundle.
  -h, --help                     Show this help text.

Examples:
  ./tool/release_macos.sh --notary-profile axichat-notary
  ./tool/release_macos.sh --target-arch arm64 --notary-profile axichat-notary
  ./tool/release_macos.sh --skip-notarize
  ./tool/release_macos.sh --package-only --notary-profile axichat-notary
  ./tool/release_macos.sh --notary-profile axichat-notary -- --build-name=0.7.2 --build-number=7
EOF
}

resolve_archive_name() {
  case "${target_arch}" in
    universal)
      printf '%s\n' "axichat-macos.zip"
      ;;
    arm64)
      printf '%s\n' "axichat-macos-arm64.zip"
      ;;
    x64)
      printf '%s\n' "axichat-macos-x64.zip"
      ;;
    *)
      echo "Unsupported target arch: ${target_arch}" >&2
      exit 1
      ;;
  esac
}

required_free_kib() {
  case "${target_arch}" in
    universal)
      printf '%s\n' $((8 * 1024 * 1024))
      ;;
    arm64|x64)
      printf '%s\n' $((4 * 1024 * 1024))
      ;;
    *)
      echo "Unsupported target arch: ${target_arch}" >&2
      exit 1
      ;;
  esac
}

format_kib_human() {
  local kib="$1"
  awk -v kib="${kib}" 'BEGIN {
    if (kib >= 1024 * 1024) {
      printf "%.1f GiB", kib / (1024 * 1024)
    } else if (kib >= 1024) {
      printf "%.1f MiB", kib / 1024
    } else {
      printf "%d KiB", kib
    }
  }'
}

ensure_free_space() {
  local required_kib available_kib
  required_kib="$(required_free_kib)"
  available_kib="$(df -Pk "${repo_root}" | awk 'NR==2 {print $4}')"

  if [[ -z "${available_kib}" ]]; then
    echo "Unable to determine free disk space for ${repo_root}" >&2
    exit 1
  fi

  if (( available_kib < required_kib )); then
    echo "Insufficient free disk space for a ${target_arch} macOS release build." >&2
    echo "Available: $(format_kib_human "${available_kib}")" >&2
    echo "Recommended minimum: $(format_kib_human "${required_kib}")" >&2
    echo "Generated directories that are often safe to remove:" >&2
    echo "  - .dart_tool/hooks_runner" >&2
    echo "  - build/macos" >&2
    echo "  - build/ios" >&2
    echo "Then rerun tool/release_macos.sh." >&2
    exit 1
  fi
}

find_rustc() {
  if [[ -n "${RUSTC:-}" && -x "${RUSTC}" ]]; then
    printf '%s\n' "${RUSTC}"
    return 0
  fi

  if command -v rustc >/dev/null 2>&1; then
    command -v rustc
    return 0
  fi

  if [[ -x "${HOME}/.cargo/bin/rustc" ]]; then
    printf '%s\n' "${HOME}/.cargo/bin/rustc"
    return 0
  fi

  return 1
}

rust_target_available() {
  local rustc_executable="$1"
  local target_triple="$2"
  local target_libdir=""

  target_libdir="$("${rustc_executable}" --print target-libdir --target "${target_triple}" 2>/dev/null || true)"
  [[ -n "${target_libdir}" && -d "${target_libdir}" ]]
}

ensure_macos_rust_targets() {
  local rustc_executable=""
  local missing_targets=()

  if ! rustc_executable="$(find_rustc)"; then
    echo "Missing required tool: rustc. Install Rust before running tool/release_macos.sh." >&2
    exit 1
  fi

  case "${target_arch}" in
    universal)
      missing_targets=(aarch64-apple-darwin x86_64-apple-darwin)
      ;;
    arm64)
      missing_targets=(aarch64-apple-darwin)
      ;;
    x64)
      missing_targets=(x86_64-apple-darwin)
      ;;
    *)
      echo "Unsupported target arch: ${target_arch}" >&2
      exit 1
      ;;
  esac

  local required_targets=("${missing_targets[@]}")
  missing_targets=()
  for target_triple in "${required_targets[@]}"; do
    if ! rust_target_available "${rustc_executable}" "${target_triple}"; then
      missing_targets+=("${target_triple}")
    fi
  done

  if [[ "${#missing_targets[@]}" -gt 0 ]]; then
    echo "Missing required Rust target(s): ${missing_targets[*]}" >&2
    echo "Flutter macOS release builds may request both Apple targets." >&2
    echo "Install them with: rustup target add aarch64-apple-darwin x86_64-apple-darwin" >&2
    echo "See packages/delta_ffi/README.md for the repo-specific native build notes." >&2
    exit 1
  fi
}

resolve_team_id() {
  if [[ -n "${team_id}" ]]; then
    printf '%s\n' "${team_id}"
    return 0
  fi

  team_id="$(
    sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM = \([A-Z0-9]\{10\}\);$/\1/p' \
      "${repo_root}/macos/Runner.xcodeproj/project.pbxproj" | head -n 1
  )"
  if [[ -z "${team_id}" ]]; then
    echo "Unable to resolve DEVELOPMENT_TEAM from the macOS project." >&2
    echo "Set AXICHAT_MACOS_TEAM_ID or pass --team-id." >&2
    exit 1
  fi
  printf '%s\n' "${team_id}"
}

prepare_notary_credentials() {
  if [[ "${skip_notarize}" -eq 1 ]]; then
    return 0
  fi

  if [[ -n "${notary_profile}" ]]; then
    notary_credentials_args=(--keychain-profile "${notary_profile}")
    return 0
  fi

  team_id="$(resolve_team_id)"
  if [[ -n "${apple_id}" && -n "${app_password}" ]]; then
    notary_credentials_args=(
      --apple-id "${apple_id}"
      --password "${app_password}"
      --team-id "${team_id}"
    )
    return 0
  fi

  cat >&2 <<'EOF'
Missing notarization credentials.
Provide one of:
  --notary-profile <name>
  --apple-id <email> --app-password <password> --team-id <id>
Or pass --skip-notarize for a signed-but-not-notarized export.
EOF
  exit 1
}

write_export_options_plist() {
  local plist_path="$1"
  local resolved_team_id="$2"

  cat >"${plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>${resolved_team_id}</string>
</dict>
</plist>
EOF
}

package_for_notary() {
  local source_bundle="$1"
  local package_path="$2"
  rm -f "${package_path}"
  ditto -c -k --sequesterRsrc --keepParent "${source_bundle}" "${package_path}"
}

notarize_bundle() {
  local source_bundle="$1"
  local notary_zip="$2"

  package_for_notary "${source_bundle}" "${notary_zip}"
  xcrun notarytool submit \
    "${notary_zip}" \
    "${notary_credentials_args[@]}" \
    --wait
  xcrun stapler staple "${source_bundle}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      output_dir="$2"
      shift 2
      ;;
    --bundle-dir)
      bundle_dir="$2"
      shift 2
      ;;
    --target-arch)
      target_arch="$2"
      shift 2
      ;;
    --archive-name)
      archive_name="$2"
      archive_name_overridden=1
      shift 2
      ;;
    --email-public-token)
      email_public_token="$2"
      shift 2
      ;;
    --notary-profile)
      notary_profile="$2"
      shift 2
      ;;
    --apple-id)
      apple_id="$2"
      shift 2
      ;;
    --app-password)
      app_password="$2"
      shift 2
      ;;
    --team-id)
      team_id="$2"
      shift 2
      ;;
    --skip-notarize)
      skip_notarize=1
      shift
      ;;
    --package-only)
      package_only=1
      shift
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

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "tool/release_macos.sh must run on macOS because Flutter macOS desktop builds are macOS-hosted." >&2
  exit 1
fi

if [[ "${archive_name_overridden}" -eq 0 ]]; then
  archive_name="$(resolve_archive_name)"
fi

for required_tool in ditto mktemp; do
  if ! command -v "${required_tool}" >/dev/null 2>&1; then
    echo "Missing required tool: ${required_tool}" >&2
    exit 1
  fi
done

prepare_notary_credentials

cd "${repo_root}"

if [[ "${package_only}" -eq 0 ]]; then
  for required_tool in flutter xcrun cargo; do
    if ! command -v "${required_tool}" >/dev/null 2>&1; then
      echo "Missing required tool: ${required_tool}" >&2
      exit 1
    fi
  done

  ensure_macos_rust_targets
  ensure_free_space

  xcode_destination='generic/platform=macOS'
  excluded_archs=""
  case "${target_arch}" in
    universal)
      ;;
    arm64)
      xcode_destination='platform=macOS,arch=arm64'
      excluded_archs='x86_64'
      ;;
    x64)
      xcode_destination='platform=macOS,arch=x86_64'
      excluded_archs='arm64'
      ;;
    *)
      echo "Unsupported target arch: ${target_arch}" >&2
      exit 1
      ;;
  esac

  flutter config --enable-macos-desktop
  flutter pub get
  dart run build_runner build --delete-conflicting-outputs

  build_args=(
    --release
    --config-only
    --dart-define=EMAIL_PUBLIC_TOKEN="${email_public_token}"
  )
  if [[ "${#flutter_args[@]}" -gt 0 ]]; then
    build_args+=("${flutter_args[@]}")
  fi

  flutter build macos "${build_args[@]}"

  archive_path="${repo_root}/build/macos/archive/${product_name}.xcarchive"
  export_path="${repo_root}/build/macos/export"
  export_options_plist="$(mktemp "${TMPDIR:-/tmp}/axichat-export-options.XXXXXX.plist")"
  resolved_team_id="$(resolve_team_id)"
  write_export_options_plist "${export_options_plist}" "${resolved_team_id}"
  rm -rf "${archive_path}" "${export_path}"

  xcrun xcodebuild archive \
    -workspace macos/Runner.xcworkspace \
    -configuration Release \
    -scheme Runner \
    -archivePath "${archive_path}" \
    -destination "${xcode_destination}" \
    -quiet \
    COMPILER_INDEX_STORE_ENABLE=NO \
    "OBJROOT=${repo_root}/build/macos/Build/Intermediates.noindex" \
    "SYMROOT=${repo_root}/build/macos/Build/Products" \
    ${excluded_archs:+"EXCLUDED_ARCHS=${excluded_archs}"}

  xcrun xcodebuild \
    -exportArchive \
    -archivePath "${archive_path}" \
    -exportPath "${export_path}" \
    -exportOptionsPlist "${export_options_plist}" \
    -quiet

  rm -f "${export_options_plist}"
fi

if [[ ! -d "${bundle_dir}" ]]; then
  echo "macOS app bundle not found: ${bundle_dir}" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "${bundle_dir}"

if [[ "${skip_notarize}" -eq 0 ]]; then
  notarize_workspace="${repo_root}/build/macos/notary"
  mkdir -p "${notarize_workspace}"
  notarize_bundle "${bundle_dir}" "${notarize_workspace}/${archive_name}"
fi

mkdir -p "${output_dir}"
archive_path="${output_dir%/}/${archive_name}"
rm -f "${archive_path}" "${archive_path}.sha256"

ditto -c -k --sequesterRsrc --keepParent "${bundle_dir}" "${archive_path}"
"${repo_root}/tool/write_sha256_files.sh" "${archive_path}"
