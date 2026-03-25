#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flutter_version_file="${repo_root}/.flutter-version"
builder="${AXICHAT_ANDROID_BUILDER:-shorebird}"
flavor="${AXICHAT_ANDROID_FLAVOR:-production}"
artifact="${AXICHAT_ANDROID_ARTIFACT:-apk}"
default_flutter_version="$(tr -d '\r\n' < "${flutter_version_file}")"
flutter_version="${AXICHAT_FLUTTER_VERSION:-${default_flutter_version}}"
output_dir="${AXICHAT_RELEASE_OUTPUT_DIR:-${repo_root}/dist}"
declare -a flutter_args=()

usage() {
  cat <<'EOF'
Usage: ./tool/release_android.sh [options] -- [flutter build args]

Options:
  --builder <shorebird|flutter>  Build with Shorebird (default) or plain Flutter.
  --flavor <name>                Flutter flavor to build. Default: production.
  --artifact <apk|appbundle>     Android artifact type. Default: apk.
  --flutter-version <version>    Flutter version passed to Shorebird release.
  --output-dir <dir>             Release output directory. Default: dist.
  -h, --help                     Show this help text.

Examples:
  ./tool/release_android.sh
  ./tool/release_android.sh --builder flutter --artifact apk -- --dart-define=FOO=bar
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
    --artifact)
      artifact="$2"
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

cd "${repo_root}"

flutter pub get
dart run build_runner build --delete-conflicting-outputs

case "${builder}" in
  shorebird)
    shorebird release android \
      --flavor "${flavor}" \
      --artifact="${artifact}" \
      --flutter-version="${flutter_version}" \
      -- \
      "${flutter_args[@]}"
    ;;
  flutter)
    flutter build "${artifact}" \
      --release \
      --flavor "${flavor}" \
      "${flutter_args[@]}"
    ;;
  *)
    echo "Unsupported builder: ${builder}" >&2
    exit 1
    ;;
esac

artifact_root="${repo_root}/build/app/outputs"
artifact_pattern='*.apk'
artifact_dir="${artifact_root}/flutter-apk"
if [[ "${artifact}" == "appbundle" ]]; then
  artifact_pattern='*.aab'
  artifact_dir="${artifact_root}/bundle"
fi

mapfile -t built_artifacts < <(find "${artifact_dir}" -type f -name "${artifact_pattern}" | sort)
if [[ "${#built_artifacts[@]}" -eq 0 ]]; then
  echo "Unable to locate built Android artifacts under ${artifact_dir}" >&2
  exit 1
fi

mkdir -p "${output_dir}"
copied_artifacts=()
for artifact_path in "${built_artifacts[@]}"; do
  destination_path="${output_dir}/$(basename "${artifact_path}")"
  cp "${artifact_path}" "${destination_path}"
  copied_artifacts+=("${destination_path}")
done

"${repo_root}/tool/write_sha256_files.sh" "${copied_artifacts[@]}"
