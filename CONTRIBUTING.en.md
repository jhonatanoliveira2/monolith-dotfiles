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

Documentation is bilingual too. When changing a guide, update both corresponding files in `docs/` and keep commands, paths, options and technical identifiers identical. The pairs are `configuracao.md` and `config.md`, `Dependencias.md` and `dependencies.md`, `Instalacao.md` and `Installation.md`, and `Problemas-conhecidos.md` and `Troubleshooting.md`.

When changing dependencies, update `packages.txt` and explain why each package is needed. Do not promote commented references to active dependencies without confirming actual use.

## Checks

Run the relevant tests before submitting:

```bash
bash tests/test-installer.sh
bash tests/test-docs.sh
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do bash -n "$f"; done
```

If ShellCheck is available, also run:

```bash
shellcheck -x -S warning scripts/*.sh scripts/lib/*.sh
```

Installer tests use temporary environments. If you change installer behaviour, add corresponding coverage to `tests/test-installer.sh`.

## Suggested workflow

1. Fork the project and create a focused branch such as `fix/...`, `feat/...` or `docs/...`.
2. Keep changes focused and write imperative commit messages.
3. Test what changed and report the actual results.
4. Open an [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) to report a problem or a repository contribution to propose a change.

## Screenshots and previews

Add screenshots under `assets/screenshots/`. Remove notifications and personal data before publishing. `assets/screenshots/screenshot-slot.svg` is only a replaceable frame for the READMEs. Installer previews are generated with `tools/ansi2svg.py`; see the [visual assets guide](assets/VISUAL-GUIDE.md).
