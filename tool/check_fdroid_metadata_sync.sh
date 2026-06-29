#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pubspec_path="${repo_root}/pubspec.yaml"
fdroid_metadata_path="${repo_root}/fdroid/metadata/im.axi.axichat.yml"
flutter_version_path="${repo_root}/.flutter-version"
fdroid_patch_in_app_update_path="${repo_root}/tool/patch_fdroid_in_app_update.py"
strip_dev_flutter_plugins_path="${repo_root}/tool/strip_dev_flutter_plugins.py"
build_fdroid_linux_path="${repo_root}/tool/build_fdroid_linux.sh"

if [[ ! -f "${pubspec_path}" ]]; then
  echo "Missing pubspec.yaml at ${pubspec_path}" >&2
  exit 1
fi

if [[ ! -f "${fdroid_metadata_path}" ]]; then
  echo "Missing F-Droid metadata at ${fdroid_metadata_path}" >&2
  exit 1
fi

if [[ ! -f "${flutter_version_path}" ]]; then
  echo "Missing Flutter version pin at ${flutter_version_path}" >&2
  exit 1
fi

for required_path in \
  "${fdroid_patch_in_app_update_path}" \
  "${strip_dev_flutter_plugins_path}" \
  "${build_fdroid_linux_path}"; do
  if [[ ! -f "${required_path}" ]]; then
    echo "Missing F-Droid helper at ${required_path}" >&2
    exit 1
  fi
done

pubspec_version_line="$(awk '/^version:[[:space:]]*/ {print $2; exit}' "${pubspec_path}")"
if [[ ! "${pubspec_version_line}" =~ ^([^+]+)\+([0-9]+)$ ]]; then
  echo "Unable to parse pubspec version '${pubspec_version_line}' (expected name+code)." >&2
  exit 1
fi

pubspec_version_name="${BASH_REMATCH[1]}"
pubspec_version_code="${BASH_REMATCH[2]}"
expected_version_code="$((2000 + pubspec_version_code))"
expected_release_tag="v${pubspec_version_name}"
expected_source_code_url="https://github.com/axichat/axichat"
expected_issue_tracker_url="https://github.com/axichat/axichat/issues"
expected_changelog_url="https://github.com/axichat/axichat/releases"
expected_repo_url="https://github.com/axichat/axichat.git"
expected_binaries_url="https://github.com/axichat/axichat/releases/download/v%v/app-arm64-v8a-production-release.apk"
expected_apk_signing_key="92d96304e82efa324f6aab21d731b32f05dbb3c8d42fc5514ea6755f33498d2e"
expected_flutter_version="$(tr -d '\r\n' < "${flutter_version_path}")"

failed=0

metadata_build_version_name="$(awk '/^[[:space:]]+- versionName:/ {print $3; exit}' "${fdroid_metadata_path}")"
metadata_build_version_code="$(awk '/^[[:space:]]+versionCode:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_build_commit="$(awk '/^[[:space:]]+commit:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_source_code_url="$(awk -F': ' '/^SourceCode:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_issue_tracker_url="$(awk -F': ' '/^IssueTracker:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_changelog_url="$(awk -F': ' '/^Changelog:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_repo_url="$(awk -F': ' '/^Repo:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_binaries_url="$(
  awk '
    /^Binaries:/ {
      sub(/^Binaries:[[:space:]]*/, "")
      if (length($0) > 0) {
        print
        exit
      }
      getline
      sub(/^[[:space:]]+/, "")
      print
      exit
    }
  ' "${fdroid_metadata_path}"
)"
metadata_allowed_signing_keys="$(awk -F': ' '/^AllowedAPKSigningKeys:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_current_version="$(awk '/^CurrentVersion:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_current_version_code="$(awk '/^CurrentVersionCode:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_update_check_data="$(awk -F': ' '/^UpdateCheckData:/ {print $2; exit}' "${fdroid_metadata_path}")"
expected_release_commit=""

if git rev-parse -q --verify "refs/tags/${expected_release_tag}^{commit}" >/dev/null 2>&1; then
  expected_release_commit="$(git rev-list -n 1 "${expected_release_tag}")"
fi

if [[ "${metadata_build_version_name}" != "${pubspec_version_name}" ]]; then
  echo "Mismatch: Builds.versionName=${metadata_build_version_name} pubspec=${pubspec_version_name}" >&2
  failed=1
fi

if [[ "${metadata_build_version_code}" != "${expected_version_code}" ]]; then
  echo "Mismatch: Builds.versionCode=${metadata_build_version_code} expected=${expected_version_code}" >&2
  failed=1
fi

if [[ -n "${expected_release_commit}" && "${metadata_build_commit}" != "${expected_release_commit}" ]]; then
  echo "Mismatch: Builds.commit=${metadata_build_commit} expected=${expected_release_commit}" >&2
  failed=1
fi

if [[ "${metadata_source_code_url}" != "${expected_source_code_url}" ]]; then
  echo "Mismatch: SourceCode=${metadata_source_code_url} expected=${expected_source_code_url}" >&2
  failed=1
fi

if [[ "${metadata_issue_tracker_url}" != "${expected_issue_tracker_url}" ]]; then
  echo "Mismatch: IssueTracker=${metadata_issue_tracker_url} expected=${expected_issue_tracker_url}" >&2
  failed=1
fi

if [[ "${metadata_changelog_url}" != "${expected_changelog_url}" ]]; then
  echo "Mismatch: Changelog=${metadata_changelog_url} expected=${expected_changelog_url}" >&2
  failed=1
fi

if [[ "${metadata_repo_url}" != "${expected_repo_url}" ]]; then
  echo "Mismatch: Repo=${metadata_repo_url} expected=${expected_repo_url}" >&2
  failed=1
fi

if [[ "${metadata_binaries_url}" != "${expected_binaries_url}" ]]; then
  echo "Mismatch: Binaries=${metadata_binaries_url} expected=${expected_binaries_url}" >&2
  failed=1
fi

if [[ "${metadata_allowed_signing_keys}" != "${expected_apk_signing_key}" ]]; then
  echo "Mismatch: AllowedAPKSigningKeys=${metadata_allowed_signing_keys} expected=${expected_apk_signing_key}" >&2
  failed=1
fi

if [[ "${metadata_current_version}" != "${pubspec_version_name}" ]]; then
  echo "Mismatch: CurrentVersion=${metadata_current_version} pubspec=${pubspec_version_name}" >&2
  failed=1
fi

if [[ "${metadata_current_version_code}" != "${expected_version_code}" ]]; then
  echo "Mismatch: CurrentVersionCode=${metadata_current_version_code} expected=${expected_version_code}" >&2
  failed=1
fi

if [[ "${metadata_update_check_data}" != "pubspec.yaml|version:\s.+\+(\d+)|.|version:\s(.+)\+" ]]; then
  echo "Mismatch: UpdateCheckData=${metadata_update_check_data}" >&2
  failed=1
fi

check_count() {
  local expected="$1"
  local pattern="$2"
  local description="$3"
  local mode="${4:-fixed}"
  local path="${5:-${fdroid_metadata_path}}"
  local actual

  if command -v rg >/dev/null 2>&1; then
    if [[ "${mode}" == "regex" ]]; then
      actual="$(rg -c -- "${pattern}" "${path}" || true)"
    else
      actual="$(rg -F -c -- "${pattern}" "${path}" || true)"
    fi
  else
    if [[ "${mode}" == "regex" ]]; then
      actual="$(grep -E -c -- "${pattern}" "${path}" || true)"
    else
      actual="$(grep -F -c -- "${pattern}" "${path}" || true)"
    fi
  fi
  actual="${actual:-0}"

  if [[ "${actual}" != "${expected}" ]]; then
    echo "Missing expected ${description} in ${path} (expected ${expected}, found ${actual})" >&2
    failed=1
  fi
}

check_absent() {
  local pattern="$1"
  local description="$2"
  local mode="${3:-fixed}"
  local path="${4:-${fdroid_metadata_path}}"
  local found=0

  if command -v rg >/dev/null 2>&1; then
    if [[ "${mode}" == "regex" ]]; then
      if rg -q -- "${pattern}" "${path}"; then
        found=1
      fi
    else
      if rg -F -q -- "${pattern}" "${path}"; then
        found=1
      fi
    fi
  else
    if [[ "${mode}" == "regex" ]]; then
      if grep -E -q -- "${pattern}" "${path}"; then
        found=1
      fi
    else
      if grep -F -q -- "${pattern}" "${path}"; then
        found=1
      fi
    fi
  fi

  if [[ "${found}" -ne 0 ]]; then
    echo "Unexpected ${description} in ${path}" >&2
    failed=1
  fi
}

check_count 1 '^\s+- flutter@stable$' 'flutter srclib' regex
check_count 1 "flutterVersion=\\\$\\(tr -d '\\\\r\\\\n' < \\.flutter-version\\)" 'flutter version extraction command' regex
check_count 1 'git -C $$flutter$$ checkout -f $flutterVersion' 'flutter checkout command'
check_count 1 'apt-get update' 'apt-get update'
check_count 1 'apt-get install -y gcc make libc-dev pkg-config perl rustup' 'host toolchain install'
check_count 1 '$$flutter$$/bin/flutter config --no-analytics' 'Flutter analytics disable'
check_count 1 '--build-number=$(($$VERCODE$$ % 1000))' 'Flutter build-number override'
check_count 1 '--dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken' 'EMAIL_PUBLIC_TOKEN define'
check_count 1 '--dart-define=ENABLE_SHOREBIRD=false' 'ENABLE_SHOREBIRD define'
check_count 1 'rustup default 1.90.0' 'rustup toolchain select'
check_count 1 'rustup target add aarch64-linux-android' 'arm64 rust target'
check_count 1 '^\s+ndk: 28\.2\.13676358$' 'NDK pin' regex
check_count 1 'python3 tool/patch_fdroid_in_app_update.py "$PUB_CACHE"' 'repo in_app_update helper invocation'
check_count 1 'python3 tool/strip_dev_flutter_plugins.py' 'repo dev-only Flutter plugin strip script'
check_count 1 '    "com.google.android.play:app-update",' 'Play Core dependency removal' fixed "${fdroid_patch_in_app_update_path}"
check_count 1 '    "com.google.android.play:app-update-ktx",' 'Play Core KTX dependency removal' fixed "${fdroid_patch_in_app_update_path}"
check_count 1 'InAppUpdatePlugin.kt' 'in_app_update plugin stub target' fixed "${fdroid_patch_in_app_update_path}"
check_count 1 'Play in-app updates are unavailable in this build.' 'in_app_update stub message' fixed "${fdroid_patch_in_app_update_path}"
check_count 1 'dev_dependency' 'dev-only Flutter plugin filter' fixed "${strip_dev_flutter_plugins_path}"
check_count 2 'dependencyGraph' 'Flutter plugin dependency graph cleanup' fixed "${strip_dev_flutter_plugins_path}"
check_count 1 'patch_fdroid_in_app_update.py' 'repo in_app_update helper path'
check_count 1 'strip_dev_flutter_plugins.py' 'repo Flutter plugin cleanup helper path'
check_count 1 'find "${PUB_CACHE}/hosted/pub.dev" -mindepth 2 -maxdepth 2' 'pub-cache pruning command' fixed "${build_fdroid_linux_path}"
check_count 1 '-name extension' 'pub-cache pruning extension target' fixed "${build_fdroid_linux_path}"
check_count 1 '-exec rm -rf {} +' 'pub-cache pruning delete action' fixed "${build_fdroid_linux_path}"
check_count 1 'rm -rf .dart_tool/build android/.gradle .gradle-user-home' 'pre-Flutter cleanup before release build' fixed "${build_fdroid_linux_path}"
check_count 1 '^\s+- \.pub-cache$' '.pub-cache scandelete entry' regex
check_count 1 '^\s+- 2000 \+ %c$' 'VercodeOperation arm64 entry' regex

check_absent '1000 + %c' 'armv7 VercodeOperation'
check_absent '4000 + %c' 'x86_64 VercodeOperation'
check_absent 'app-armeabi-v7a-production-release.apk' 'armv7 APK output'
check_absent 'app-x86_64-production-release.apk' 'x86_64 APK output'
check_absent 'rustup target add armv7-linux-androideabi' 'armv7 Rust target'
check_absent 'rustup target add x86_64-linux-android' 'x86_64 Rust target'
check_absent 'rustup@1.27.1' 'rustup srclib entry'
check_absent 'build-essential pkg-config perl' 'old host toolchain install'
check_absent 'rustup-init.sh -y --default-toolchain 1.90.0' 'old rustup bootstrap'
check_absent 'source $HOME/.cargo/env' 'old cargo env source'
check_absent 'export GRADLE_USER_HOME=$(pwd)/.gradle-user-home' 'old GRADLE_USER_HOME export'
check_absent 'export GRADLE_OPTS="' 'old GRADLE_OPTS export prefix'
check_absent 'printf "sdk.dir=%s\nflutter.sdk=%s\n" "$$SDK$$" "$$flutter$$" > android/local.properties' 'old android/local.properties write'
check_absent '^\s+- export ANDROID_(HOME|SDK_ROOT|NDK_HOME|NDK_ROOT)=\$\$(SDK|NDK)\$\$$' 'old Android SDK/NDK env exports' regex
check_absent 'flutter build apk \\' 'shell-style line continuations in flutter build command'
check_absent 'base64.b64decode(' 'inline base64-generated helper'
check_absent '.fdroid_patch_in_app_update.py' 'temporary generated helper path'
check_absent "python3 -c 'import json; from pathlib import Path;" 'inline plugin strip python'
check_absent 'flutter@3\.41\.4' 'hardcoded flutter srclib pin' regex

if [[ ! "${expected_flutter_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid .flutter-version '${expected_flutter_version}'" >&2
  exit 1
fi

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "F-Droid metadata is in sync with pubspec (${pubspec_version_name}+${pubspec_version_code}), Flutter ${expected_flutter_version}, and arm64 F-Droid version-code mapping."
