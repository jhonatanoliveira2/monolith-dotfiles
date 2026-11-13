# Contribution guide

[Português (Brasil)](CONTRIBUTING.md) · **English**

Thank you for contributing to MONOLITH. Clear, verifiable and safe changes help keep the installer and configuration useful on other machines.

## Before opening a contribution

- Do not include tokens, credentials, private keys, email addresses, usernames or personal paths. Review the entire diff before submitting.
- Do not claim tests you did not run. State the environment you used and any checks that remain outstanding.
- Write in the language you prefer, English or Brazilian Portuguese: code, interface text and documentation. A translation to the other one is welcome, never required.
- Preserve third-party licenses and notices alongside the components they apply to.

## Project conventions

The existing code uses English for scripts, comments, internal names and technical logs; following that helps, but it is not a rule. Installer messages live in `scripts/lib/messages.sh` (`_m key "English" ["Portuguese"]`), the shell's in `core/Strings.qml` and `settings/Labels.qml`. A text written in one language is shown in that language until someone translates it; when both exist, keep the placeholders in the same order.

Most guides in `docs/` exist in both languages (for instance `installation.md` and `instalacao.md`, `nixos.md` and `nixos.pt-br.md`). When changing a guide you may change only the version in your language, and a new guide may exist in one language only. If you update both, keep commands, paths and options identical.

The repository serves two systems with the same configuration in `configs/`: Arch Linux / CachyOS (installer in `scripts/`) and NixOS (flake in `nix/`). A change in `configs/` applies to both: do not hard-code one distribution's paths (`/usr/bin/...`), detect at run time (`core/Distro.qml`). The Nothing theme is optional and only exists when `~/.config/monolith/nothing.json` is present (written by Nix or by `scripts/nothing-theme.sh`, from the same files of `nix/nothing/`): without it the shell must not change.

When changing dependencies, update `packages.txt` (Arch) and `nix/packages.nix` or the modules in `nix/modules/nixos/` (NixOS) and explain why each package is needed. Do not promote commented references to active dependencies without confirming actual use.

## Checks

Run the relevant tests before submitting (the same ones CI runs on every push and pull request):

```bash
bash tests/lint.sh                   # bash -n, shellcheck, luacheck, Python and QML syntax
bash tests/test-docs.sh              # links, anchors, structure
bash tests/test-installer.sh         # Arch installer (temporary environments)
bash tests/test-nixos-install.sh     # NixOS guided installer (no disk is touched)
bash tests/test-scripts.sh           # the shell's helper scripts (fake curl, no network)
bash tests/test-shell.sh             # the shell's singletons without a compositor (needs quickshell)
bash tests/smoke-shell.sh            # the whole shell in a nested Hyprland (opens a window for ~40 s; --nothing = with the theme)
nix flake check                      # with Nix only: builds the packages and evaluates an example machine
```

`tests/lint.sh` skips the tools that are not installed (`--strict` turns that into a failure).

The tests use temporary environments and never touch your session. If you change installer behaviour, add coverage to `tests/test-installer.sh`; if you change a shell service (`core/`, `services/`), to `tests/test-shell.sh`.

## Suggested workflow

1. Fork the project and create a focused branch such as `fix/...`, `feat/...` or `docs/...`.
2. Keep changes focused and write imperative commit messages.
3. Test what changed and report the actual results.
4. Open an [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) to report a problem or a repository contribution to propose a change.

## Previews

The README's previews live in `assets/previews/` and are generated from the real programs by `python3 tools/previews.py` (needs fastfetch, fish, `script` and Python with Pillow and numpy; `--only default/nautilus` redoes one). `default/` holds the default theme and `nothing/` the optional Nothing theme; the photo of the Nothing wallpaper preview is `assets/previews/src/night-peaks.jpg`. The fastfetch previews always show NixOS (fixed distribution, kernel and package rows). They never show the user's name or hostname; check the result before sending, and remove personal data from any new image.
