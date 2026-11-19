# Mini vMac Launcher

A small bash TUI for choosing which disk images to mount in native Mini vMac. It starts the emulator fullscreen and remembers your selection between runs. The interface is in English and calls the boot disk the **Startup Disk**, as the Mac does.

## Main features

- Recursive disk browser for `Disks/`, including subfolders.
- Selection is saved automatically in `.selected-disks`; the Startup Disk is passed to Mini vMac first.
- Read-only toggle for disk images, marked with `ø`.
- Opens Mini vMac on a new Hyprland desktop and returns to the previous one when it is empty.

## Installation

1. Clone the repo:
   ```sh
   git clone https://github.com/fedekrum/minivmac-launcher.git
   ```
2. Copy `minivmac-launcher.sh` into your Mini vMac directory, next to `minivmac`, `Mac-Plus.rom` and `Disks/`.
3. Make it executable:
   ```sh
   chmod +x minivmac-launcher.sh
   ```
4. Run it from a terminal with `./minivmac-launcher.sh`.

Supported disk image extensions: `.dsk`, `.disk`, `.img`, `.dmg`, `.dc42`, `.image`.

This repo contains only the launcher: the emulator binary, ROM and disk images are not included.

## Platforms

- **Linux** — primary platform, tested on Arch Linux with Hyprland. A terminal emulator (`foot` or `omarchy-launch-tui`) is used when launching from an application menu.
- **macOS** — works from a terminal with Bash 4+ (the system Bash 3.2 is too old). The Hyprland desktop feature does not apply.
- **Windows** — not supported directly; use WSL with a Linux Mini vMac build.
