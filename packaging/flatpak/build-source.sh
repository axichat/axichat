#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
module_root="$(cd "${repo_dir}/.." && pwd)"
inputs_dir="${AXICHAT_FLATPAK_INPUTS_DIR:-${module_root}/flatpak-inputs}"
downloads_dir="${AXICHAT_FLATPAK_DOWNLOADS_DIR:-${module_root}/downloads}"
pub_cache_dir="${inputs_dir}/pub-cache"
home_dir="${module_root}/flatpak-home"

export HOME="${home_dir}"
export CARGO_HOME="${home_dir}/.cargo"
export PUB_CACHE="${pub_cache_dir}"
export PATH="${module_root}/flutter-sdk/flutter/bin:/usr/lib/sdk/rust-stable/bin:${PATH}"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true

required_paths=(
  "${module_root}/flutter-sdk/flutter/bin/flutter"
  "${downloads_dir}/sqlcipher-v4_10_0.c"
  "${downloads_dir}/pdfium-linux-x64.tgz"
  "${inputs_dir}/pub-cache"
  "${inputs_dir}/third_party"
  "${inputs_dir}/vendor/cargo"
  "${inputs_dir}/cargo-config.toml"
  "${inputs_dir}/pubspec_overrides.yaml"
)

for required_path in "${required_paths[@]}"; do
  if [[ ! -e "${required_path}" ]]; then
    echo "Missing required Flatpak source input: ${required_path}" >&2
    exit 1
  fi
done

mkdir -p "${HOME}" "${CARGO_HOME}" "${repo_dir}/.cargo"

ln -sfn "${inputs_dir}/third_party" "${repo_dir}/flatpak-third_party"
ln -sfn "${inputs_dir}/vendor/cargo" "${repo_dir}/.cargo/flatpak-cargo-vendor"
cp "${inputs_dir}/cargo-config.toml" "${repo_dir}/.cargo/config.toml"
cp "${inputs_dir}/pubspec_overrides.yaml" "${repo_dir}/pubspec_overrides.yaml"

cp "${downloads_dir}/sqlcipher-v4_10_0.c" \
  "${PUB_CACHE}/hosted/pub.dev/sqlcipher_flutter_libs-0.6.8/linux/sqlcipher.c"
cp "${downloads_dir}/pdfium-linux-x64.tgz" \
  "${PUB_CACHE}/hosted/pub.dev/pdfium_flutter-0.1.9/linux/pdfium-linux-x64.tgz"

python3 <<'PY'
import os
from pathlib import Path


def replace_once(path_str: str, old: str, new: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    if old not in text:
        raise SystemExit(f"Expected text not found in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


pub_cache = Path(os.environ["PUB_CACHE"])
sqlcipher_path = pub_cache / "hosted/pub.dev/sqlcipher_flutter_libs-0.6.8/linux/CMakeLists.txt"
sqlcipher_download = (
    'file(DOWNLOAD "https://fsn1.your-objectstorage.com/simon-public/assets/sqlcipher/'
    'v4_10_0.c" "${CMAKE_CURRENT_BINARY_DIR}/sqlcipher.c" EXPECTED_HASH '
    'SHA512=ea4ad61eb636a3b6b0a4d8a1b57b51af187ac8724fe853bd9ce58c7ee4054bd62'
    'c4e6d7d11788c8af9ff8e95c6a52eb36a41062172022bc1cbc0567de0aec8c1)'
)
sqlcipher_local = """set(SQLCIPHER_AMALGAMATION "${CMAKE_CURRENT_SOURCE_DIR}/sqlcipher.c")
if(EXISTS "${SQLCIPHER_AMALGAMATION}")
  file(COPY "${SQLCIPHER_AMALGAMATION}" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
else()
  file(DOWNLOAD "https://fsn1.your-objectstorage.com/simon-public/assets/sqlcipher/v4_10_0.c" "${CMAKE_CURRENT_BINARY_DIR}/sqlcipher.c" EXPECTED_HASH SHA512=ea4ad61eb636a3b6b0a4d8a1b57b51af187ac8724fe853bd9ce58c7ee4054bd62c4e6d7d11788c8af9ff8e95c6a52eb36a41062172022bc1cbc0567de0aec8c1)
endif()"""
replace_once(str(sqlcipher_path), sqlcipher_download, sqlcipher_local)

pdfium_path = pub_cache / "hosted/pub.dev/pdfium_flutter-0.1.9/linux/CMakeLists.txt"
pdfium_archive_name = "set(PDFIUM_ARCHIVE_NAME pdfium-${PDFIUM_PLATFORM}-${PDFIUM_LINUX_ABI})"
pdfium_archive_name_with_local = """set(PDFIUM_ARCHIVE_NAME pdfium-${PDFIUM_PLATFORM}-${PDFIUM_LINUX_ABI})
set(PDFIUM_LOCAL_ARCHIVE ${CMAKE_CURRENT_SOURCE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz)"""
replace_once(str(pdfium_path), pdfium_archive_name, pdfium_archive_name_with_local)

pdfium_download = (
    "file(DOWNLOAD "
    "https://github.com/bblanchon/pdfium-binaries/releases/download/${PDFIUM_RELEASE}/"
    "${PDFIUM_ARCHIVE_NAME}.tgz ${PDFIUM_RELEASE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz)"
)
pdfium_local = """if(EXISTS ${PDFIUM_LOCAL_ARCHIVE})
        file(COPY ${PDFIUM_LOCAL_ARCHIVE} DESTINATION ${PDFIUM_RELEASE_DIR})
    else()
        file(DOWNLOAD https://github.com/bblanchon/pdfium-binaries/releases/download/${PDFIUM_RELEASE}/${PDFIUM_ARCHIVE_NAME}.tgz ${PDFIUM_RELEASE_DIR}/${PDFIUM_ARCHIVE_NAME}.tgz)
    endif()"""
replace_once(str(pdfium_path), pdfium_download, pdfium_local)
PY

cd "${repo_dir}"

flutter config --enable-linux-desktop
flutter pub get --offline
flutter build linux --release \
  --dart-define=ENABLE_SHOREBIRD=false \
  --dart-define=EMAIL_PUBLIC_TOKEN=axichatpublictoken

install -Dm755 build/linux/x64/release/bundle/axichat /app/axichat
install -Dm755 packaging/flatpak/run-axichat.sh /app/bin/axichat
mkdir -p /app/lib /app/data
cp -a build/linux/x64/release/bundle/lib/. /app/lib/
cp -a build/linux/x64/release/bundle/data/. /app/data/
install -Dm644 packaging/flatpak/im.axi.axichat.desktop \
  /app/share/applications/im.axi.axichat.desktop
install -Dm644 packaging/flatpak/im.axi.axichat.metainfo.xml \
  /app/share/metainfo/im.axi.axichat.metainfo.xml
install -Dm644 build/linux/x64/release/bundle/share/icons/hicolor/256x256/apps/im.axi.axichat.png \
  /app/share/icons/hicolor/256x256/apps/im.axi.axichat.png
