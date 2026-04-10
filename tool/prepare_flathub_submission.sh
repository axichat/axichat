#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
git_ref="${AXICHAT_FLATHUB_GIT_REF:-HEAD}"
git_branch="${AXICHAT_FLATHUB_GIT_BRANCH:-}"
app_git_url="${AXICHAT_FLATHUB_APP_GIT_URL:-https://github.com/axichat/axichat.git}"
inputs_dir="${AXICHAT_FLATPAK_INPUTS_DIR:-${repo_root}/build/flatpak}"
sources_dir="${AXICHAT_FLATHUB_SOURCES_DIR:-${repo_root}/build/flathub-sources}"
submission_dir="${AXICHAT_FLATHUB_SUBMISSION_DIR:-${repo_root}/build/flathub-submission}"
manifest_template="${repo_root}/packaging/flatpak/im.axi.axichat.flathub.yml.in"
flathub_config_template="${repo_root}/packaging/flatpak/flathub.json"
prepare_inputs=1
inputs_url="${AXICHAT_FLATPAK_INPUTS_URL:-}"
inputs_archive_name="${AXICHAT_FLATPAK_INPUTS_ARCHIVE_NAME:-axichat-flatpak-inputs.tar.gz}"

usage() {
  cat <<'EOF'
Usage: ./tool/prepare_flathub_submission.sh [options]

This script prepares the files needed for a Flathub submission:
  - build/flathub-sources/axichat-flatpak-inputs.tar.gz
  - build/flathub-submission/im.axi.axichat.yml
  - build/flathub-submission/flathub.json

Options:
  --git-ref <ref>             Git tag/ref for the app source. Default: HEAD.
  --git-branch <branch>       Render the app source as branch+commit instead of
                              tag+commit. Useful for Linux-only Flathub fixes
                              that should not reuse or mint a cross-platform tag.
  --app-git-url <url>         Public git URL for the Axichat repo.
  --inputs-url <url>          Final public URL for the uploaded flatpak-inputs archive.
  --inputs-dir <dir>          Flatpak staging dir. Default: build/flatpak.
  --sources-dir <dir>         Output dir for archives. Default: build/flathub-sources.
  --submission-dir <dir>      Output dir for manifest files. Default: build/flathub-submission.
  --skip-prepare-inputs       Reuse an existing staged build/flatpak tree.
  -h, --help                  Show this help text.

Notes:
  - By default the app source is rendered as a pinned `type: git` source using
    the provided tag/ref plus its resolved commit.
  - If --git-branch is set, the app source is rendered using that branch plus
    the resolved commit for --git-ref.
  - If --inputs-url is omitted, a placeholder example.invalid URL is written
    into the manifest. Upload the archive, then rerun with the real URL.
EOF
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --git-ref)
      git_ref="$2"
      shift 2
      ;;
    --git-branch)
      git_branch="$2"
      shift 2
      ;;
    --app-git-url)
      app_git_url="$2"
      shift 2
      ;;
    --inputs-url)
      inputs_url="$2"
      shift 2
      ;;
    --inputs-dir)
      inputs_dir="$2"
      shift 2
      ;;
    --sources-dir)
      sources_dir="$2"
      shift 2
      ;;
    --submission-dir)
      submission_dir="$2"
      shift 2
      ;;
    --skip-prepare-inputs)
      prepare_inputs=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "Missing required tool: git." >&2
  exit 1
fi

if ! git -C "${repo_root}" rev-parse --verify "${git_ref}^{commit}" >/dev/null 2>&1; then
  echo "Unable to resolve git ref: ${git_ref}" >&2
  exit 1
fi

if [[ ! -f "${manifest_template}" ]]; then
  echo "Missing manifest template: ${manifest_template}" >&2
  exit 1
fi

if [[ ! -f "${flathub_config_template}" ]]; then
  echo "Missing Flathub config template: ${flathub_config_template}" >&2
  exit 1
fi

app_git_ref_field="tag"
app_git_ref_value="${git_ref}"
app_git_ref_label="tag/ref"

if [[ -n "${git_branch}" ]]; then
  app_git_ref_field="branch"
  app_git_ref_value="${git_branch}"
  app_git_ref_label="branch"
fi

app_git_commit="$(git -C "${repo_root}" rev-list -n 1 "${git_ref}")"

if [[ -z "${app_git_commit}" ]]; then
  echo "Unable to resolve commit for git ref: ${git_ref}" >&2
  exit 1
fi

if [[ -z "${inputs_url}" ]]; then
  inputs_url="https://example.invalid/${inputs_archive_name}"
fi

mkdir -p "${sources_dir}" "${submission_dir}"

if [[ "${prepare_inputs}" -eq 1 ]]; then
  "${repo_root}/tool/prepare_flatpak_inputs.sh" "${inputs_dir}"
fi

AXICHAT_FLATPAK_INPUTS_ARCHIVE_NAME="${inputs_archive_name}" \
AXICHAT_FLATPAK_INPUTS_URL="${inputs_url}" \
  "${repo_root}/tool/archive_flatpak_inputs.sh" "${inputs_dir}" "${sources_dir}"

inputs_archive_path="${sources_dir}/${inputs_archive_name}"
inputs_sha256="$(shasum -a 256 "${inputs_archive_path}" | awk '{print $1}')"

manifest_path="${submission_dir}/im.axi.axichat.yml"
sed \
  -e "s/__AXICHAT_APP_GIT_URL__/$(escape_sed_replacement "${app_git_url}")/g" \
  -e "s/__AXICHAT_APP_GIT_REF_FIELD__/$(escape_sed_replacement "${app_git_ref_field}")/g" \
  -e "s/__AXICHAT_APP_GIT_REF_VALUE__/$(escape_sed_replacement "${app_git_ref_value}")/g" \
  -e "s/__AXICHAT_APP_GIT_COMMIT__/$(escape_sed_replacement "${app_git_commit}")/g" \
  -e "s/__AXICHAT_FLATPAK_INPUTS_URL__/$(escape_sed_replacement "${inputs_url}")/g" \
  -e "s/__AXICHAT_FLATPAK_INPUTS_SHA256__/$(escape_sed_replacement "${inputs_sha256}")/g" \
  "${manifest_template}" > "${manifest_path}"

install -Dm644 "${flathub_config_template}" "${submission_dir}/flathub.json"

cat <<EOF
Prepared Flathub submission files
- App git URL: ${app_git_url}
- App git ${app_git_ref_label}: ${app_git_ref_value}
- App git resolved from ref: ${git_ref}
- App git commit: ${app_git_commit}
- Flatpak inputs archive: ${inputs_archive_path}
  SHA256: ${inputs_sha256}
- Manifest: ${manifest_path}
- Flathub config: ${submission_dir}/flathub.json

Upload the flatpak-inputs archive to a stable public URL and rerun with:
  --inputs-url <url>

Current manifest URLs:
- Flatpak inputs URL: ${inputs_url}
EOF
