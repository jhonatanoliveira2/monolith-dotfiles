# Guia de contribuição

**Português (Brasil)** · [English](CONTRIBUTING.en.md)

Obrigado por contribuir com o MONOLITH. Esta branch tem suporte **somente ao NixOS**; mudanças para Arch Linux /
CachyOS vão para a `main`.

## Antes de abrir uma contribuição

- Não inclua tokens, credenciais, chaves privadas, endereços de e-mail, nomes de usuário ou caminhos pessoais. Revise todo o diff antes de enviar.
- Não declare testes que você não executou. Informe o ambiente usado e as verificações que ficaram pendentes.
- Textos voltados ao usuário devem existir em português do Brasil e em inglês.
- Preserve as licenças e os avisos de terceiros junto aos componentes a que se aplicam.

## Convenções do projeto

Código, comentários, nomes internos e logs técnicos usam inglês. Apenas mensagens voltadas ao usuário são
traduzidas (`settings/Labels.qml` e `core/Strings.qml` do shell, os pares `t "pt" "en"` do instalador).

A documentação é bilíngue: ao alterar um guia, atualize os dois arquivos e mantenha comandos, caminhos, opções e
identificadores técnicos idênticos. Os pares são `README.md` / `README.pt-br.md`, `CONTRIBUTING.en.md` /
`CONTRIBUTING.md` e os guias `docs/*.md` / `docs/*.pt-br.md`.

Pacotes ficam em `nix/packages.nix` (programas do usuário) ou nos módulos NixOS (`nix/modules/nixos/`,
serviços); explique por que cada um é necessário.

## Verificações

```bash
nix flake check                      # compila os pacotes e avalia uma máquina de exemplo
bash tests/test-nixos-install.sh     # instalador guiado (nenhum disco é tocado)
bash tests/test-docs.sh              # links, âncoras e pares bilíngues
bash -n nix/install/monolith-install.sh
```

## Fluxo sugerido

1. Faça um fork e crie uma branch focada, como `fix/...`, `feat/...` ou `docs/...`.
2. Mantenha as mudanças focadas e escreva mensagens de commit no imperativo.
3. Teste o que mudou (um `nixos-rebuild build` de uma configuração real quando os módulos mudarem) e informe os resultados reais.
4. Abra uma [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) para relatar um problema ou um pull request para propor uma mudança.
