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
expected_armv7_version_code="$((1000 + pubspec_version_code))"
expected_arm64_version_code="$((2000 + pubspec_version_code))"
expected_x64_version_code="$((4000 + pubspec_version_code))"
expected_current_version_code="${expected_x64_version_code}"

metadata_build_version_names=()
while IFS= read -r line; do
  metadata_build_version_names+=("${line}")
done < <(awk '/^[[:space:]]+- versionName:/ {print $3}' "${fdroid_metadata_path}")

metadata_build_version_codes=()
while IFS= read -r line; do
  metadata_build_version_codes+=("${line}")
done < <(awk '/^[[:space:]]+versionCode:/ {print $2}' "${fdroid_metadata_path}")
metadata_current_version="$(awk '/^CurrentVersion:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_current_version_code="$(awk '/^CurrentVersionCode:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_update_check_data="$(awk -F': ' '/^UpdateCheckData:/ {print $2; exit}' "${fdroid_metadata_path}")"
metadata_vercode_operations=()
while IFS= read -r line; do
  metadata_vercode_operations+=("${line}")
done < <(
  awk '
    /^VercodeOperation:/ {in_ops=1; next}
    in_ops && /^[[:space:]]+- / {
      line=$0
      sub(/^[[:space:]]+-[[:space:]]*/, "", line)
      print line
      next
    }
    in_ops {in_ops=0}
  ' "${fdroid_metadata_path}"
)

failed=0

if [[ "${#metadata_build_version_names[@]}" -eq 0 ]]; then
  echo "Missing Builds.versionName entries in ${fdroid_metadata_path}" >&2
  failed=1
fi

for build_version_name in "${metadata_build_version_names[@]}"; do
  if [[ "${build_version_name}" != "${pubspec_version_name}" ]]; then
    echo "Mismatch: Builds.versionName=${build_version_name} pubspec=${pubspec_version_name}" >&2
    failed=1
  fi
done

expected_codes=(
  "${expected_armv7_version_code}"
  "${expected_arm64_version_code}"
  "${expected_x64_version_code}"
)

if [[ "${#metadata_build_version_codes[@]}" -ne "${#expected_codes[@]}" ]]; then
  echo "Mismatch: expected ${#expected_codes[@]} Builds.versionCode entries, found ${#metadata_build_version_codes[@]}" >&2
  failed=1
fi

for expected_code in "${expected_codes[@]}"; do
  found_expected=0
  for actual_code in "${metadata_build_version_codes[@]}"; do
    if [[ "${actual_code}" == "${expected_code}" ]]; then
      found_expected=1
      break
    fi
  done
  if [[ "${found_expected}" -eq 0 ]]; then
    echo "Missing expected Builds.versionCode=${expected_code} (pubspec build code ${pubspec_version_code})" >&2
    failed=1
  fi
done

for actual_code in "${metadata_build_version_codes[@]}"; do
  is_known_code=0
  for expected_code in "${expected_codes[@]}"; do
    if [[ "${actual_code}" == "${expected_code}" ]]; then
      is_known_code=1
      break
    fi
  done
  if [[ "${is_known_code}" -eq 0 ]]; then
    echo "Unexpected Builds.versionCode=${actual_code}. Expected only: ${expected_codes[*]}" >&2
    failed=1
  fi
done

if [[ "${metadata_current_version}" != "${pubspec_version_name}" ]]; then
  echo "Mismatch: CurrentVersion=${metadata_current_version} pubspec=${pubspec_version_name}" >&2
  failed=1
fi

if [[ "${metadata_current_version_code}" != "${expected_current_version_code}" ]]; then
  echo "Mismatch: CurrentVersionCode=${metadata_current_version_code} expected=${expected_current_version_code}" >&2
  failed=1
fi

expected_vercode_operations=(
  "1000 + %c"
  "2000 + %c"
  "4000 + %c"
)
expected_update_check_data="'pubspec.yaml|version:\\s.+\\+(\\d+)|.|version:\\s(.+)\\+'"

if [[ "${#metadata_vercode_operations[@]}" -ne "${#expected_vercode_operations[@]}" ]]; then
  echo "Mismatch: expected ${#expected_vercode_operations[@]} VercodeOperation entries, found ${#metadata_vercode_operations[@]}" >&2
  failed=1
fi

for expected_operation in "${expected_vercode_operations[@]}"; do
  found_operation=0
  for actual_operation in "${metadata_vercode_operations[@]}"; do
    if [[ "${actual_operation}" == "${expected_operation}" ]]; then
      found_operation=1
      break
    fi
  done
  if [[ "${found_operation}" -eq 0 ]]; then
    echo "Missing expected VercodeOperation entry: ${expected_operation}" >&2
    failed=1
  fi
done

if [[ "${metadata_update_check_data}" != "${expected_update_check_data}" ]]; then
  echo "Mismatch: UpdateCheckData=${metadata_update_check_data} expected=${expected_update_check_data}" >&2
  failed=1
fi

if command -v rg >/dev/null 2>&1; then
  missing_shorebird_define=0
  missing_email_token_define=0
  missing_vercode_build_number=0
  missing_flutter_srclib=0
  missing_flutter_local_properties=0
  missing_pub_cache_scandelete=0
  multiline_flutter_build_commands=0
  missing_ndk_pin=0
  missing_android_sdk_env=0
  missing_rustup_srclib=0
  missing_rustup_setup=0
  if ! rg -q -- "--dart-define=ENABLE_SHOREBIRD=false" "${fdroid_metadata_path}"; then
    missing_shorebird_define=1
  fi
  if ! rg -q -- "--dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken" "${fdroid_metadata_path}"; then
    missing_email_token_define=1
  fi
  if [[ "$(rg -F -c -- '--build-number=$(($$VERCODE$$ % 1000))' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_vercode_build_number=1
  fi
  if [[ "$(rg -c -- 'flutter@3\.41\.4' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_flutter_srclib=1
  fi
  if [[ "$(rg -c -- 'rustup@1\.27\.1' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_rustup_srclib=1
  fi
  if [[ "$(rg -c -- 'printf "sdk\.dir=%s\\nflutter\.sdk=%s\\n" "\$\$SDK\$\$" "\$\$flutter\$\$" > android/local\.properties' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_flutter_local_properties=1
  fi
  if [[ "$(rg -c -- '^[[:space:]]+- \.pub-cache$' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_pub_cache_scandelete=1
  fi
  if rg -q -- 'flutter build apk \\' "${fdroid_metadata_path}"; then
    multiline_flutter_build_commands=1
  fi
  if [[ "$(rg -c -- '^[[:space:]]+ndk: 28\.2\.13676358$' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_ndk_pin=1
  fi
  if [[ "$(rg -c -- '^[[:space:]]+- export ANDROID_(HOME|SDK_ROOT|NDK_HOME|NDK_ROOT)=\$\$(SDK|NDK)\$\$$' "${fdroid_metadata_path}")" != "24" ]]; then
    missing_android_sdk_env=1
  fi
  if [[ "$(rg -F -c -- 'rustup-init.sh -y --default-toolchain 1.90.0' "${fdroid_metadata_path}")" != "3" ]] || [[ "$(rg -F -c -- 'source $HOME/.cargo/env' "${fdroid_metadata_path}")" != "3" ]] || [[ "$(rg -F -c -- 'rustup target add armv7-linux-androideabi aarch64-linux-android x86_64-linux-android' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_rustup_setup=1
  fi
else
  missing_shorebird_define=0
  missing_email_token_define=0
  missing_vercode_build_number=0
  missing_flutter_srclib=0
  missing_flutter_local_properties=0
  missing_pub_cache_scandelete=0
  multiline_flutter_build_commands=0
  missing_ndk_pin=0
  missing_android_sdk_env=0
  missing_rustup_srclib=0
  missing_rustup_setup=0
  if ! grep -F -q -- "--dart-define=ENABLE_SHOREBIRD=false" "${fdroid_metadata_path}"; then
    missing_shorebird_define=1
  fi
  if ! grep -F -q -- "--dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken" "${fdroid_metadata_path}"; then
    missing_email_token_define=1
  fi
  if [[ "$(grep -F -c -- '--build-number=$(($$VERCODE$$ % 1000))' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_vercode_build_number=1
  fi
  if [[ "$(grep -F -c -- 'flutter@3.41.4' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_flutter_srclib=1
  fi
  if [[ "$(grep -F -c -- 'rustup@1.27.1' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_rustup_srclib=1
  fi
  if [[ "$(grep -F -c -- 'printf "sdk.dir=%s\nflutter.sdk=%s\n" "$$SDK$$" "$$flutter$$" > android/local.properties' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_flutter_local_properties=1
  fi
  if [[ "$(grep -E -c '^[[:space:]]+- \.pub-cache$' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_pub_cache_scandelete=1
  fi
  if grep -F -q -- 'flutter build apk \' "${fdroid_metadata_path}"; then
    multiline_flutter_build_commands=1
  fi
  if [[ "$(grep -E -c '^[[:space:]]+ndk: 28\.2\.13676358$' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_ndk_pin=1
  fi
  if [[ "$(grep -E -c '^[[:space:]]+- export ANDROID_(HOME|SDK_ROOT|NDK_HOME|NDK_ROOT)=\\$\\$(SDK|NDK)\\$\\$$' "${fdroid_metadata_path}")" != "24" ]]; then
    missing_android_sdk_env=1
  fi
  if [[ "$(grep -F -c -- 'rustup-init.sh -y --default-toolchain 1.90.0' "${fdroid_metadata_path}")" != "3" ]] || [[ "$(grep -E -c '^[[:space:]]+- source \\$HOME/\\.cargo/env$' "${fdroid_metadata_path}")" != "3" ]] || [[ "$(grep -E -c '^[[:space:]]+- rustup target add armv7-linux-androideabi aarch64-linux-android x86_64-linux-android$' "${fdroid_metadata_path}")" != "3" ]]; then
    missing_rustup_setup=1
  fi
fi

if [[ "${missing_shorebird_define}" -ne 0 ]]; then
  echo "Missing required F-Droid build define: --dart-define=ENABLE_SHOREBIRD=false" >&2
  failed=1
fi

if [[ "${missing_email_token_define}" -ne 0 ]]; then
  echo "Missing required F-Droid build define: --dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken" >&2
  failed=1
fi

if [[ "${missing_vercode_build_number}" -ne 0 ]]; then
  echo 'Expected each split build to use --build-number=$(($$VERCODE$$ % 1000)) so Flutter adds the ABI offset only once' >&2
  failed=1
fi

if [[ "${missing_flutter_srclib}" -ne 0 ]]; then
  echo 'Expected each split build to declare srclibs: flutter@3.41.4 for $$flutter$$ commands' >&2
  failed=1
fi

if [[ "${missing_rustup_srclib}" -ne 0 ]]; then
  echo 'Expected each split build to declare srclibs: rustup@1.27.1 for the Rust toolchain bootstrap' >&2
  failed=1
fi

if [[ "${missing_flutter_local_properties}" -ne 0 ]]; then
  echo 'Expected each split build to write sdk.dir=$$SDK$$ and flutter.sdk=$$flutter$$ to android/local.properties in prebuild' >&2
  failed=1
fi

if [[ "${missing_pub_cache_scandelete}" -ne 0 ]]; then
  echo 'Expected each split build to scandelete .pub-cache to avoid Flutter dependency scanner noise' >&2
  failed=1
fi

if [[ "${multiline_flutter_build_commands}" -ne 0 ]]; then
  echo 'Flutter build apk commands must be single-line YAML scalars, not shell-style backslash continuations' >&2
  failed=1
fi

if [[ "${missing_ndk_pin}" -ne 0 ]]; then
  echo 'Expected each split build to pin ndk: 28.2.13676358' >&2
  failed=1
fi

if [[ "${missing_android_sdk_env}" -ne 0 ]]; then
  echo 'Expected each split build to export ANDROID_HOME/ANDROID_SDK_ROOT/ANDROID_NDK_HOME/ANDROID_NDK_ROOT' >&2
  failed=1
fi

if [[ "${missing_rustup_setup}" -ne 0 ]]; then
  echo 'Expected each split build to install rustup 1.90.0 and add the Android Rust targets before flutter pub get' >&2
  failed=1
fi

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "F-Droid metadata is in sync with pubspec (${pubspec_version_name}+${pubspec_version_code}) and split ABI version-code mapping."
