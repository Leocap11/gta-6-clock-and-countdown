#!/usr/bin/env bash
set -euo pipefail

ROOT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_windows_installer() {
    local uninstall_option=()
    [[ "${1:-}" == "--uninstall" ]] && uninstall_option=(-Uninstall)
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT_DIRECTORY/windows/install.ps1")" "${uninstall_option[@]}"
}

case "$(uname -s)" in
    Linux) exec bash "$ROOT_DIRECTORY/linux/install.sh" "$@" ;;
    Darwin) exec bash "$ROOT_DIRECTORY/macos/install.sh" "$@" ;;
    MINGW* | MSYS* | CYGWIN*) run_windows_installer "$@" ;;
    *) echo "ERROR: unsupported operating system ($(uname -s))." >&2; exit 1 ;;
esac
