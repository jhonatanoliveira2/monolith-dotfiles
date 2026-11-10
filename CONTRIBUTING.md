# Guia de contribuição

[English](CONTRIBUTING.en.md) · **Português (Brasil)**

Obrigado por contribuir com o MONOLITH. Alterações claras, verificáveis e seguras ajudam a manter o instalador e as configurações úteis em outras máquinas.

## Antes de abrir uma contribuição

- Não inclua tokens, credenciais, chaves privadas, e-mails, nomes de usuário ou caminhos pessoais. Revise o diff inteiro antes de enviar.
- Não declare testes que não executou. Informe o ambiente usado e quaisquer verificações pendentes.
- Textos apresentados ao usuário devem existir em inglês e português do Brasil.
- Preserve licenças e avisos de terceiros junto dos componentes aos quais se aplicam.

## Convenções do projeto

Scripts, comentários, nomes internos e logs técnicos usam inglês. Apenas mensagens voltadas ao usuário são traduzidas. As mensagens do instalador ficam em `scripts/lib/messages.sh`; mantenha os placeholders na mesma ordem nos dois idiomas.

A documentação também é bilíngue. Ao alterar um guia, atualize os dois arquivos correspondentes em `docs/` e mantenha comandos, caminhos, opções e identificadores técnicos iguais. Os pares usam os nomes `configuracao.md` e `config.md`, `dependencias.md` e `dependencies.md`, `instalacao.md` e `installation.md`, `problemas-conhecidos.md` e `troubleshooting.md`; os guias do NixOS usam `nome.md` e `nome.pt-br.md` (`nixos`, `nothing-theme`).

O repositório atende dois sistemas com a mesma configuração em `configs/`: Arch Linux / CachyOS (instalador em `scripts/`) e NixOS (flake em `nix/`). Uma mudança em `configs/` vale para os dois: não use caminhos fixos de uma distribuição (`/usr/bin/...`), detecte em tempo de execução (`core/Distro.qml`). O tema Nothing é opcional e só existe quando `~/.config/monolith/nothing.json` está presente: sem ele o shell não pode mudar.

Ao alterar dependências, atualize `packages.txt` (Arch) e `nix/packages.nix` ou os módulos em `nix/modules/nixos/` (NixOS) e explique o motivo de cada pacote. Não transforme referências em comentários em dependências ativas sem confirmar o uso real.

## Verificações

Execute os testes relevantes antes de enviar (os mesmos que o CI roda em cada push e pull request):

```bash
bash tests/lint.sh                   # bash -n, shellcheck, luacheck, sintaxe de Python e de QML
bash tests/test-docs.sh              # links, âncoras, pares bilíngues, estrutura
bash tests/test-installer.sh         # instalador do Arch (ambientes temporários)
bash tests/test-nixos-install.sh     # instalador guiado do NixOS (nenhum disco é tocado)
bash tests/test-shell.sh             # singletons do shell sem compositor (precisa do quickshell)
nix flake check                      # só com Nix: constrói os pacotes e avalia uma máquina de exemplo
```

`tests/lint.sh` pula as ferramentas que não estiverem instaladas (`--strict` transforma isso em falha).

Os testes usam ambientes temporários e nunca tocam a sua sessão. Se alterar o comportamento do instalador, acrescente cobertura em `tests/test-installer.sh`; se alterar um serviço do shell (`core/`, `services/`), em `tests/test-shell.sh`.

## Fluxo sugerido

1. Crie um fork e um branch específico, como `fix/...`, `feat/...` ou `docs/...`.
2. Faça alterações focadas e escreva mensagens de commit no imperativo.
3. Teste o que mudou e descreva resultados reais.
4. Abra uma [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) para relatar um problema ou uma contribuição no repositório para propor a alteração.

## Capturas e prévias

Adicione capturas em `assets/screenshots/`. Remova notificações e dados pessoais antes de publicar. Os READMEs usam `1.png`, `2.png` e `3.png`. As prévias do instalador são geradas por `tools/ansi2svg.py`.
