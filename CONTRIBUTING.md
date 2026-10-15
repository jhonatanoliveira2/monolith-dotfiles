# Contribuindo

[Português (Brasil)](CONTRIBUTING.md) · [English](CONTRIBUTING.en.md)

Obrigado por querer ajudar! Este projeto é um instalador + documentação para um ambiente Arch/Hyprland.

## Regras de ouro

1. **Não envie dados pessoais nem segredos** (tokens, e-mails, caminhos com seu usuário, backups do `micro`,
   `fish_variables`…). Veja [`.gitignore`](.gitignore) e [configuracao.md](docs/configuracao.md#arquivos-deixados-de-fora).
2. **Não afirme testes que você não executou.** No PR, diga em que sistema testou (Arch real, VM, contêiner)
   e o que *não* testou.
3. **Dois idiomas sempre.** Todo texto para o usuário existe em português do Brasil **e** inglês.

## Convenções

- **Idioma do código:** scripts, comentários, variáveis, identificadores internos, chaves de mensagens e logs
  técnicos em **inglês**. Só os textos mostrados ao usuário são traduzidos.
- **Mensagens:** adicione com `_m chave "English" "Português"` em `scripts/lib/messages.sh`; mantenha os
  `%s` na mesma ordem nas duas línguas. Use `t chave args…` nos scripts.
- **Bash:** `set -Eeuo pipefail`, aspas em variáveis, sem `eval`, sem `rm -rf` sobre caminhos não validados,
  `local` em funções. Compatível com Bash 4.4+.
- **Segurança do instalador:** nada em `$HOME` muda antes do backup; toda gravação é atômica e entra no
  *journal* de reversão; nunca apague arquivos do usuário; nunca peça root sem necessidade.
- **Documentação:** `docs/*.md` (PT-BR) e `docs/*.en.md` (EN) mudam juntos. Comandos, caminhos e
  identificadores técnicos devem ser **idênticos** nos dois idiomas.
- **Dependências:** edite `packages.txt` indicando o **motivo** (qual atalho/script/módulo exige o pacote). Não
  promova itens que só aparecem em comentários.

## Ambiente e testes

```bash
bash tests/test-installer.sh                          # como usuário comum (não root)
bash tests/test-docs.sh                               # links, âncoras e pares bilíngues
shellcheck -x -S warning scripts/*.sh scripts/lib/*.sh
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do bash -n "$f"; done
```

Os testes usam *fixtures* temporárias e **nunca** tocam seu `~/.config`. Se mudar o comportamento do
instalador, adicione um teste em `tests/test-installer.sh`.

## Fluxo

1. Faça um *fork* e crie um branch (`fix/…`, `feat/…`, `docs/…`).
2. Commits pequenos, mensagens no imperativo (`Add …`, `Fix …`).
3. Abra o PR com o [modelo](.github/PULL_REQUEST_TEMPLATE.md) e marque a checklist com honestidade.
4. Para bugs, use o modelo de *issue* e anexe o log (sem dados pessoais).

## Capturas de tela e prévias

Coloque suas capturas em `assets/screenshots/` (sem dados pessoais visíveis). As prévias SVG do instalador
são geradas por `tools/ansi2svg.py` — veja [assets/README.md](assets/README.md).


