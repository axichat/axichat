#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bundle_dir="${1:-${repo_root}/build/linux/x64/release/bundle}"
raw_version="${2:-}"
output_dir="${3:-${repo_root}/dist}"
architecture="${AXICHAT_DEB_ARCH:-amd64}"
package_name_display="Axichat"
package_summary="Open-source XMPP and email client with calendar"

append_linux_long_description() {
  cat <<'EOF'
 Axichat is a free open source SMTP (email) and XMPP (chat) client with cutting-edge UI.
 .
 You can self-host your own email and XMPP server for Axichat if you want extra privacy and control.
 .
 Feature highlights:
 - Unified inbox for chat + email
 - Sync across all your devices (mobile and desktop)
 - Easy drag-and-drop calendar
 .
 Axichat is still under active development, so things may break.
EOF
}

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
binary_package_name="axichat"
package_root="${repo_root}/build/linux/deb/${package_name}"
install_root="${package_root}/opt/axichat"
desktop_file="${repo_root}/linux/im.axi.axichat.desktop"
icon_file="${repo_root}/assets/icons/generated/app_icon_linux.png"
package_file="${output_dir}/${package_name}.deb"
substvars_file="${package_root}/DEBIAN/substvars"
binary_control_file="${package_root}/DEBIAN/control"
source_control_file="${package_root}/debian/control"

rm -rf "${package_root}"
mkdir -p "${install_root}" "${package_root}/DEBIAN" "${package_root}/debian" "${output_dir}"

cp -R "${bundle_dir}/." "${install_root}/"
mkdir -p "${package_root}/usr/bin"
cat > "${package_root}/usr/bin/axichat" <<'EOF'
#!/usr/bin/env sh
set -eu
cd /opt/axichat
exec /opt/axichat/axichat "$@"
EOF
chmod 755 "${package_root}/usr/bin/axichat"
install -Dm644 "${desktop_file}" "${package_root}/usr/share/applications/im.axi.axichat.desktop"
install -Dm644 "${icon_file}" "${package_root}/usr/share/icons/hicolor/256x256/apps/im.axi.axichat.png"

cat > "${source_control_file}" <<EOF
Source: ${binary_package_name}
Section: net
Priority: optional
Maintainer: Axichat <support@axi.chat>
Standards-Version: 4.6.2

Package: ${binary_package_name}
Architecture: ${architecture}
Description: ${package_name_display}
EOF

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
      "--package=${binary_package_name}"
      "-T${substvars_file}"
      "-l${install_root}"
      "-l${install_root}/lib"
    )

    # The Linux bundle carries its own WPE stack. Keep the .deb dependent on
    # the system libraries those bundled binaries still need, but do not force
    # installation of the same WPE packages again.
    if [[ -e "${install_root}/lib/libWPEWebKit-2.0.so.1" ]]; then
      dpkg_shlibdeps_args+=(
        "-xlibwpewebkit-2.0-1"
        "-xlibwpe-1.0-1"
        "-xlibwpebackend-fdo-1.0-1"
      )
    fi

    for target in "${elf_targets[@]}"; do
      dpkg_shlibdeps_args+=("-e${target}")
    done
    (
      cd "${package_root}"
      dpkg-shlibdeps "${dpkg_shlibdeps_args[@]}"
    )
    depends="$(
      awk '
        index($0, "shlibs:Depends=") == 1 {
          sub(/^shlibs:Depends=/, "", $0)
          print
          exit
        }
      ' "${substvars_file}"
    )"
  fi
fi

cat > "${binary_control_file}" <<EOF
Package: ${binary_package_name}
Version: ${version}
Section: net
Priority: optional
Architecture: ${architecture}
Maintainer: Axichat <support@axi.chat>
Homepage: https://axi.chat
EOF

if [[ -n "${depends}" ]]; then
  printf 'Depends: %s\n' "${depends}" >> "${binary_control_file}"
fi

cat >> "${binary_control_file}" <<EOF
Description: ${package_summary}
EOF

append_linux_long_description >> "${binary_control_file}"

dpkg-deb --build --root-owner-group "${package_root}" "${package_file}"
echo "Created ${package_file}"
