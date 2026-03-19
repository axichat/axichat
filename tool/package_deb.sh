#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="${1:-${repo_root}/build/linux/x64/release/bundle}"
raw_version="${2:-}"
output_dir="${3:-${repo_root}/dist}"
architecture="${AXICHAT_DEB_ARCH:-amd64}"

if [[ ! -d "${bundle_dir}" ]]; then
  echo "Missing Linux bundle directory: ${bundle_dir}" >&2
  exit 1
fi

if [[ -z "${raw_version}" ]]; then
  raw_version="$(awk '/^version:[[:space:]]*/ {print $2; exit}' "${repo_root}/pubspec.yaml")"
fi

version="${raw_version#v}"
version="${version%%+*}"

if [[ -z "${version}" ]]; then
  echo "Unable to determine Debian package version." >&2
  exit 1
fi

package_name="axichat-linux-${architecture}"
package_root="${repo_root}/build/linux/deb/${package_name}"
install_root="${package_root}/opt/axichat"
desktop_file="${repo_root}/linux/im.axi.axichat.desktop"
icon_file="${repo_root}/assets/icons/generated/app_icon_linux.png"
package_file="${output_dir}/${package_name}.deb"
substvars_file="${package_root}/DEBIAN/substvars"

rm -rf "${package_root}"
mkdir -p "${install_root}" "${package_root}/DEBIAN" "${output_dir}"

cp -R "${bundle_dir}/." "${install_root}/"
mkdir -p "${package_root}/usr/bin"
ln -s ../../opt/axichat/axichat "${package_root}/usr/bin/axichat"
install -Dm644 "${desktop_file}" "${package_root}/usr/share/applications/im.axi.axichat.desktop"
install -Dm644 "${icon_file}" "${package_root}/usr/share/icons/hicolor/256x256/apps/im.axi.axichat.png"

depends=""
if command -v dpkg-shlibdeps >/dev/null 2>&1 && command -v file >/dev/null 2>&1; then
  elf_targets=()
  while IFS= read -r -d '' candidate; do
    if file --brief "${candidate}" | grep -q 'ELF'; then
      elf_targets+=("${candidate}")
    fi
  done < <(find "${install_root}" -type f -print0)

  if [[ "${#elf_targets[@]}" -gt 0 ]]; then
    dpkg_shlibdeps_args=(
      "-T${substvars_file}"
      "-l${install_root}"
      "-l${install_root}/lib"
    )
    for target in "${elf_targets[@]}"; do
      dpkg_shlibdeps_args+=("-e${target}")
    done
    dpkg-shlibdeps "${dpkg_shlibdeps_args[@]}"
    depends="$(awk -F= '$1 == "shlibs:Depends" {print $2; exit}' "${substvars_file}")"
  fi
fi

cat > "${package_root}/DEBIAN/control" <<EOF
Package: axichat
Version: ${version}
Section: net
Priority: optional
Architecture: ${architecture}
Maintainer: Axichat <support@axi.chat>
Homepage: https://axi.chat
EOF

if [[ -n "${depends}" ]]; then
  printf 'Depends: %s\n' "${depends}" >> "${package_root}/DEBIAN/control"
fi

cat >> "${package_root}/DEBIAN/control" <<EOF
Description: Open-source XMPP and email client with integrated calendar
 Axichat combines XMPP chat, email, calendar, reminders, and tasks in one
 privacy-focused desktop application without Firebase or trackers.
EOF

dpkg-deb --build --root-owner-group "${package_root}" "${package_file}"
echo "Created ${package_file}"
