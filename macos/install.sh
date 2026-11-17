#!/bin/bash
set -euo pipefail

PACKAGE_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
WIDGETS_DIRECTORY="$HOME/Library/Application Support/Übersicht/widgets"
WIDGET_DIRECTORY="$WIDGETS_DIRECTORY/gta6-countdown.widget"
DATA_DIRECTORY="$HOME/Library/Application Support/GTA6Countdown"
WALLPAPER_FILE="$DATA_DIRECTORY/wallpaper.jpg"
PREVIOUS_WALLPAPER_FILE="$DATA_DIRECTORY/previous-wallpaper"
FONT_FILE="$HOME/Library/Fonts/Pricedown Bl.otf"
FONT_INSTALLED_MARKER="$DATA_DIRECTORY/font-installed-by-script"
ROCKSTAR_MEDIA_URL="https://www.rockstargames.com/VI/_next/static/media"
ARTWORK_URL="$ROCKSTAR_MEDIA_URL/an-extended-look.0zw.9~1j0ne~4.jpg"
LOGO_TITLE_URL="$ROCKSTAR_MEDIA_URL/logo_gta.0h_86ilgw96eh.png"
LOGO_NUMERAL_URL="$ROCKSTAR_MEDIA_URL/logo_vi.13u0vs8.9roug.png"
FONT_ARCHIVE_URL="https://dl.dafont.com/dl/?f=pricedown"

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

download() {
    curl --fail --silent --show-error --location --user-agent "Mozilla/5.0" --output "$2" "$1" \
        || fail "download failed: $1 (Rockstar may have changed its website)."
}

uebersicht_is_installed() {
    [[ -d "/Applications/Übersicht.app" || -d "$HOME/Applications/Übersicht.app" ]]
}

install_uebersicht() {
    uebersicht_is_installed && return
    command -v brew >/dev/null || fail "install Übersicht from https://tracesof.net/uebersicht/ and run the script again."
    echo "Installing Übersicht with Homebrew..."
    brew install --cask ubersicht
}

current_wallpaper() {
    osascript -e 'tell application "System Events" to get picture of desktop 1'
}

set_wallpaper() {
    osascript -e "tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$1\""
}

install_font() {
    if [[ -f "$FONT_FILE" ]]; then
        echo "Pricedown font already installed."
        return
    fi
    echo "Downloading the Pricedown font (free, Typodermic Desktop license)..."
    download "$FONT_ARCHIVE_URL" "$1/pricedown.zip"
    unzip -o -q "$1/pricedown.zip" -d "$1/font"
    mkdir -p "$HOME/Library/Fonts"
    cp "$1/font/Pricedown Bl.otf" "$FONT_FILE"
    touch "$FONT_INSTALLED_MARKER"
}

install_widget() {
    echo "Downloading the official artwork and logo from the Rockstar website..."
    mkdir -p "$WIDGET_DIRECTORY"
    cp "$PACKAGE_DIRECTORY/gta6-countdown.widget/index.jsx" "$WIDGET_DIRECTORY/"
    download "$LOGO_TITLE_URL" "$WIDGET_DIRECTORY/logo-title.png"
    download "$LOGO_NUMERAL_URL" "$WIDGET_DIRECTORY/logo-numeral.png"
    download "$ARTWORK_URL" "$WALLPAPER_FILE"
}

restart_uebersicht() {
    osascript -e 'tell application "Übersicht" to quit' >/dev/null 2>&1 || true
    sleep 2
    open -a "Übersicht"
}

install_everything() {
    [[ "$(uname)" == "Darwin" ]] || fail "this script is for macOS."
    local work_directory
    work_directory="$(mktemp -d)"
    trap "rm -rf '$work_directory'" EXIT
    install_uebersicht
    mkdir -p "$DATA_DIRECTORY"
    install_widget
    install_font "$work_directory"
    [[ -f "$PREVIOUS_WALLPAPER_FILE" ]] || current_wallpaper > "$PREVIOUS_WALLPAPER_FILE"
    set_wallpaper "$WALLPAPER_FILE"
    restart_uebersicht
    echo
    echo "Done! Double-click the countdown to unlock it and drag it around."
    echo "To start Übersicht at every login: Übersicht menu bar icon > Preferences > Launch Übersicht when I login."
    echo "To remove everything: right-click uninstall.command > Open"
}

remove_everything() {
    rm -rf "$WIDGET_DIRECTORY"
    if [[ -f "$PREVIOUS_WALLPAPER_FILE" ]]; then
        set_wallpaper "$(cat "$PREVIOUS_WALLPAPER_FILE")"
    fi
    if [[ -f "$FONT_INSTALLED_MARKER" ]]; then
        rm -f "$FONT_FILE"
    fi
    rm -rf "$DATA_DIRECTORY"
    echo "Removed: countdown, logo, wallpaper and font (if installed by the script). Previous wallpaper restored."
    echo "Übersicht is still installed: if you do not need it, drag it from Applications to the Trash."
}

case "${1:-}" in
    --uninstall) remove_everything ;;
    "") install_everything ;;
    *) fail "unknown option: $1 (run without options to install, --uninstall to remove)" ;;
esac
