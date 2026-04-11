#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?version required}"
SHA="${2:?sha required}"
DEFAULT_URL='https://github.com/Arthur-Ficial/apfel-quick/releases/download/v#{version}/apfel-quick-macos-arm64.zip'
URL="${APP_URL_OVERRIDE:-$DEFAULT_URL}"

sed \
    -e "s/__VERSION__/${VERSION}/g" \
    -e "s/__SHA256__/${SHA}/g" \
    -e "s|__URL__|${URL}|g" \
    "$ROOT_DIR/Packaging/Homebrew/apfel-quick.rb.template"
