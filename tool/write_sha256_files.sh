#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "Usage: ./tool/write_sha256_files.sh <file> [file ...]" >&2
  exit 1
fi

for input_path in "$@"; do
  if [[ ! -f "${input_path}" ]]; then
    echo "Missing file for checksum generation: ${input_path}" >&2
    exit 1
  fi

  checksum_path="${input_path}.sha256"
  checksum_value="$(shasum -a 256 "${input_path}" | awk '{print $1}')"
  printf '%s  %s\n' "${checksum_value}" "$(basename "${input_path}")" > "${checksum_path}"
  echo "Wrote ${checksum_path}"
done
