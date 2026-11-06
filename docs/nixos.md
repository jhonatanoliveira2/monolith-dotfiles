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

**New configuration** (a flake with NixOS + Home Manager + MONOLITH):

```bash
mkdir ~/nixos && cd ~/nixos
nix flake init -t github:jhonatanoliveira2/monolith-dotfiles/feature/nixos-support
cp /etc/nixos/hardware-configuration.nix .
# edit configuration.nix: user name, hostname, keyboard, bootloader
sudo nixos-rebuild switch --flake .#monolith-pc
```

**Existing flake:** add the input and the module, then enable the options.

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
| `boot.grub.enable` | GRUB in use | GRUB theme |
| `boot.grub.resolution` | `"1920x1080"` | theme drawn for this size; GRUB's preferred mode (`,auto` fallback) |
| `boot.recovery` | `true` | extra boot entry "recovery" (no splash, verbose, text login) |
| `greeter.enable` | `false` | Quickshell greeter on greetd |
| `greeter.background` | `null` | wallpaper behind the login (black by default, continuous with the splash) |
| `greeter.defaultUser` / `defaultSession` | `null` / `"hyprland"` | used until a login is remembered |
| `greeter.allowOtherUsers` / `consoleSession` | `true` / `true` | type another user name / "Console" session |
| `greeter.clock24`, `animations`, `keyboard` | `true`, `true`, xkb layout | footer and behaviour |
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
| `wallpapers` | `true` | copy `wallpapers/` into `~/Pictures/Wallpapers` and `~/Videos/wallpaper-live` |
| `gtk` | `true` | `Materia-dark` and the dark colour scheme (dconf) |

## Boot, splash and login

The three stages share one visual line: black, the **NixOS snowflake drawn in the Monolith style** (light grey,
a faint halo, standing above a lit horizon), the `MONOLITH` wordmark in JetBrains Mono and a 2 px line.

1. **GRUB**: the mark and wordmark at the top, grey entries, the selected one white in a thin light frame (the
   shell's selected rows). The timeout is the 2 px line, emptying. Keys are listed at the bottom.
2. **Plymouth**: the mark fades in at the centre, a light sweep crosses it every few seconds and the line fills
   with the boot progress. Disk passwords and questions take the line's place; systemd messages show at the bottom.
3. **Greeter**: opens on Plymouth's last frame (same place, same size) — the splash is kept on screen until then
   (`plymouth quit --retain-splash`) — then the mark rises, the line fades and the clock and login appear.
   A successful login plays the light sweep, fades to black and starts the session.

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

For LUKS, `boot.initrd.systemd.enable = true` gives the cleanest password prompt in the splash; it is not forced
because it changes how the initrd runs custom scripts.

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
- **No splash with LUKS**: try `boot.initrd.systemd.enable = true`; check `boot.plymouth.enable`.
- **GRUB text too small or large**: set `monolith.boot.grub.resolution` to the screen's resolution.
