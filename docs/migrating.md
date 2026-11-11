# Updating from an old branch

[Português (Brasil)](migracao.md) · **English**

Everything that lived on `feature/nixos-support`, `feature/nothing-theme` and `unify/main` is now in **`main`**,
and those branches were removed from GitHub. Arch Linux / CachyOS and NixOS are both installed from `main`.
Find your case below; each one takes a minute.

| You installed from | What to do |
|---|---|
| `main`, Arch Linux / CachyOS | [Arch: from `main`](#arch-linux--cachyos-from-main) - a normal update |
| another branch, Arch Linux / CachyOS | [Arch: from another branch](#arch-linux--cachyos-from-another-branch) |
| `feature/nixos-support`, `feature/nothing-theme` or `?ref=unify/main`, NixOS | [NixOS](#nixos) |

## Arch Linux / CachyOS from `main`

`main` moved forward without rewriting history, so a plain update works:

```sh
cd ~/monolith-dotfiles          # your clone
git pull --ff-only
./scripts/install.sh
```

Or **Settings > Update**. The installer now asks for the theme (default or [Nothing](nothing-theme.md)); your
files are backed up first, as always.

## Arch Linux / CachyOS from another branch

**Settings > Update** fails with `couldn't find remote ref ...`, because the branch is gone. Move the clone to `main`:

```sh
cd ~/monolith-dotfiles
git stash                       # only if you changed files in the clone
git fetch origin --prune
git switch main                 # or: git switch -c main --track origin/main
git pull --ff-only
git branch -D unify/main 2>/dev/null; git branch -D feature/nothing-theme feature/nixos-support 2>/dev/null
./scripts/install.sh
```

`git stash pop` brings your changes back afterwards.

## NixOS

The `monolith` input of `/etc/nixos/flake.nix` still names the old branch, so `nix flake update` (and
Settings > Update) fails. The `flake.lock` still pins the old commit, so the system keeps booting and rebuilding;
only updates stop. Point the input at `main`:

```sh
sudo sed -i -E 's#monolith-dotfiles(/feature/(nixos-support|nothing-theme)|\?ref=unify/main)#monolith-dotfiles#' /etc/nixos/flake.nix
grep -n 'monolith-dotfiles' /etc/nixos/flake.nix     # url = "github:jhonatanoliveira2/monolith-dotfiles";
sudo nix flake update monolith --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos
```

What changes:

- **Nothing theme:** it was on by default on `feature/nothing-theme`; on `main` it is off unless chosen. To keep it,
  add `nothingTheme.enable = true;` to the `monolith = { ... };` block of `/etc/nixos/configuration.nix` (or
  `monolith.nothingTheme.enable = true;` outside it) before rebuilding.
- **Bar:** its position and style are already saved in your settings and stay as they are.
- New installs: `sudo nix --extra-experimental-features "nix-command flakes" run github:jhonatanoliveira2/monolith-dotfiles#install`
  (no `?ref=` needed).

## Something else

If a step fails, see [troubleshooting](troubleshooting.md) or open an
[issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) with the command and its output.
