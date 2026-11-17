#!/usr/bin/env bash
set -euo pipefail

readonly PACKAGE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COUNTDOWN_UUID="gta6-countdown@vicountdown"
readonly PLASMOID_ID="org.vicountdown.gta6countdown"
readonly CONFIG_DIRECTORY="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly CINNAMON_DESKLET_DIRECTORY="$HOME/.local/share/cinnamon/desklets/$COUNTDOWN_UUID"
readonly GNOME_EXTENSION_DIRECTORY="$HOME/.local/share/gnome-shell/extensions/$COUNTDOWN_UUID"
readonly HYPRLAND_CONFIG_FILE="$CONFIG_DIRECTORY/hypr/hyprland.conf"
readonly AUTOSTART_FILE="$CONFIG_DIRECTORY/autostart/gta6-countdown.desktop"
readonly DATA_DIRECTORY="$HOME/.local/share/gta6-countdown"
readonly OVERLAY_FILE="$DATA_DIRECTORY/gta6_overlay.py"
readonly FONT_DIRECTORY="$HOME/.local/share/fonts"
readonly FONT_FILE="$FONT_DIRECTORY/Pricedown Bl.otf"
readonly FONT_INSTALLED_MARKER="$DATA_DIRECTORY/font-installed-by-script"
readonly INSTALLED_DESKTOP_FILE="$DATA_DIRECTORY/desktop"
readonly PREVIOUS_WALLPAPER_FILE="$DATA_DIRECTORY/previous-wallpaper"
readonly WALLPAPER_FILE="$DATA_DIRECTORY/wallpaper-with-logo.jpg"
readonly ROCKSTAR_MEDIA_URL="https://www.rockstargames.com/VI/_next/static/media"
readonly ARTWORK_URL="$ROCKSTAR_MEDIA_URL/an-extended-look.0zw.9~1j0ne~4.jpg"
readonly LOGO_TITLE_URL="$ROCKSTAR_MEDIA_URL/logo_gta.0h_86ilgw96eh.png"
readonly LOGO_NUMERAL_URL="$ROCKSTAR_MEDIA_URL/logo_vi.13u0vs8.9roug.png"
readonly FONT_ARCHIVE_URL="https://dl.dafont.com/dl/?f=pricedown"
readonly COUNTDOWN_HORIZONTAL_POSITION="0.1235"
readonly COUNTDOWN_VERTICAL_POSITION="0.486"
readonly FALLBACK_SCREEN_GEOMETRY="1920x1080+0+0"
readonly PACKAGE_HINTS="Install them with your distro's package manager:
  Debian/Ubuntu/Mint/Pop!_OS: sudo apt install curl unzip python3-pil python3-gi python3-gi-cairo gir1.2-gtklayershell-0.1 x11-xserver-utils
  Fedora:                     sudo dnf install curl unzip python3-pillow python3-gobject gtk-layer-shell xrandr
  Arch/Manjaro:               sudo pacman -S curl unzip python-pillow python-gobject gtk-layer-shell xorg-xrandr
  openSUSE:                   sudo zypper install curl unzip python3-Pillow python3-gobject-cairo typelib-1_0-GtkLayerShell-0_1 xrandr"

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

detect_desktop() {
    case "${XDG_CURRENT_DESKTOP:-}" in
        *Cinnamon*) echo "cinnamon" ;;
        *KDE*) echo "kde" ;;
        *COSMIC*) echo "cosmic" ;;
        *Hyprland*) echo "hyprland" ;;
        *GNOME*) echo "gnome" ;;
        *) fail "unsupported desktop (${XDG_CURRENT_DESKTOP:-unknown}). Supported: Cinnamon, GNOME, KDE Plasma 6, COSMIC, Hyprland." ;;
    esac
}

require_tools() {
    local missing_tools=()
    for tool in "$@"; do
        command -v "$tool" >/dev/null || missing_tools+=("$tool")
    done
    (( ${#missing_tools[@]} == 0 )) || fail "missing: ${missing_tools[*]}. $PACKAGE_HINTS"
}

require_pillow() {
    python3 -c "import PIL" 2>/dev/null || fail "missing: Python Pillow. $PACKAGE_HINTS"
}

require_gtk_layer_shell() {
    python3 -c "import cairo, gi; gi.require_version('Gtk', '3.0'); gi.require_version('GtkLayerShell', '0.1'); from gi.repository import Gtk, GtkLayerShell" 2>/dev/null \
        || fail "missing: GTK layer shell for Python (gtk-layer-shell, PyGObject, pycairo). $PACKAGE_HINTS"
}

require_desktop_support() {
    case "$1" in
        cinnamon)
            [[ "${XDG_SESSION_TYPE:-}" != "wayland" ]] || fail "the Cinnamon Wayland session is not supported: choose 'Cinnamon' (X11) at login."
            require_tools curl unzip python3 fc-cache gsettings dbus-send xrandr
            require_pillow
            ;;
        gnome)
            require_tools curl unzip python3 fc-cache gsettings gnome-shell
            require_pillow
            local gnome_major_version
            gnome_major_version="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
            (( gnome_major_version >= 45 )) || fail "GNOME 45 or newer is required (you have GNOME $gnome_major_version)."
            ;;
        kde)
            require_tools curl unzip python3 fc-cache dbus-send kpackagetool6 plasma-apply-wallpaperimage
            require_pillow
            ;;
        cosmic | hyprland)
            require_tools curl unzip python3 fc-cache
            require_gtk_layer_shell
            ;;
    esac
}

download() {
    local url="$1" destination="$2"
    curl --fail --silent --show-error --location --user-agent "Mozilla/5.0" --output "$destination" "$url" \
        || fail "download failed: $url (Rockstar may have changed its website)."
}

download_official_artwork() {
    local destination_directory="$1"
    echo "Downloading the official artwork and logo from the Rockstar website..."
    download "$ARTWORK_URL" "$destination_directory/artwork.jpg"
    download "$LOGO_TITLE_URL" "$destination_directory/logo-title.png"
    download "$LOGO_NUMERAL_URL" "$destination_directory/logo-numeral.png"
}

run_plasma_script() {
    dbus-send --session --print-reply=literal --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$1" \
        | sed -e 's/^[[:space:]]*//'
}

xrandr_primary_geometry() {
    command -v xrandr >/dev/null || return 0
    local geometry
    geometry="$(xrandr --current 2>/dev/null | grep -oP ' connected primary \K[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' || true)"
    [[ -n "$geometry" ]] || geometry="$(xrandr --current 2>/dev/null | grep -oP ' connected \K[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -1 || true)"
    echo "$geometry"
}

primary_monitor_geometry() {
    local desktop="$1" geometry=""
    if [[ "$desktop" == "kde" ]]; then
        geometry="$(run_plasma_script 'var area = screenGeometry(0); print(area.width + "x" + area.height + "+" + area.x + "+" + area.y);' || true)"
    else
        geometry="$(xrandr_primary_geometry)"
    fi
    [[ "$geometry" =~ ^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$ ]] || geometry="$FALLBACK_SCREEN_GEOMETRY"
    echo "$geometry"
}

install_font() {
    if fc-list : family | grep -i "pricedown" >/dev/null; then
        echo "Pricedown font already installed."
        return 1
    fi
    local archive_directory="$1/font"
    echo "Downloading the Pricedown font (free, Typodermic Desktop license)..."
    mkdir -p "$archive_directory" "$FONT_DIRECTORY"
    download "$FONT_ARCHIVE_URL" "$archive_directory/pricedown.zip"
    unzip -o -q "$archive_directory/pricedown.zip" -d "$archive_directory"
    cp "$archive_directory/Pricedown Bl.otf" "$FONT_FILE"
    fc-cache -f "$FONT_DIRECTORY"
    touch "$FONT_INSTALLED_MARKER"
}

edit_gsettings_list() {
    local schema="$1" key="$2" action="$3" entry="$4"
    gsettings set "$schema" "$key" "$(python3 -I "$PACKAGE_DIRECTORY/gsettings_list.py" "$action" "$(gsettings get "$schema" "$key")" "$entry")"
}

save_previous_wallpaper() {
    [[ -f "$PREVIOUS_WALLPAPER_FILE" ]] || echo "$1" > "$PREVIOUS_WALLPAPER_FILE"
}

install_for_cinnamon() {
    local monitor_x="$1" monitor_y="$2" screen_width="$3" screen_height="$4" font_was_installed="$5"
    edit_gsettings_list org.cinnamon enabled-desklets remove "$COUNTDOWN_UUID"
    mkdir -p "$CINNAMON_DESKLET_DIRECTORY"
    cp "$PACKAGE_DIRECTORY/desklet/metadata.json" "$PACKAGE_DIRECTORY/desklet/desklet.js" "$CINNAMON_DESKLET_DIRECTORY/"
    save_previous_wallpaper "$(gsettings get org.cinnamon.desktop.background picture-uri)"
    gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER_FILE"
    gsettings set org.cinnamon.desktop.background picture-options "zoom"
    local desklet_id desklet_x desklet_y
    desklet_id="$(gsettings get org.cinnamon next-desklet-id)"
    desklet_x="$(python3 -c "print(round($monitor_x + $screen_width * $COUNTDOWN_HORIZONTAL_POSITION))")"
    desklet_y="$(python3 -c "print(round($monitor_y + $screen_height * $COUNTDOWN_VERTICAL_POSITION))")"
    edit_gsettings_list org.cinnamon enabled-desklets add "$COUNTDOWN_UUID:$desklet_id:$desklet_x:$desklet_y"
    gsettings set org.cinnamon next-desklet-id "$((desklet_id + 1))"
    if [[ "$font_was_installed" == true ]]; then
        echo "Restarting Cinnamon to load the new font (your windows stay open)..."
        dbus-send --session --type=method_call --dest=org.Cinnamon /org/Cinnamon org.Cinnamon.RestartCinnamon boolean:false
    fi
    echo "Double-click the countdown to unlock it and drag it around."
}

install_for_gnome() {
    rm -rf "$GNOME_EXTENSION_DIRECTORY"
    mkdir -p "$GNOME_EXTENSION_DIRECTORY"
    cp "$PACKAGE_DIRECTORY/gnome-extension/metadata.json" "$PACKAGE_DIRECTORY/gnome-extension/extension.js" "$GNOME_EXTENSION_DIRECTORY/"
    save_previous_wallpaper "$(gsettings get org.gnome.desktop.background picture-uri)|$(gsettings get org.gnome.desktop.background picture-uri-dark)"
    gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_FILE"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_FILE"
    gsettings set org.gnome.desktop.background picture-options "zoom"
    gsettings set org.gnome.shell disable-user-extensions false
    edit_gsettings_list org.gnome.shell enabled-extensions add "$COUNTDOWN_UUID"
    echo "IMPORTANT: log out and log back in to make the countdown appear."
    echo "Double-click the countdown to unlock it and drag it around (if you use desktop icons, close your windows first)."
}

plasma_widget_script() {
    cat <<PLASMA_SCRIPT_END
desktops().filter(function (desktop) { return desktop.screen === 0; }).forEach(function (desktop) {
    desktop.widgets("$PLASMOID_ID").forEach(function (widget) { widget.remove(); });
    var area = screenGeometry(0);
    var scale = area.height / 1440;
    desktop.addWidget("$PLASMOID_ID",
        Math.round(area.width * $COUNTDOWN_HORIZONTAL_POSITION),
        Math.round(area.height * $COUNTDOWN_VERTICAL_POSITION),
        Math.round(720 * scale), Math.round(210 * scale));
});
PLASMA_SCRIPT_END
}

current_plasma_wallpaper() {
    run_plasma_script 'var desktop = desktops()[0]; desktop.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"]; print(desktop.readConfig("Image"));'
}

wait_for_plasmashell() {
    for attempt in $(seq 1 30); do
        run_plasma_script 'print("ok");' >/dev/null 2>&1 && return
        sleep 1
    done
    fail "plasmashell is not responding after the restart."
}

restart_plasmashell() {
    echo "Restarting Plasma to load the new font..."
    systemctl --user restart plasma-plasmashell.service 2>/dev/null \
        || { kquitapp6 plasmashell >/dev/null 2>&1 || true; (setsid plasmashell >/dev/null 2>&1 &); }
    sleep 3
    wait_for_plasmashell
}

install_for_kde() {
    local font_was_installed="$1"
    kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" >/dev/null 2>&1 || true
    kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIRECTORY/kde-plasmoid" >/dev/null
    save_previous_wallpaper "$(current_plasma_wallpaper)"
    [[ "$font_was_installed" == true ]] && restart_plasmashell
    plasma-apply-wallpaperimage "$WALLPAPER_FILE" >/dev/null
    run_plasma_script "$(plasma_widget_script)" >/dev/null
    echo "To move the countdown: right-click the desktop > Enter Edit Mode, then drag it."
}

stop_overlay() {
    pkill -f "python3 $OVERLAY_FILE" 2>/dev/null || true
}

start_overlay() {
    stop_overlay
    (setsid python3 "$OVERLAY_FILE" >/dev/null 2>&1 < /dev/null &)
}

install_overlay() {
    download_official_artwork "$DATA_DIRECTORY"
    cp "$PACKAGE_DIRECTORY/wayland-overlay/gta6_overlay.py" "$OVERLAY_FILE"
}

install_for_hyprland() {
    [[ -f "$HYPRLAND_CONFIG_FILE" ]] || fail "Hyprland config not found at $HYPRLAND_CONFIG_FILE."
    install_overlay
    grep -qF "$OVERLAY_FILE" "$HYPRLAND_CONFIG_FILE" || printf '\nexec-once = python3 %s\n' "$OVERLAY_FILE" >> "$HYPRLAND_CONFIG_FILE"
    start_overlay
    echo "Added an exec-once line to $HYPRLAND_CONFIG_FILE so the countdown starts at every login."
    echo "Double-click the countdown to unlock it and drag it around."
}

install_for_cosmic() {
    install_overlay
    mkdir -p "$(dirname "$AUTOSTART_FILE")"
    cat > "$AUTOSTART_FILE" <<AUTOSTART_END
[Desktop Entry]
Type=Application
Name=GTA VI Countdown
Exec=python3 $OVERLAY_FILE
X-GNOME-Autostart-enabled=true
AUTOSTART_END
    start_overlay
    echo "Double-click the countdown to unlock it and drag it around."
}

install_everything() {
    local desktop work_directory font_was_installed=false
    desktop="$(detect_desktop)"
    require_desktop_support "$desktop"
    echo "Detected desktop: $desktop"
    mkdir -p "$DATA_DIRECTORY"
    echo "$desktop" > "$INSTALLED_DESKTOP_FILE"
    work_directory="$(mktemp -d)"
    trap "rm -rf '$work_directory'" EXIT
    install_font "$work_directory" && font_was_installed=true
    case "$desktop" in
        cosmic) install_for_cosmic ;;
        hyprland) install_for_hyprland ;;
        *) install_with_composed_wallpaper "$desktop" "$work_directory" "$font_was_installed" ;;
    esac
    echo
    echo "Done! To remove everything: ./install.sh --uninstall"
}

install_with_composed_wallpaper() {
    local desktop="$1" work_directory="$2" font_was_installed="$3"
    local geometry screen_width screen_height monitor_x monitor_y
    geometry="$(primary_monitor_geometry "$desktop")"
    IFS='x+' read -r screen_width screen_height monitor_x monitor_y <<< "$geometry"
    echo "Primary screen: ${screen_width}x${screen_height}"
    download_official_artwork "$work_directory"
    python3 -I "$PACKAGE_DIRECTORY/compose_wallpaper.py" "$work_directory" "$WALLPAPER_FILE" "$screen_width" "$screen_height"
    case "$desktop" in
        cinnamon) install_for_cinnamon "$monitor_x" "$monitor_y" "$screen_width" "$screen_height" "$font_was_installed" ;;
        gnome) install_for_gnome ;;
        kde) install_for_kde "$font_was_installed" ;;
    esac
}

uninstall_for_cinnamon() {
    edit_gsettings_list org.cinnamon enabled-desklets remove "$COUNTDOWN_UUID"
    rm -rf "$CINNAMON_DESKLET_DIRECTORY"
    [[ -f "$PREVIOUS_WALLPAPER_FILE" ]] && gsettings set org.cinnamon.desktop.background picture-uri "$(tr -d "'" < "$PREVIOUS_WALLPAPER_FILE")"
    return 0
}

uninstall_for_gnome() {
    edit_gsettings_list org.gnome.shell enabled-extensions remove "$COUNTDOWN_UUID"
    rm -rf "$GNOME_EXTENSION_DIRECTORY"
    if [[ -f "$PREVIOUS_WALLPAPER_FILE" ]]; then
        local light_wallpaper dark_wallpaper
        IFS='|' read -r light_wallpaper dark_wallpaper < "$PREVIOUS_WALLPAPER_FILE"
        gsettings set org.gnome.desktop.background picture-uri "$(tr -d "'" <<< "$light_wallpaper")"
        gsettings set org.gnome.desktop.background picture-uri-dark "$(tr -d "'" <<< "$dark_wallpaper")"
    fi
}

uninstall_for_kde() {
    run_plasma_script "desktops().forEach(function (desktop) { desktop.widgets(\"$PLASMOID_ID\").forEach(function (widget) { widget.remove(); }); });" >/dev/null || true
    kpackagetool6 --type Plasma/Applet --remove "$PLASMOID_ID" >/dev/null 2>&1 || true
    if [[ -s "$PREVIOUS_WALLPAPER_FILE" ]]; then
        plasma-apply-wallpaperimage "$(sed 's|^file://||' "$PREVIOUS_WALLPAPER_FILE")" >/dev/null || true
    fi
}

uninstall_for_hyprland() {
    stop_overlay
    [[ -f "$HYPRLAND_CONFIG_FILE" ]] && sed -i "\|$OVERLAY_FILE|d" "$HYPRLAND_CONFIG_FILE"
    return 0
}

uninstall_for_cosmic() {
    stop_overlay
    rm -f "$AUTOSTART_FILE"
}

uninstall_everything() {
    [[ -f "$INSTALLED_DESKTOP_FILE" ]] || fail "nothing is installed."
    case "$(cat "$INSTALLED_DESKTOP_FILE")" in
        cinnamon) uninstall_for_cinnamon ;;
        gnome) uninstall_for_gnome ;;
        kde) uninstall_for_kde ;;
        cosmic) uninstall_for_cosmic ;;
        hyprland) uninstall_for_hyprland ;;
    esac
    if [[ -f "$FONT_INSTALLED_MARKER" ]]; then
        rm -f "$FONT_FILE"
        fc-cache -f "$FONT_DIRECTORY"
    fi
    rm -rf "$DATA_DIRECTORY"
    echo "Removed: countdown, wallpaper and font (if installed by the script). Previous wallpaper restored."
}

case "${1:-}" in
    --uninstall) uninstall_everything ;;
    "") install_everything ;;
    *) fail "unknown option: $1 (run without options to install, --uninstall to remove)" ;;
esac
