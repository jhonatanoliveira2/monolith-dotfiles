# Guia de contribuição

[English](CONTRIBUTING.en.md) · **Português (Brasil)**

Obrigado por contribuir com o MONOLITH. Alterações claras, verificáveis e seguras ajudam a manter o instalador e as configurações úteis em outras máquinas.

## Antes de abrir uma contribuição

- Não inclua tokens, credenciais, chaves privadas, e-mails, nomes de usuário ou caminhos pessoais. Revise o diff inteiro antes de enviar.
- Não declare testes que não executou. Informe o ambiente usado e quaisquer verificações pendentes.
- Escreva no idioma que preferir, inglês ou português do Brasil, no código, nos textos da interface e na documentação. A tradução para o outro idioma é bem-vinda, mas não é obrigatória.
- Preserve licenças e avisos de terceiros junto dos componentes aos quais se aplicam.

## Convenções do projeto

O código existente usa inglês em scripts, comentários, nomes internos e logs técnicos; seguir isso ajuda, mas não é regra. As mensagens do instalador ficam em `scripts/lib/messages.sh` (`_m chave "inglês" ["português"]`) e as do shell em `core/Strings.qml` e `settings/Labels.qml`. Um texto escrito em um idioma só aparece nesse idioma até alguém traduzir; quando houver os dois, mantenha os placeholders na mesma ordem.

A maior parte dos guias em `docs/` existe nos dois idiomas (por exemplo `instalacao.md` e `installation.md`, `nixos.pt-br.md` e `nixos.md`). Ao alterar um guia, você pode mudar só a versão do idioma que usa, e um guia novo pode existir em um idioma só. Se atualizar os dois, mantenha comandos, caminhos e opções iguais.

O repositório atende dois sistemas com a mesma configuração em `configs/`: Arch Linux / CachyOS (instalador em `scripts/`) e NixOS (flake em `nix/`). Uma mudança em `configs/` vale para os dois: não use caminhos fixos de uma distribuição (`/usr/bin/...`), detecte em tempo de execução (`core/Distro.qml`). O tema Nothing é opcional e só existe quando `~/.config/monolith/nothing.json` está presente (gravado pelo Nix ou pelo `scripts/nothing-theme.sh`, a partir dos mesmos arquivos de `nix/nothing/`): sem ele o shell não pode mudar.

Ao alterar dependências, atualize `packages.txt` (Arch) e `nix/packages.nix` ou os módulos em `nix/modules/nixos/` (NixOS) e explique o motivo de cada pacote. Não transforme referências em comentários em dependências ativas sem confirmar o uso real.

## Verificações

Execute os testes relevantes antes de enviar (os mesmos que o CI roda em cada push e pull request):

```bash
bash tests/lint.sh                   # bash -n, shellcheck, luacheck, sintaxe de Python e de QML
bash tests/test-docs.sh              # links, âncoras, estrutura
bash tests/test-installer.sh         # instalador do Arch (ambientes temporários)
bash tests/test-nixos-install.sh     # instalador guiado do NixOS (nenhum disco é tocado)
bash tests/test-scripts.sh           # scripts auxiliares do shell (curl falso, sem rede)
bash tests/test-shell.sh             # singletons do shell sem compositor (precisa do quickshell)
bash tests/smoke-shell.sh            # o shell inteiro num Hyprland aninhado (abre uma janela por ~40 s; --nothing = com o tema)
nix flake check                      # só com Nix: constrói os pacotes e avalia uma máquina de exemplo
```

`tests/lint.sh` pula as ferramentas que não estiverem instaladas (`--strict` transforma isso em falha).

Os testes usam ambientes temporários e nunca tocam a sua sessão. Se alterar o comportamento do instalador, acrescente cobertura em `tests/test-installer.sh`; se alterar um serviço do shell (`core/`, `services/`), em `tests/test-shell.sh`.

## Fluxo sugerido

1. Crie um fork e um branch específico, como `fix/...`, `feat/...` ou `docs/...`.
2. Faça alterações focadas e escreva mensagens de commit no imperativo.
3. Teste o que mudou e descreva resultados reais.
4. Abra uma [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) para relatar um problema ou uma contribuição no repositório para propor a alteração.

## Prévias

As prévias do README ficam em `assets/previews/` e são geradas a partir dos programas reais por `python3 tools/previews.py` (precisa de fastfetch, fish, `script` e Python com Pillow e numpy; `--only nome` refaz uma só). Elas não mostram o nome do usuário nem o hostname; confira o resultado antes de enviar, e tire dados pessoais de qualquer imagem nova.
