# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Bash scripts that install and configure a personal Arch Linux desktop (Ryzen 5 3600, RTX 2060, NVMe, 16 GB RAM, linux-zen kernel, BTRFS, UEFI only). The desktop is Hyprland, and its dotfiles live in a separate repo, `my-hyprland` (github.com/DSanches92/my-hyprland).

Commit messages follow Conventional Commits written in Portuguese (`feat: ...`, `fix: ...`). Script comments and user-facing output are in pt-BR, so keep new text in Portuguese.

There is no build, lint config or test suite. To check scripts, use `bash -n <script>` and `shellcheck <script>` (shellcheck is not installed by default). The scripts are destructive (they partition disks, run `dd`, edit GRUB/mkinitcpio, install packages), so never run them on the host to test them. To test a piece of logic, pull it into a sandbox (a temporary `HOME`, a copy of the file being edited) or use a VM.

## Installation flow

The scripts run in sequence, each in a different context:

1. `make-bootable.sh <device> <iso> [--no-scripts]`: runs on an existing machine. It refuses the system disk (any partition mounted at `/`, `/boot`, `/boot/efi`, `/efi` or `/home`), unmounts the target's partitions, writes the ISO with `dd`, then copies the scripts listed in its `SCRIPTS` array onto the ISO's writable VFAT partition. **When you add a new script that must be on the USB stick, add it to `SCRIPTS`.**
2. `install-arch-linux.sh`: runs as root from the live USB. It is a single file with two parts, picked by `systemd-detect-virt --chroot`:
   - Part 1 (live): partitions the disk (GPT: 8G swap, 600M EFI, BTRFS root), creates the subvolumes `@`, `@home`, `@cache`, `@log` and `@.snapshots`, runs pacstrap/genfstab, writes the passwords to `/mnt/root/.chroot-creds` with `printf %q` under `umask 077` (a `trap` deletes the file on exit), copies itself into `/mnt/root`, and re-runs itself with `arch-chroot`.
   - Part 2 (chroot): sources and deletes the creds file, then sets up locale (pt_BR), keymap (br-abnt2), hostname, pacman.conf (multilib), sudoers, the user, GRUB, NetworkManager, ufw and systemd-timesyncd, and builds `paru` from the AUR. `timedatectl` does not work inside the chroot, so services are enabled with `systemctl enable` only.
3. `post-install.sh`: runs as a normal user after the first boot, never in chroot. It covers:
   - NVIDIA (`nvidia-open-dkms`, modules in mkinitcpio, `nvidia-drm.modeset=1` in GRUB, nouveau blacklisted) and PipeWire;
   - tuning: cpupower set to `powersave` + EPP `balance_performance` in `/etc/default/cpupower-service.conf`, `amd_pstate=active`, sysctl, the NVMe scheduler;
   - extra packages (samba, podman, wine);
   - Oh My Zsh with its plugins (autosuggestions, syntax-highlighting, histdb), plus nvm and bun from their official installers;
   - snapper, which reuses the existing `@.snapshots` subvolume by deleting the one `snapper create-config` makes.
4. `install-hyprland.sh`: runs as a normal user and requires `paru`. It installs packages, enables services (SDDM, bluetooth), then clones `my-hyprland` from GitHub (not from the local copy) into a temp dir and runs its `install.sh`. That script copies the configs into `~/.config`, applies the zsh config and installs the SDDM theme with sudo.
5. `install-gaming.sh` (optional): installs Steam, `proton-ge-custom-bin`, gamemode, MangoHud, gamescope and Lutris. It writes `~/.config/MangoHud/MangoHud.conf` inline. It also writes `~/.local/bin/steam-proton-default`, which sets Proton GE as Steam's default tool by editing only `CompatToolMapping."0"` in `config.vdf` with `python-vdf` (`VDFDict`). Before editing it backs up the file and refuses to run while Steam is open.

`install-i3wm.sh` is the legacy alternative to step 4 and is not maintained. Hyprland is the official flow.

## Conventions

- `set -euo pipefail`, ANSI color variables (`GREEN`/`CYAN`/`YELLOW`/`RED`/`NC`), numbered progress steps (`:: [n/N] ...`), and `paru -S --needed --noconfirm` for packages.
- Hardcoded settings (USERNAME, HOSTNAME, locale, GRUB params, CPU governor, nvm version) live in a config block near the top of each script.
- User-level scripts refuse to run as root. `post-install.sh` runs a background `sudo -v` keepalive with an EXIT trap.
- Back up files before editing them in place, using the suffix `.bak-<date>`.
- Under `set -e`, a bare `VAR=$(cmd)` that fails aborts the script, so wrap it as `if VAR=$(cmd); then ...` when a failure is expected.
- Installers that edit shell rc files (nvm, bun, `bun completions`) must not touch `~/.zshrc`. The user's shell config lives in `my-hyprland/zsh/danilo.zsh`.
- When a dotfile in `my-hyprland` needs a new program (keybind, autostart, waybar module), add the package to `install-hyprland.sh` too.
- Package names drift (`rofi-wayland` → `rofi`, `proton-ge-custom` → `proton-ge-custom-bin`). Check them with `paru -Si <pkg>` before adding or renaming.
