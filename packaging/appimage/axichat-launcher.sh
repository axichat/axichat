#!/bin/sh

set -eu

appdir="${APPDIR:-$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)}"
bundle_root="${appdir}/usr/lib/axichat"

ld_library_path="${appdir}/usr/lib:${bundle_root}/lib"
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  ld_library_path="${ld_library_path}:${LD_LIBRARY_PATH}"
fi
export LD_LIBRARY_PATH="${ld_library_path}"

exec "${bundle_root}/axichat" "$@"
