#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pubspec_path="${repo_root}/pubspec.yaml"
fdroid_metadata_path="${repo_root}/fdroid/metadata/im.axi.axichat.yml"

if [[ ! -f "${pubspec_path}" ]]; then
  echo "Missing pubspec.yaml at ${pubspec_path}" >&2
  exit 1
fi

if [[ ! -f "${fdroid_metadata_path}" ]]; then
  echo "Missing F-Droid metadata at ${fdroid_metadata_path}" >&2
  exit 1
fi

pubspec_version_line="$(awk '/^version:[[:space:]]*/ {print $2; exit}' "${pubspec_path}")"
if [[ ! "${pubspec_version_line}" =~ ^([^+]+)\+([0-9]+)$ ]]; then
  echo "Unable to parse pubspec version '${pubspec_version_line}' (expected name+code)." >&2
  exit 1
fi

pubspec_version_name="${BASH_REMATCH[1]}"
pubspec_version_code="${BASH_REMATCH[2]}"
expected_version_code="$((2000 + pubspec_version_code))"

failed=0

metadata_build_version_name="$(awk '/^[[:space:]]+- versionName:/ {print $3; exit}' "${fdroid_metadata_path}")"
metadata_build_version_code="$(awk '/^[[:space:]]+versionCode:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_current_version="$(awk '/^CurrentVersion:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_current_version_code="$(awk '/^CurrentVersionCode:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_update_check_data="$(awk -F': ' '/^UpdateCheckData:/ {print $2; exit}' "${fdroid_metadata_path}")"

if [[ "${metadata_build_version_name}" != "${pubspec_version_name}" ]]; then
  echo "Mismatch: Builds.versionName=${metadata_build_version_name} pubspec=${pubspec_version_name}" >&2
  failed=1
fi

if [[ "${metadata_build_version_code}" != "${expected_version_code}" ]]; then
  echo "Mismatch: Builds.versionCode=${metadata_build_version_code} expected=${expected_version_code}" >&2
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
  local actual

  if command -v rg >/dev/null 2>&1; then
    if [[ "${mode}" == "regex" ]]; then
      actual="$(rg -c -- "${pattern}" "${fdroid_metadata_path}")"
    else
      actual="$(rg -F -c -- "${pattern}" "${fdroid_metadata_path}")"
    fi
  else
    if [[ "${mode}" == "regex" ]]; then
      actual="$(grep -E -c -- "${pattern}" "${fdroid_metadata_path}")"
    else
      actual="$(grep -F -c -- "${pattern}" "${fdroid_metadata_path}")"
    fi
  fi

  if [[ "${actual}" != "${expected}" ]]; then
    echo "Missing expected ${description} (expected ${expected}, found ${actual})" >&2
    failed=1
  fi
}

check_absent() {
  local pattern="$1"
  local description="$2"
  local mode="${3:-fixed}"
  local found=0

  if command -v rg >/dev/null 2>&1; then
    if [[ "${mode}" == "regex" ]]; then
      if rg -q -- "${pattern}" "${fdroid_metadata_path}"; then
        found=1
      fi
    else
      if rg -F -q -- "${pattern}" "${fdroid_metadata_path}"; then
        found=1
      fi
    fi
  else
    if [[ "${mode}" == "regex" ]]; then
      if grep -E -q -- "${pattern}" "${fdroid_metadata_path}"; then
        found=1
      fi
    else
      if grep -F -q -- "${pattern}" "${fdroid_metadata_path}"; then
        found=1
      fi
    fi
  fi

  if [[ "${found}" -ne 0 ]]; then
    echo "Unexpected ${description}" >&2
    failed=1
  fi
}

check_count 1 'flutter@3.41.4' 'flutter srclib'
check_count 1 'rustup@1.27.1' 'rustup srclib'
check_count 1 'apt-get update' 'apt-get update'
check_count 1 'apt-get install -y build-essential pkg-config perl' 'host toolchain install'
check_count 1 'export GRADLE_USER_HOME=$(pwd)/.gradle-user-home' 'GRADLE_USER_HOME export'
check_count 1 'export GRADLE_OPTS="' 'GRADLE_OPTS export prefix'
check_count 1 '-Dorg.gradle.caching=false' 'Gradle caching disabled'
check_count 1 '-Dorg.gradle.workers.max=1' 'Gradle workers limited'
check_count 1 '-Dorg.gradle.daemon=false' 'Gradle daemon disabled'
check_count 1 '-Dorg.gradle.parallel=false' 'Gradle parallel disabled'
check_count 1 '-Dorg.gradle.vfs.watch=false' 'Gradle VFS watch disabled'
check_count 1 '-Dorg.gradle.configuration-cache=false' 'Gradle configuration cache disabled'
check_count 1 '-Dkotlin.incremental=false' 'Kotlin incremental disabled'
check_count 1 'printf "sdk.dir=%s\nflutter.sdk=%s\n" "$$SDK$$" "$$flutter$$" > android/local.properties' 'android/local.properties write'
check_count 1 '--build-number=$(($$VERCODE$$ % 1000))' 'Flutter build-number override'
check_count 1 '--dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken' 'EMAIL_PUBLIC_TOKEN define'
check_count 1 '--dart-define=ENABLE_SHOREBIRD=false' 'ENABLE_SHOREBIRD define'
check_count 1 'rustup-init.sh -y --default-toolchain 1.90.0' 'rustup bootstrap'
check_count 1 'source $HOME/.cargo/env' 'cargo env source'
check_count 1 'rustup target add aarch64-linux-android' 'arm64 rust target'
check_count 1 '^\s+ndk: 28\.2\.13676358$' 'NDK pin' regex
check_count 8 '^\s+- export ANDROID_(HOME|SDK_ROOT|NDK_HOME|NDK_ROOT)=\$\$(SDK|NDK)\$\$$' 'Android SDK/NDK env exports' regex
check_count 1 "python3 -c 'import json; from pathlib import Path;" 'dev-only Flutter plugin strip script'
check_count 1 '.flutter-plugins-dependencies' 'Flutter plugin graph edit target'
check_count 1 'dev_dependency' 'dev-only Flutter plugin filter'
check_count 1 'dependencyGraph' 'Flutter plugin dependency graph cleanup'
check_count 1 'find "$PUB_CACHE/hosted/pub.dev" -mindepth 2 -maxdepth 2' 'pub-cache pruning command'
check_count 1 '-name extension' 'pub-cache pruning extension target'
check_count 1 '-exec rm -rf {} +' 'pub-cache pruning delete action'
check_count 1 'rm -rf .dart_tool/build android/.gradle .gradle-user-home' 'pre-Flutter cleanup before release build'
check_count 1 '^\s+- \.pub-cache$' '.pub-cache scandelete entry' regex
check_count 1 '^\s+- 2000 \+ %c$' 'VercodeOperation arm64 entry' regex

check_absent '1000 + %c' 'armv7 VercodeOperation'
check_absent '4000 + %c' 'x86_64 VercodeOperation'
check_absent 'app-armeabi-v7a-production-release.apk' 'armv7 APK output'
check_absent 'app-x86_64-production-release.apk' 'x86_64 APK output'
check_absent 'rustup target add armv7-linux-androideabi' 'armv7 Rust target'
check_absent 'rustup target add x86_64-linux-android' 'x86_64 Rust target'
check_absent 'flutter build apk \\' 'shell-style line continuations in flutter build command'

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "F-Droid metadata is in sync with pubspec (${pubspec_version_name}+${pubspec_version_code}) and arm64 F-Droid version-code mapping."
