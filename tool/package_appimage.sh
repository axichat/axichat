#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="${1:-${repo_root}/build/linux/x64/release/bundle}"
raw_version="${2:-}"
output_dir="${3:-${repo_root}/dist}"
architecture="${AXICHAT_APPIMAGE_ARCH:-x86_64}"
appdir="${AXICHAT_APPIMAGE_APPDIR:-${repo_root}/build/linux/appimage/AppDir}"
appimage_workdir="${AXICHAT_APPIMAGE_WORKDIR:-${repo_root}/build/linux/appimage}"
desktop_file="${repo_root}/linux/im.axi.axichat.desktop"
icon_file="${repo_root}/assets/icons/generated/app_icon_linux.png"
metainfo_file="${repo_root}/packaging/flatpak/im.axi.axichat.metainfo.xml"
launcher_template="${repo_root}/packaging/appimage/axichat-launcher.sh"
linuxdeploy_bin="${AXICHAT_LINUXDEPLOY_BIN:-}"
appimage_runtime_file="${AXICHAT_APPIMAGE_RUNTIME_FILE:-${appimage_workdir}/runtime-${architecture}}"
appimage_runtime_url="${AXICHAT_APPIMAGE_RUNTIME_URL:-https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-${architecture}}"
appimage_validate_metadata="${AXICHAT_APPIMAGE_VALIDATE_METADATA:-0}"
package_file="${output_dir}/axichat-${architecture}.AppImage"

usage() {
  cat <<'EOF'
Usage: ./tool/package_appimage.sh [bundle-dir] [version] [output-dir]

Build an AppImage from the Flutter Linux bundle using linuxdeploy.

Environment overrides:
  AXICHAT_LINUXDEPLOY_BIN   linuxdeploy executable or AppImage path.
  AXICHAT_APPIMAGE_ARCH     AppImage architecture label. Default: x86_64.
  AXICHAT_APPIMAGE_APPDIR   AppDir working directory.
  AXICHAT_APPIMAGE_RUNTIME_FILE
                            Optional AppImage runtime file for offline builds.
  AXICHAT_APPIMAGE_RUNTIME_URL
                            Runtime download URL. Default: official AppImage
                            runtime for the selected architecture.
  AXICHAT_APPIMAGE_VALIDATE_METADATA
                            Set to 1 to enable appstream validation during
                            AppImage packaging. Default: 0.
EOF
}

resolve_linuxdeploy() {
  if [[ -n "${linuxdeploy_bin}" ]]; then
    printf '%s\n' "${linuxdeploy_bin}"
    return
  fi

  for candidate in linuxdeploy linuxdeploy-x86_64.AppImage; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return
    fi
  done

  if [[ -x "${HOME}/Applications/linuxdeploy-x86_64.AppImage" ]]; then
    printf '%s\n' "${HOME}/Applications/linuxdeploy-x86_64.AppImage"
    return
  fi

  if [[ -x "${HOME}/.local/bin/linuxdeploy" ]]; then
    printf '%s\n' "${HOME}/.local/bin/linuxdeploy"
    return
  fi

  return 1
}

resolve_image_tool() {
  for candidate in magick convert; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return
    fi
  done

  return 1
}

resolve_download_tool() {
  for candidate in curl wget; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return
    fi
  done

  return 1
}

download_runtime() {
  local destination="$1"
  local destination_dir
  destination_dir="$(dirname "${destination}")"
  mkdir -p "${destination_dir}"

  local download_tool
  download_tool="$(resolve_download_tool || true)"
  if [[ -z "${download_tool}" ]]; then
    cat >&2 <<'EOF'
Missing required download tool: install `curl` or `wget`, or set
AXICHAT_APPIMAGE_RUNTIME_FILE to a pre-downloaded AppImage runtime.
EOF
    exit 1
  fi

  local temp_file
  temp_file="$(mktemp "${destination}.XXXXXX")"
  trap 'rm -f "${temp_file}"' RETURN

  if [[ "${download_tool}" == "curl" ]]; then
    curl -Lf --retry 3 --output "${temp_file}" "${appimage_runtime_url}"
  else
    wget -O "${temp_file}" "${appimage_runtime_url}"
  fi

  chmod +x "${temp_file}"
  mv -f "${temp_file}" "${destination}"
  trap - RETURN
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "tool/package_appimage.sh must run on Linux." >&2
  exit 1
fi

if [[ ! -d "${bundle_dir}" ]]; then
  echo "Missing Linux bundle directory: ${bundle_dir}" >&2
  exit 1
fi

if [[ ! -f "${desktop_file}" ]]; then
  echo "Missing desktop file: ${desktop_file}" >&2
  exit 1
fi

if [[ ! -f "${icon_file}" ]]; then
  echo "Missing icon file: ${icon_file}" >&2
  exit 1
fi

if [[ ! -f "${metainfo_file}" ]]; then
  echo "Missing AppStream metadata file: ${metainfo_file}" >&2
  exit 1
fi

if [[ ! -f "${launcher_template}" ]]; then
  echo "Missing AppImage launcher template: ${launcher_template}" >&2
  exit 1
fi

image_tool="$(resolve_image_tool || true)"
if [[ -z "${image_tool}" ]]; then
  cat >&2 <<'EOF'
Missing required tool: ImageMagick.
Install ImageMagick so the AppImage icon can be resized to a linuxdeploy-
compatible size, or make `magick`/`convert` available on PATH.
EOF
  exit 1
fi

linuxdeploy_resolved="$(resolve_linuxdeploy || true)"
if [[ -z "${linuxdeploy_resolved}" ]]; then
  cat >&2 <<'EOF'
Missing required tool: linuxdeploy.
Install linuxdeploy as described in the AppImage packaging guide, or set
AXICHAT_LINUXDEPLOY_BIN to the linuxdeploy executable/AppImage path.
EOF
  exit 1
fi

chmod +x "${linuxdeploy_resolved}" 2>/dev/null || true

declare -a linuxdeploy_command=("${linuxdeploy_resolved}")
linuxdeploy_realpath="${linuxdeploy_resolved}"
if command -v readlink >/dev/null 2>&1; then
  linuxdeploy_realpath="$(readlink -f "${linuxdeploy_resolved}" 2>/dev/null || printf '%s\n' "${linuxdeploy_resolved}")"
fi

if [[ "${linuxdeploy_resolved}" == *.AppImage || "${linuxdeploy_realpath}" == *.AppImage ]]; then
  # linuxdeploy is often distributed as an AppImage. Running it in
  # extract-and-run mode avoids a hard dependency on FUSE/fusermount.
  export APPIMAGE_EXTRACT_AND_RUN=1
fi

if [[ -z "${raw_version}" ]]; then
  raw_version="$(awk '/^version:[[:space:]]*/ {print $2; exit}' "${repo_root}/pubspec.yaml")"
fi

version="${raw_version#v}"
version="${version%%+*}"

if [[ -z "${version}" ]]; then
  echo "Unable to determine AppImage version." >&2
  exit 1
fi

if [[ ! -f "${appimage_runtime_file}" ]]; then
  echo "Downloading AppImage runtime to ${appimage_runtime_file}" >&2
  download_runtime "${appimage_runtime_file}"
fi

rm -rf "${appdir}"
mkdir -p \
  "${appdir}/usr/bin" \
  "${appdir}/usr/lib/axichat" \
  "${appdir}/usr/lib/axichat/share/icons/hicolor/256x256/apps" \
  "${appdir}/usr/share/metainfo" \
  "${appdir}/usr/share/icons/hicolor/256x256/apps"

cp -R "${bundle_dir}/." "${appdir}/usr/lib/axichat/"

appimage_icon_file="${appdir}/usr/share/icons/hicolor/256x256/apps/im.axi.axichat.png"
"${image_tool}" "${icon_file}" -resize 256x256! "${appimage_icon_file}"
cp "${appimage_icon_file}" \
  "${appdir}/usr/lib/axichat/share/icons/hicolor/256x256/apps/im.axi.axichat.png"
install -Dm644 "${metainfo_file}" "${appdir}/usr/share/metainfo/im.axi.axichat.appdata.xml"

linuxdeploy_args=(
  --appdir "${appdir}"
  --desktop-file "${desktop_file}"
  --icon-file "${appimage_icon_file}"
  --custom-apprun "${launcher_template}"
  --deploy-deps-only "${appdir}/usr/lib/axichat/axichat"
)

while IFS= read -r library_path; do
  linuxdeploy_args+=(--library "${library_path}")
done < <(
  find "${appdir}/usr/lib/axichat/lib" -maxdepth 1 -type f \
    \( -name '*.so' -o -name '*.so.*' \) | sort
)

mkdir -p "${output_dir}"
rm -f "${package_file}"

before_snapshot="$(mktemp)"
after_snapshot="$(mktemp)"
find "${output_dir}" -maxdepth 1 -type f -name '*.AppImage' -printf '%f\n' | sort > "${before_snapshot}"

(
  cd "${output_dir}"
  if [[ -n "${appimage_runtime_file}" ]]; then
    export LDAI_RUNTIME_FILE="${appimage_runtime_file}"
  fi
  if [[ "${appimage_validate_metadata}" != "1" ]]; then
    export LDAI_NO_APPSTREAM=1
  fi
  ARCH="${architecture}" VERSION="${version}" "${linuxdeploy_command[@]}" "${linuxdeploy_args[@]}" --output appimage
)

find "${output_dir}" -maxdepth 1 -type f -name '*.AppImage' -printf '%f\n' | sort > "${after_snapshot}"
generated_appimage="$(
  comm -13 "${before_snapshot}" "${after_snapshot}" | head -n 1
)"

if [[ -z "${generated_appimage}" ]]; then
  generated_appimage="$(find "${output_dir}" -maxdepth 1 -type f -name '*.AppImage' -printf '%T@ %f\n' | sort -n | tail -n 1 | awk '{print $2}')"
fi

rm -f "${before_snapshot}" "${after_snapshot}"

if [[ -z "${generated_appimage}" ]]; then
  echo "linuxdeploy did not produce an AppImage in ${output_dir}." >&2
  exit 1
fi

if [[ "${output_dir}/${generated_appimage}" != "${package_file}" ]]; then
  mv -f "${output_dir}/${generated_appimage}" "${package_file}"
fi

chmod +x "${package_file}"
echo "Created ${package_file}"
