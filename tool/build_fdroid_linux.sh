#!/usr/bin/env bash

set -euo pipefail

host_packages=(
  gcc
  make
  libc-dev
  pkg-config
  perl
  rustup
  git
  python3
  openjdk-17-jdk
  curl
  unzip
  xz-utils
)

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is intended to run on Linux." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
metadata_path="${repo_root}/fdroid/metadata/im.axi.axichat.yml"

if [[ ! -f "${metadata_path}" ]]; then
  echo "Missing metadata file: ${metadata_path}" >&2
  exit 1
fi

cd "${repo_root}"

expected_commit="$(awk '/^[[:space:]]+commit:/ {print $2; exit}' "${metadata_path}")"
expected_flutter_version="$(awk '/^[[:space:]]+- flutter@/ {sub(/.*flutter@/, ""); print; exit}' "${metadata_path}")"
expected_rust_toolchain="$(awk '/^[[:space:]]+- rustup default / {print $4; exit}' "${metadata_path}")"

ensure_host_packages() {
  local need_install=0
  local required_commands=(
    git
    python3
    rustup
    curl
    unzip
    xz
    javac
  )

  for cmd in "${required_commands[@]}"; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      need_install=1
      break
    fi
  done

  if [[ "${need_install}" -eq 0 ]]; then
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Missing required host tools and apt-get is unavailable." >&2
    exit 1
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "Missing required host tools and sudo is unavailable to install them." >&2
    exit 1
  fi

  sudo apt-get update
  sudo apt-get install -y "${host_packages[@]}"
}

install_flutter_if_needed() {
  local flutter_parent archive_name archive_path download_url detected_version

  flutter_parent="${FLUTTER_PARENT:-${HOME}/sdk}"

  if [[ -n "${FLUTTER_ROOT:-}" && -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
    flutter_root="${FLUTTER_ROOT}"
  elif command -v flutter >/dev/null 2>&1; then
    flutter_bin="$(command -v flutter)"
    flutter_root="$(cd "$(dirname "${flutter_bin}")/.." && pwd)"
  else
    flutter_root="${flutter_parent}/flutter-${expected_flutter_version}"
  fi

  if [[ -x "${flutter_root}/bin/flutter" ]]; then
    detected_version="$(
      python3 - "${flutter_root}/bin/flutter" <<'PY'
import json
import subprocess
import sys

flutter = sys.argv[1]

try:
    output = subprocess.check_output(
        [flutter, "--version", "--machine"],
        stderr=subprocess.STDOUT,
        text=True,
    )
    print(json.loads(output)["frameworkVersion"])
    raise SystemExit(0)
except Exception:
    pass

output = subprocess.check_output(
    [flutter, "--version"],
    stderr=subprocess.STDOUT,
    text=True,
)
parts = output.splitlines()[0].split()
if len(parts) < 2:
    raise SystemExit("Could not determine Flutter version.")
print(parts[1])
PY
    )"
    if [[ "${detected_version}" == "${expected_flutter_version}" ]]; then
      export FLUTTER_ROOT="${flutter_root}"
      return
    fi
  fi

  mkdir -p "${flutter_parent}"
  archive_name="flutter_linux_${expected_flutter_version}-stable.tar.xz"
  archive_path="${flutter_parent}/${archive_name}"
  download_url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${archive_name}"
  flutter_root="${flutter_parent}/flutter-${expected_flutter_version}"

  rm -rf "${flutter_root}" "${flutter_parent}/flutter"
  curl -L "${download_url}" -o "${archive_path}"
  tar -xf "${archive_path}" -C "${flutter_parent}"
  mv "${flutter_parent}/flutter" "${flutter_root}"

  export FLUTTER_ROOT="${flutter_root}"
}

flutter_version() {
  python3 - "$1" <<'PY'
import json
import subprocess
import sys

flutter = sys.argv[1]

try:
    output = subprocess.check_output(
        [flutter, "--version", "--machine"],
        stderr=subprocess.STDOUT,
        text=True,
    )
    print(json.loads(output)["frameworkVersion"])
    raise SystemExit(0)
except Exception:
    pass

output = subprocess.check_output(
    [flutter, "--version"],
    stderr=subprocess.STDOUT,
    text=True,
)
parts = output.splitlines()[0].split()
if len(parts) < 2:
    raise SystemExit("Could not determine Flutter version.")
print(parts[1])
PY
}

ensure_android_components() {
  local sdkmanager

  sdkmanager="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
  if [[ ! -x "${sdkmanager}" ]]; then
    echo "Missing sdkmanager at ${sdkmanager}." >&2
    echo "Install Android command-line tools first." >&2
    exit 1
  fi

  yes | "${sdkmanager}" --licenses >/dev/null
  "${sdkmanager}" \
    "ndk;${ndk_version}" \
    "platforms;android-34" \
    "platforms;android-35" \
    "platforms;android-36" \
    "build-tools;35.0.0" \
    "cmake;3.22.1"
}

ensure_host_packages

current_commit="$(git rev-parse HEAD)"

if [[ "${ALLOW_NON_METADATA_COMMIT:-0}" != "1" && "${current_commit}" != "${expected_commit}" ]]; then
  echo "Current HEAD is ${current_commit}, but metadata expects ${expected_commit}." >&2
  echo "Checkout ${expected_commit} first, or rerun with ALLOW_NON_METADATA_COMMIT=1." >&2
  exit 1
fi

install_flutter_if_needed

if [[ -z "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ]]; then
  echo "Set ANDROID_HOME or ANDROID_SDK_ROOT before running this script." >&2
  exit 1
fi

export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
export ANDROID_SDK_ROOT="${ANDROID_HOME}"

ndk_version="$(awk '/^[[:space:]]+ndk:/ {print $2; exit}' "${metadata_path}")"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-${ANDROID_HOME}/ndk/${ndk_version}}}"
export ANDROID_NDK_ROOT="${ANDROID_NDK_HOME}"

if [[ ! -d "${ANDROID_HOME}" ]]; then
  echo "Android SDK not found: ${ANDROID_HOME}" >&2
  exit 1
fi

ensure_android_components

if [[ ! -d "${ANDROID_NDK_HOME}" ]]; then
  echo "Android NDK not found: ${ANDROID_NDK_HOME}" >&2
  exit 1
fi

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  echo "Flutter binary not found: ${FLUTTER_ROOT}/bin/flutter" >&2
  exit 1
fi

actual_flutter_version="$(flutter_version "${FLUTTER_ROOT}/bin/flutter")"

if [[ "${actual_flutter_version}" != "${expected_flutter_version}" ]]; then
  echo "Flutter version ${actual_flutter_version} does not match metadata version ${expected_flutter_version}." >&2
  echo "Point FLUTTER_ROOT at Flutter ${expected_flutter_version} before running this script." >&2
  exit 1
fi

vercode="$(awk '/^[[:space:]]+versionCode:/ {print $2; exit}' "${metadata_path}")"
build_number="$((vercode % 1000))"
output_path="$(awk '/^[[:space:]]+output:/ {print $2; exit}' "${metadata_path}")"
default_email_public_token="$(grep -o 'EMAIL_PUBLIC_TOKEN=[^[:space:]]*' "${metadata_path}" | head -n 1 | cut -d= -f2)"
email_public_token="${EMAIL_PUBLIC_TOKEN:-${default_email_public_token}}"

export PUB_CACHE="${repo_root}/.pub-cache"
export PATH="${HOME}/.cargo/bin:${PATH}"

printf 'sdk.dir=%s\nflutter.sdk=%s\n' "${ANDROID_HOME}" "${FLUTTER_ROOT}" > android/local.properties

"${FLUTTER_ROOT}/bin/flutter" config --no-analytics
rustup default "${expected_rust_toolchain}"
rustup target add aarch64-linux-android

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is not available on PATH after rustup setup." >&2
  exit 1
fi

"${FLUTTER_ROOT}/bin/flutter" pub get

python3 - "${metadata_path}" <<'PY'
import base64
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r'write_bytes\(base64\.b64decode\("([A-Za-z0-9+/=\s]+)"\)\)', text, re.S)
if match is None:
    raise SystemExit("Could not extract in_app_update patch helper from metadata.")
Path(".fdroid_patch_in_app_update.py").write_bytes(base64.b64decode(match.group(1)))
PY
python3 .fdroid_patch_in_app_update.py "${PUB_CACHE}"
rm -f .fdroid_patch_in_app_update.py

python3 - <<'PY'
import json
from pathlib import Path

p = Path(".flutter-plugins-dependencies")
o = json.loads(p.read_text())
d = {
    plugin["name"]
    for plugins in o.get("plugins", {}).values()
    if isinstance(plugins, list)
    for plugin in plugins
    if plugin.get("dev_dependency")
}
o["plugins"] = {
    platform: [plugin for plugin in plugins if plugin.get("name") not in d]
    for platform, plugins in o.get("plugins", {}).items()
}
o["dependencyGraph"] = [
    plugin for plugin in o.get("dependencyGraph", [])
    if plugin.get("name") not in d
]
p.write_text(json.dumps(o, separators=(",", ":")))
PY

find "${PUB_CACHE}/hosted/pub.dev" -mindepth 2 -maxdepth 2 \
  \( -name example -o -name test -o -name tests -o -name benchmark -o -name benchmarks \
     -o -name windows -o -name linux -o -name macos -o -name ios -o -name web -o -name extension \) \
  -prune -exec rm -rf {} +

"${FLUTTER_ROOT}/bin/dart" run build_runner build --delete-conflicting-outputs

rm -rf .dart_tool/build android/.gradle .gradle-user-home

"${FLUTTER_ROOT}/bin/flutter" build apk \
  --flavor production \
  --release \
  --split-per-abi \
  --target-platform=android-arm64 \
  --build-number="${build_number}" \
  --dart-define=EMAIL_PUBLIC_TOKEN="${email_public_token}" \
  --dart-define=ENABLE_SHOREBIRD=false

apk_path="${repo_root}/${output_path}"

if [[ ! -f "${apk_path}" ]]; then
  echo "Build finished without producing ${apk_path}" >&2
  exit 1
fi

echo "Built: ${apk_path}"
sha256sum "${apk_path}"
