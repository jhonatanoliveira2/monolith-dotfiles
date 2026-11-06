# MONOLITH on NixOS

[Português (Brasil)](nixos.pt-br.md) · **English**

The `feature/nixos-support` branch ships the MONOLITH Shell as a **Nix flake**: a NixOS module for the system
side, a Home Manager module for each user and, NixOS-only, a boot experience (GRUB theme, Plymouth splash and a
Quickshell greeter) that carries the shell's look from power-on to the desktop.

The Arch Linux / CachyOS installer is untouched and still works from this branch; on NixOS it stops and points
here, because copying files into `$HOME` would fight Home Manager.

## Contents

- [How it is built](#how-it-is-built)
- [Installing](#installing)
- [Options](#options)
- [Boot, splash and login](#boot-splash-and-login)
- [Differences from Arch](#differences-from-arch)
- [Checking and troubleshooting](#checking-and-troubleshooting)

## How it is built

One source tree serves both distributions; nothing in `configs/` is duplicated for Nix.

| Piece | Source | On NixOS |
|---|---|---|
| Shell (bar, menus, settings) | `configs/.config/quickshell/` | package `shell`, linked as `~/.config/quickshell` |
| Other configs (Hyprland, fish, ghostty...) | `configs/.config/*` | linked file by file from the Nix store |
| Files programs rewrite (btop, micro, nvim, GTK settings, wpgtk, HyprMod) | same | copied once, writable ("seeded") |
| `~/.local/bin` helpers | `configs/.local/bin/` | package `scripts` (tools on `PATH`), linked into `~/.local/bin` |
| THP-free start | `configs/.config/quickshell/scripts/start.sh` | `monolith-nothp` (a few lines of C, no python3) |
| Packages | `packages.txt` | `nix/packages.nix` (same groups) + NixOS services |
| Boot identity | `branding/` | packages `branding`, `plymouth-theme`, `grub-theme` |
| Greeter | `greeter/` + the shell's `Txt`, `Btn`, `Avatar` | package `greeter`, run by greetd |

```
flake.nix
nix/
  meta.nix              version / revision shown in Settings
  packages.nix          the packages.txt of NixOS
  pkgs/                 shell, scripts, nothp, branding, plymouth-theme, grub-theme, greeter
  modules/home.nix      programs.monolith (Home Manager)
  modules/nixos/        monolith.* (system.nix, boot.nix, greeter.nix)
  checks/               machine evaluated by `nix flake check`
branding/               snowflake mark composition, wordmark, Plymouth script, GRUB template, build.sh
greeter/                Quickshell greeter (shell.qml, GreeterWindow.qml, core/Theme.qml)
templates/nixos/        starting configuration (nix flake init -t)
```

The shell itself only gained distribution-neutral behaviour, so Arch keeps working: it recognises NixOS
(logo and name), finds the RNNoise plugin in Nix profiles, offers a Nix garbage collection in Settings > Storage,
keeps the battery charge limit in `/var/lib/monolith` when `/etc` is read-only, and reads
`~/.config/monolith/nix.json` (written by the Home Manager module) for Settings > System and Settings > Update.

## Installing

### Guided installer (NixOS ISO, recommended)

Boot the NixOS installer ISO (the minimal one is enough), connect to the network and run:

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support#install
```

It asks for the language, the target disk, user, hostname, time zone, locale, keyboard, disk encryption (LUKS)
and swap, shows a summary and only erases the disk after its name is typed back. Then it partitions
(GPT + 1 GiB EFI partition on UEFI, MBR on BIOS), formats ext4, runs `nixos-generate-config`, fills the
template with the answers, installs, sets the user's password (root stays locked: use `sudo`) and reboots.

- Safety: the ISO stick, mounted disks, disks in use (swap, LUKS, LVM, RAID) and disks under 20 GiB are never
  offered; `-- --dry-run` shows every command without changing anything.
- If the install stops after the disk was prepared (network, an error fixed on the branch), run the same command
  again: it offers to resume and fetches the latest version of the branch (`--refresh`).
- After installing: `sudo nixos-rebuild switch --flake /etc/nixos`.

### From the NixOS installer ISO, by hand

The live ISO has no `/etc/nixos/hardware-configuration.nix` yet: it is generated for the target disk after
partitioning. Flakes are also off on the ISO, hence `--extra-experimental-features`. Example for a UEFI machine
and one whole disk (`/dev/nvme0n1`, **erased**; check the name with `lsblk`):

```bash
sudo -i                                    # everything below as root
export NIX_CONFIG="experimental-features = nix-command flakes"
[ -d /sys/firmware/efi ] && echo UEFI || echo BIOS

# 1. partition, format, mount
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart root ext4 1GiB 100%
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot && mount -o umask=077 /dev/disk/by-label/boot /mnt/boot

# 2. hardware-configuration.nix for this machine (in /mnt/etc/nixos)
nixos-generate-config --root /mnt

# 3. the MONOLITH template next to it (it replaces the generated configuration.nix)
cd /mnt/etc/nixos && rm configuration.nix
nix flake init -t github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support
nano configuration.nix                     # user, hostname, time zone, keyboard (and BIOS, see the file)

# 4. install, set the user's password, reboot
nixos-install --flake /mnt/etc/nixos#monolith-pc
nixos-enter --root /mnt -c 'passwd alice'  # your user name: the greeter needs a password
reboot
```

On a BIOS machine use an msdos label and the root partition only, and in `configuration.nix` set
`boot.loader.grub.device = "/dev/sda"` (the disk), `efiSupport = false` and remove `canTouchEfiVariables`.

### On an installed NixOS

```bash
mkdir ~/nixos && cd ~/nixos
nix --extra-experimental-features "nix-command flakes" flake init -t github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support
cp /etc/nixos/hardware-configuration.nix .
# edit configuration.nix: user name, hostname, keyboard, bootloader (keep the one you already use)
sudo nixos-rebuild switch --flake .#monolith-pc
```

### Existing flake

Add the input and the module, then enable the options.

```nix
inputs.monolith = {
  url = "github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
# in nixosSystem { modules = [ ... ]; }
home-manager.nixosModules.home-manager
monolith.nixosModules.default
```

```nix
monolith = {
  enable = true;
  homeUsers = [ "alice" ];
  boot.enable = true;
  greeter.enable = true;
};
home-manager.backupFileExtension = "pre-monolith";
```

Standalone Home Manager works too: import `monolith.homeManagerModules.default` and set
`programs.monolith.enable = true`; the system still needs `programs.hyprland.enable` (or `monolith.enable`).

> Files already in `~/.config` (from an earlier manual install) block Home Manager. `backupFileExtension` renames
> them instead of failing.

## Options

### NixOS (`monolith.*`)

| Option | Default | What it does |
|---|---|---|
| `enable` | `false` | Hyprland, PipeWire, NetworkManager, Bluetooth + Blueman, UPower, udisks2, power-profiles-daemon, gvfs, polkit, portals (Hyprland + GTK), hyprlock PAM, fonts, gpu-screen-recorder |
| `language` | `"pt"` | `pt` or `en`: GRUB, Plymouth prompts, greeter |
| `homeUsers` | `[ ]` | users that get `programs.monolith.enable` (Home Manager NixOS module) |
| `battery.chargeLimit` | `null` | initial charge limit in %; Settings > Battery changes it later |
| `gpuScreenRecorder` | `true` | SUPER+R recording with the needed capabilities |
| `boot.enable` | `false` | the boot experience below |
| `boot.silent` | `true` | `quiet` and low log levels (messages stay in the journal) |
| `boot.plymouth.enable` | `true` | MONOLITH splash, also for LUKS passwords |
| `boot.seamless` | `true` | splash's last frame stays until the greeter draws the same frame |
| `boot.gpuModules` | `[ ]` | GPU driver in the initrd (`i915`, `xe`, `amdgpu`, `nouveau`...): the splash starts at once and is not cut when the driver loads; the guided installer fills it |
| `boot.splashMinSeconds` | `6` | minimum loading screen time: at startup the splash lasts until this many seconds after the kernel starts (fast NVMe boots), at reboot / power off at least this long; `0` = off. Initial value: **Settings › System › Startup** changes it without a rebuild (`/var/lib/monolith/splash-min-seconds`) |
| `boot.grub.enable` | GRUB in use | GRUB theme |
| `boot.grub.resolution` | `"1920x1080"` | theme drawn for this size; GRUB's preferred mode (`,auto` fallback) |
| `boot.recovery` | `true` | extra boot entry "recovery" (no splash, verbose, text login) |
| `greeter.enable` | `false` | Quickshell greeter on greetd |
| `greeter.background` | `null` | wallpaper behind the login (black by default, continuous with the splash) |
| `greeter.defaultUser` / `defaultSession` | `null` / `"hyprland"` | used until a login is remembered |
| `greeter.allowOtherUsers` / `consoleSession` | `true` / `true` | type another user name / "Console" session |
| `greeter.clock24`, `animations`, `keyboard` | `true`, `true`, xkb layout | footer and behaviour |
| `greeter.output` | `null` | with several monitors, the one showing the login (e.g. `"HDMI-A-1"`); the others show the night sky. `null` = the built-in panel unless the lid is closed, else the first monitor |
| `greeter.startTimeout`, `fallback` | `25`, `true` | seconds before the text greeter (tuigreet) takes over |

### Home Manager (`programs.monolith.*`)

| Option | Default | What it does |
|---|---|---|
| `enable` | `false` | configs, shell, helpers and packages |
| `optionalPackages` | `true` | the optional group of `packages.txt` (RNNoise, cava, pavucontrol, btop, neovim...) |
| `extraPackages` | `[ ]` | more packages |
| `apps` | `{ browser = "firefox"; }` | programs of the binds (`terminal`, `fileManager`, `ide`, `browser`, `lockScreen`) |
| `browserPackage` | `pkgs.firefox` | package for `apps.browser` (`null` if installed otherwise, e.g. Zen from its flake) |
| `updateCommand` | `null` | what Settings > Update > Update now runs in a terminal |
| `mutableFiles` | btop, micro, nvim, nwg-look, GTK settings, wpg, HyprMod | copied instead of linked |
| `fetch.enable` | `true` | [fetch](https://github.com/areofyl/fetch): the NixOS logo spinning in 3D next to the system info, in the MONOLITH greys (`~/.config/fetch/`). Run `fetch`; any key stops it, the mouse turns the logo |
| `fetch.atShellStart` | `false` | run `fetch` when fish opens (not on the Linux console; `MONOLITH_NO_FETCH=1` skips it) |
| `fetch.shadingMode`, `extraConfig` | `"ascii"`, `""` | `ascii` (the `#` relief), `blocks`, or `sextants` (sharpest, Ghostty / Kitty); extra lines for `~/.config/fetch/config` (e.g. `"speed=1.2"`) |
| `wallpapers` | `true` | copy `wallpapers/` into `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live` |
| `gtk` | `true` | `Materia-dark` and the dark colour scheme (dconf) |

## Boot, splash and login

The three stages share one visual line: black, the **NixOS snowflake drawn in the Monolith style** (light grey,
a faint halo, standing above a lit horizon), the `MONOLITH` wordmark in JetBrains Mono and a 2 px line.

1. **GRUB**: the mark and wordmark at the top, grey entries, the selected one white in a thin light frame (the
   shell's selected rows). The timeout is the 2 px line, emptying. Keys are listed at the bottom. Once an entry
   is chosen, the screen turns black with only the small snowflake in the bottom-right corner while the kernel
   loads, until the splash takes over.
2. **Plymouth**: the mark appears at the centre with a breathing bloom, a light sweep crosses it right away and
   then every ~2 s, and the line (with its own glow) fills with the boot progress. Shutdown and reboot show the
   mark at once. Disk passwords and questions take the line's place; systemd messages show at the bottom.
3. **Greeter**: opens on Plymouth's last frame (same place, same size) — the splash is kept on screen until then
   (`plymouth quit --retain-splash`) — then the mark rises and turns white with its bloom and a light sweep, the line fades,
   a night sky appears (star dust and stars drifting down in two layers, twinkles, sparkles, falling stars whose
   bloom fades as they cross) and the minimal login fades in: clock, user,
   a password line that glows when focused, the session and three power icons. A successful login flares the
   bloom, fades to black and starts the session.

The greeter authenticates through PAM (greetd): extra prompts (second factor, expired password) appear in the
same field. Up / Down choose the user, Ctrl+Left / Right the session, Esc cancels. The last user and session
are remembered in `/var/lib/monolith-greeter`. Profile pictures come from AccountsService.

**Recovery paths**

- GRUB keeps every generation, the configured timeout, `e` (edit the kernel line, e.g. remove `quiet`) and `c`.
- The **recovery** entry boots the same system without splash or graphical greeter, with full messages.
- Esc during the splash shows the boot log.
- If the greeter fails to load or shows nothing within `greeter.startTimeout`, **tuigreet** starts instead.
- The "Console" session gives a login shell; Ctrl+Alt+F2… reach the other consoles.
- Each stage can be turned off alone (`boot.plymouth.enable`, `boot.grub.enable`, `greeter.enable`).

With LUKS nothing else is needed: the initrd is always systemd-based (the scripted stage 1 and its
`boot.initrd.verbose` / `boot.initrd.systemd.enable` options were removed from nixpkgs), and it asks for the
password through the splash.

To see the boot menu without rebooting, `branding/preview-grub.sh` boots the real GRUB with the theme in QEMU
(a window, or `--shot file.png`; `--res` and `--lang` as in the options).

The splash scripts and images are built from `branding/` by `branding/build.sh`, which can be run by hand to
preview them (needs `rsvg-convert`, `magick`, `grub-mkfont` and the snowflake SVG from `nixos-icons`).

## Differences from Arch

| Arch / CachyOS | NixOS |
|---|---|
| `scripts/install.sh` copies `configs/`, installs packages | the flake: Home Manager links the files, NixOS enables the services |
| Settings > Update: `git pull` + installer | compares the pinned revision with GitHub; "Update now" runs `programs.monolith.updateCommand` |
| Settings > Storage: pacman / paru / yay caches | Nix store garbage collection (`nix-collect-garbage --delete-older-than 14d`, user + system), keeps recent generations |
| charge limit kept by a udev rule in `/etc` | kept in `/var/lib/monolith/charge-limit`, applied at boot by `monolith-charge-limit.service` |
| RNNoise "Install" button (pacman) | plugin installed by `optionalPackages`; found in the Nix profiles |
| `start.sh` uses python3 for THP | `monolith-nothp` |
| AUR: awww, mpvpaper, wpgtk, Material Icons | nixpkgs: `awww`, `mpvpaper`, `wpgtk`, `material-icons` |
| `zen-browser-bin` | not in nixpkgs: `apps.browser` (Firefox by default) |
| login / boot unchanged | GRUB theme, Plymouth splash, greeter (`monolith.boot`, `monolith.greeter`) |

Editing a linked file does not work (it is in the read-only store): change it in your fork of the repository, or
add it to `mutableFiles`. Everything the Settings app writes (`~/.config/hypr/generated/`,
`~/.local/state/quickshell-monolith/`) stays writable.

## Checking and troubleshooting

```bash
nix flake check                         # builds every package, evaluates a full example machine
nix build .#greeter .#grub-theme        # one package
nixos-rebuild build-vm --flake .#host   # try the whole boot in a VM
```

- **"Existing file ... is in the way"**: set `home-manager.backupFileExtension`.
- **The shell did not pick up a new version**: Home Manager swaps `~/.config/quickshell` atomically; restart the
  shell (log out, or `pkill quickshell` and start it from the launcher).
- **Greeter fell back to the text one**: `journalctl -u greetd -b` shows why (the wrapper logs the status).
- **No splash with LUKS**: check `monolith.boot.plymouth.enable` and that the GPU driver loads in the initrd
  (`boot.initrd.kernelModules`, e.g. `amdgpu`, `i915`).
- **GRUB text too small or large**: set `monolith.boot.grub.resolution` to the screen's resolution.
