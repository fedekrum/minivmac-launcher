# Mini vMac Launcher

A small, pure-bash terminal launcher for [Mini vMac](https://www.gryphel.com/c/minivmac/). It lets you pick which disk images to mount before starting the emulator, then launches Mini vMac fullscreen on a fresh desktop.

The interface is entirely in English and uses Mac terminology: the boot disk is called the **Startup Disk**.

## What it does

- Scans `Disks/` recursively, including subfolders, for disk images.
- Shows a compact tree: folders can be expanded and collapsed with `Space`.
- Remembers your selection in `.discos-seleccionados` (paths relative to `Disks/`); the first line is the Startup Disk and is passed to Mini vMac first.
- Lets you mark a Startup Disk with `S`. `Enter` requires at least one selected disk and a selected Startup Disk.
- Shows recursive counts on every folder, for example `(2 disks, 1 selected)`, so you can see selections inside collapsed folders.
- Empty folders close automatically while you navigate: going up closes a folder when you reach its header; going down closes it after you pass its last disk. Folders containing a selected disk stay open.
- Can mark a disk as read-only with `L`. This only changes the file permissions (`a-w` / `u+w`): Mini vMac fails to open it for writing and mounts it locked. Locked disks are marked with `ø`.
- If running under Hyprland, starts the emulator on a new desktop and returns to the previous one if that desktop is left empty.

## Layout

Put `iniciar.sh` in the same directory as your native Mini vMac setup:

```
minivmac/
├── iniciar.sh
├── minivmac
├── Mac-Plus.rom
└── Disks/
    ├── System 6.0.8.dsk
    └── originales/
        └── Game.dsk
```

Run it from a terminal with `./iniciar.sh`, or launch it from your application menu (a terminal will be opened for you if needed).

Supported disk image extensions: `.dsk`, `.disk`, `.img`, `.dmg`, `.dc42`, `.image`. Folders with no disk images inside are not shown.

The launcher itself does not contain the emulator, the ROM, or any disk images.

## Keys

```
┌─ Shortcuts ──────────────────────────────┐
│ [↑/↓] move              [S] Startup Disk │
│ [Space] Select          [Enter] start    │
│ [Ctrl+A] all/none       [Esc] cancel     │
│ [L] lock                                 │
└──────────────────────────────────────────┘
```

- `[Space]` selects/deselects a disk, or expands/collapses a folder.
- `[S]` marks the current disk as the Startup Disk.
- `[Ctrl+A]` selects all disks, or none. Selecting all again restores the last Startup Disk.
- `[Enter]` saves the selection and starts Mini vMac.
- `[Esc]` cancels without saving or starting anything.
- `[L]` toggles write permission on the current disk (`ø` means locked/read-only).

Unselecting the Startup Disk clears its mark; selecting it again restores it. If nothing is selected and you check a disk, that disk becomes the Startup Disk.

## Requirements

- Bash and a UTF-8 terminal.
- A native Mini vMac binary and ROM, named `minivmac` and `Mac-Plus.rom` in the same directory.
- Hyprland is optional; it is only used for the separate desktop.
