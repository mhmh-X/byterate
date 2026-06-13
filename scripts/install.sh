#!/usr/bin/env bash
set -euo pipefail

APP_NAME="ByteRate"
REPO="mhmh-X/byterate"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
DOWNLOAD_URL="${BYTERATE_DOWNLOAD_URL:-https://github.com/${REPO}/releases/latest/download/${APP_NAME}.zip}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ByteRate only supports macOS." >&2
  exit 1
fi

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd curl
need_cmd ditto
need_cmd xattr
need_cmd open

run_maybe_sudo() {
  if [ -w "$INSTALL_DIR" ]; then
    "$@"
  else
    sudo "$@"
  fi
}

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

zip_path="$tmp_dir/${APP_NAME}.zip"
extract_dir="$tmp_dir/extract"
source_app="$extract_dir/${APP_NAME}.app"
target_app="$INSTALL_DIR/${APP_NAME}.app"

echo "Downloading ${APP_NAME}..."
curl -fL --retry 3 --retry-delay 1 "$DOWNLOAD_URL" -o "$zip_path"

mkdir -p "$extract_dir"
ditto -x -k "$zip_path" "$extract_dir"

if [ ! -d "$source_app" ]; then
  echo "Downloaded archive did not contain ${APP_NAME}.app." >&2
  exit 1
fi

echo "Installing to ${target_app}..."
run_maybe_sudo mkdir -p "$INSTALL_DIR"
run_maybe_sudo rm -rf "$target_app"
run_maybe_sudo ditto "$source_app" "$target_app"

echo "Removing Gatekeeper quarantine attribute..."
run_maybe_sudo xattr -dr com.apple.quarantine "$target_app" 2>/dev/null || true

if [ "${BYTERATE_NO_OPEN:-0}" != "1" ]; then
  open "$target_app"
fi

echo "${APP_NAME} installed successfully."
