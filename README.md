# GTA VI Clock & Countdown

A cross-platform desktop countdown to the release of **Grand Theft Auto VI** (19 November 2026), with the official Jason & Lucia artwork as wallpaper.

When the countdown reaches zero it turns into a clock showing the time, weekday and date.

One folder works on **Windows**, **macOS** and **Linux**: the installer detects your system by itself.

---

## Features

- **Wallpaper**: downloads the official Jason & Lucia artwork and the GTA VI logo from the Rockstar Games website and sets them as your wallpaper, with the logo in the top-right corner.
- **Countdown widget**: shows days, hours, minutes and seconds to the release, drawn on the desktop in the Pricedown font.
- **Clock mode**: after the release the widget becomes a clock with weekday and date.
- **Locked position**: the widget is locked so it is not moved by accident. Double-click it to unlock it, drag it, and it locks itself again (on KDE: right-click the desktop > *Enter Edit Mode*).
- **Clean uninstall**: restores your previous wallpaper and removes the widget and the font.

## Supported systems

| System  | Requirements | Countdown engine |
|---------|--------------|------------------|
| Windows | Windows 10 / 11 | [Rainmeter](https://www.rainmeter.net/) (installed automatically with `winget` if missing) |
| macOS   | macOS 11 Big Sur or newer | [Übersicht](https://tracesof.net/uebersicht/) (installed automatically with Homebrew if missing) |
| Linux   | One of the desktops listed below | Native widget for each desktop |

### Linux desktops

| Desktop | Countdown engine |
|---------|------------------|
| Cinnamon (X11 session) | Cinnamon desklet |
| GNOME 45+ | GNOME Shell extension (log out and back in after installing) |
| KDE Plasma 6 | Plasma widget (plasmoid) |
| COSMIC | GTK layer-shell overlay |
| Hyprland | GTK layer-shell overlay (adds an `exec-once` line to `~/.config/hypr/hyprland.conf`, removed on uninstall) |

Not supported: XFCE, MATE, LXQt, Budgie, KDE Plasma 5, Sway and others.

---

## Installation

### 1. Download the project

Either clone the repository:

```bash
git clone https://github.com/Leocap11/gta-6-clock-and-countdown.git
cd gta-6-clock-and-countdown
```

or click **Code > Download ZIP** on GitHub and extract it.

> Keep the folder after installing: you need it to uninstall.

### 2. Run the installer

#### Windows

1. Open the project folder.
2. Double-click **`install.bat`**.
3. If *"Windows protected your PC"* appears, click **More info > Run anyway**.
4. If Rainmeter is missing, the installer installs it with `winget`.

#### macOS

1. Open the project folder in Finder.
2. Right-click **`install.command`** > **Open** > **Open**.
3. If macOS asks to allow control of *"System Events"*, click **OK** (needed to set the wallpaper).
4. If Übersicht is missing, the installer installs it with Homebrew. Without Homebrew, download it from [tracesof.net/uebersicht](https://tracesof.net/uebersicht/) and run the installer again.
5. To start the countdown at every login: Übersicht menu bar icon > **Preferences** > **Launch Übersicht when I login**.

#### Linux

1. Install the dependencies for your distribution:

   ```bash
   # Debian / Ubuntu / Mint / Pop!_OS
   sudo apt install curl unzip python3-pil python3-gi python3-gi-cairo gir1.2-gtklayershell-0.1 x11-xserver-utils

   # Fedora
   sudo dnf install curl unzip python3-pillow python3-gobject gtk-layer-shell xrandr

   # Arch / Manjaro
   sudo pacman -S curl unzip python-pillow python-gobject gtk-layer-shell xorg-xrandr

   # openSUSE
   sudo zypper install curl unzip python3-Pillow python3-gobject-cairo typelib-1_0-GtkLayerShell-0_1 xrandr
   ```

   If something is still missing, the installer tells you which package to install.

2. Run the installer from the project folder:

   ```bash
   ./install.sh
   ```

3. On **GNOME**, log out and back in to activate the extension.

---

## Uninstallation

Uninstalling restores your previous wallpaper and removes the countdown widget and the font.

| System  | How to uninstall |
|---------|------------------|
| Windows | Double-click **`uninstall.bat`** |
| macOS   | Right-click **`uninstall.command`** > **Open** |
| Linux   | Run `./install.sh --uninstall` in the project folder |

Rainmeter (Windows) and Übersicht (macOS) are left installed: remove them yourself if you no longer need them (*Settings > Apps* on Windows, drag Übersicht to the Trash on macOS).

After uninstalling you can delete the project folder.

---

## Project structure

```
gta-6-clock-and-countdown/
├── install.sh              # entry point: detects the OS and runs the right installer
├── install.bat             # Windows install launcher
├── uninstall.bat           # Windows uninstall launcher
├── install.command         # macOS install launcher (double-clickable)
├── uninstall.command       # macOS uninstall launcher
├── windows/
│   ├── install.ps1         # Windows installer (PowerShell)
│   └── Skins/GTA6Countdown # Rainmeter skin
├── macos/
│   ├── install.sh          # macOS installer
│   └── gta6-countdown.widget  # Übersicht widget
└── linux/
    ├── install.sh          # Linux installer
    ├── compose_wallpaper.py   # puts the logo on the artwork
    ├── gsettings_list.py
    ├── desklet/            # Cinnamon desklet
    ├── gnome-extension/    # GNOME Shell extension
    ├── kde-plasmoid/       # KDE Plasma 6 widget
    └── wayland-overlay/    # GTK layer-shell overlay for COSMIC and Hyprland
```

## Troubleshooting

- **The wallpaper is not downloaded**: the images are fetched from the Rockstar Games website; if Rockstar changes its site the download URLs may stop working.
- **The countdown does not appear on GNOME**: log out and back in, then check that the extension is enabled in the *Extensions* app.
- **macOS blocks the script**: use right-click > *Open* instead of double-click, the first time only.

## Disclaimer

This is an unofficial fan project, not affiliated with or endorsed by Rockstar Games or Take-Two Interactive.

The artwork and logo belong to Rockstar Games; the Pricedown font belongs to Typodermic Fonts (free Desktop license). None of them is included in this repository: the installer downloads them from the original sources for personal use only.
