# Contribution guide

[Português (Brasil)](CONTRIBUTING.md) · **English**

Thank you for contributing to MONOLITH. This branch supports **NixOS only**; changes for Arch Linux / CachyOS go
to `main`.

## Before opening a contribution

- Do not include tokens, credentials, private keys, email addresses, usernames or personal paths. Review the entire diff before submitting.
- Do not claim tests you did not run. State the environment you used and any checks that remain outstanding.
- User-facing text must be available in English and Brazilian Portuguese.
- Preserve third-party licenses and notices alongside the components they apply to.

## Project conventions

Code, comments, internal names and technical logs use English. Only user-facing messages are translated (the
shell's `settings/Labels.qml` and `core/Strings.qml`, the installer's `t "pt" "en"` pairs).

Documentation is bilingual: when changing a guide, update both files and keep commands, paths, options and
technical identifiers identical. The pairs are `README.md` / `README.pt-br.md`, `CONTRIBUTING.en.md` /
`CONTRIBUTING.md` and the `docs/*.md` / `docs/*.pt-br.md` guides.

Packages go in `nix/packages.nix` (user programs) or the NixOS modules (`nix/modules/nixos/`, services); explain
why each one is needed.

## Checks

```bash
nix flake check                      # builds the packages and evaluates an example machine
bash tests/test-nixos-install.sh     # guided installer (no disk is touched)
bash tests/test-docs.sh              # links, anchors and bilingual pairs
bash -n nix/install/monolith-install.sh
```

## Suggested workflow

1. Fork the project and create a focused branch such as `fix/...`, `feat/...` or `docs/...`.
2. Keep changes focused and write imperative commit messages.
3. Test what changed (a `nixos-rebuild build` of a real configuration when modules change) and report the actual results.
4. Open an [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) to report a problem or a pull request to propose a change.
