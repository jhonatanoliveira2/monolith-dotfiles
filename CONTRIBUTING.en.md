# Contribution guide

[Português (Brasil)](CONTRIBUTING.md) · **English**

Thank you for contributing to MONOLITH. Clear, verifiable and safe changes help keep the installer and configuration useful on other machines.

## Before opening a contribution

- Do not include tokens, credentials, private keys, email addresses, usernames or personal paths. Review the entire diff before submitting.
- Do not claim tests you did not run. State the environment you used and any checks that remain outstanding.
- User-facing text must be available in English and Brazilian Portuguese.
- Preserve third-party licenses and notices alongside the components they apply to.

## Project conventions

Scripts, comments, internal names and technical logs use English. Only user-facing messages are translated. Installer messages live in `scripts/lib/messages.sh`; keep placeholders in the same order in both languages.

Documentation is bilingual too. When changing a guide, update both corresponding files in `docs/` and keep commands, paths, options and technical identifiers identical. The pairs are `configuracao.md` and `config.md`, `dependencias.md` and `dependencies.md`, `instalacao.md` and `installation.md`, and `problemas-conhecidos.md` and `troubleshooting.md`; the NixOS guides use `name.md` and `name.pt-br.md` (`nixos`, `nothing-theme`).

The repository serves two systems with the same configuration in `configs/`: Arch Linux / CachyOS (installer in `scripts/`) and NixOS (flake in `nix/`). A change in `configs/` applies to both: do not hard-code one distribution's paths (`/usr/bin/...`), detect at run time (`core/Distro.qml`). The Nothing theme is optional and only exists when `~/.config/monolith/nothing.json` is present: without it the shell must not change.

When changing dependencies, update `packages.txt` (Arch) and `nix/packages.nix` or the modules in `nix/modules/nixos/` (NixOS) and explain why each package is needed. Do not promote commented references to active dependencies without confirming actual use.

## Checks

Run the relevant tests before submitting (the same ones CI runs on every push and pull request):

```bash
bash tests/lint.sh                   # bash -n, shellcheck, luacheck, Python and QML syntax
bash tests/test-docs.sh              # links, anchors, bilingual pairs, structure
bash tests/test-installer.sh         # Arch installer (temporary environments)
bash tests/test-nixos-install.sh     # NixOS guided installer (no disk is touched)
bash tests/test-shell.sh             # the shell's singletons without a compositor (needs quickshell)
nix flake check                      # with Nix only: builds the packages and evaluates an example machine
```

`tests/lint.sh` skips the tools that are not installed (`--strict` turns that into a failure).

The tests use temporary environments and never touch your session. If you change installer behaviour, add coverage to `tests/test-installer.sh`; if you change a shell service (`core/`, `services/`), to `tests/test-shell.sh`.

## Suggested workflow

1. Fork the project and create a focused branch such as `fix/...`, `feat/...` or `docs/...`.
2. Keep changes focused and write imperative commit messages.
3. Test what changed and report the actual results.
4. Open an [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) to report a problem or a repository contribution to propose a change.

## Screenshots and previews

Add screenshots under `assets/screenshots/`. Remove notifications and personal data before publishing. The READMEs use `1.png`, `2.png` and `3.png`. Installer previews are generated with `tools/ansi2svg.py`.
