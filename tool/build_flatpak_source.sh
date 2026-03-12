#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
inputs_dir="${AXICHAT_FLATPAK_INPUTS_DIR:-${repo_root}/build/flatpak}"
builder_dir="${AXICHAT_FLATPAK_BUILD_DIR:-${repo_root}/build/flatpak-builder}"
manifest="${repo_root}/packaging/flatpak/im.axi.axichat.source.yml"

if ! command -v flatpak-builder >/dev/null 2>&1; then
  echo "flatpak-builder is required to build the source-based Flatpak." >&2
  exit 1
fi

"${repo_root}/tool/prepare_flatpak_inputs.sh" "${inputs_dir}"
flatpak-builder --force-clean "${builder_dir}" "${manifest}"
