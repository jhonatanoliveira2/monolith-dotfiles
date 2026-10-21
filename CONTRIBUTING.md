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

A documentação também é bilíngue. Ao alterar um guia, atualize os dois arquivos correspondentes em `docs/` e mantenha comandos, caminhos, opções e identificadores técnicos iguais. Os pares usam os nomes `configuracao.md` e `config.md`, `Dependencias.md` e `dependencies.md`, `Instalacao.md` e `Installation.md`, `Problemas-conhecidos.md` e `Troubleshooting.md`.

Ao alterar dependências, atualize `packages.txt` e explique o motivo de cada pacote. Não transforme referências em comentários em dependências ativas sem confirmar o uso real.

## Verificações

Execute os testes relevantes antes de enviar:

```bash
bash tests/test-installer.sh
bash tests/test-docs.sh
for f in scripts/*.sh scripts/lib/*.sh tests/*.sh; do bash -n "$f"; done
```

Se tiver ShellCheck instalado, rode também:

```bash
shellcheck -x -S warning scripts/*.sh scripts/lib/*.sh
```

Os testes do instalador usam ambientes temporários. Se alterar o comportamento do instalador, acrescente uma cobertura correspondente em `tests/test-installer.sh`.

## Fluxo sugerido

1. Crie um fork e um branch específico, como `fix/...`, `feat/...` ou `docs/...`.
2. Faça alterações focadas e escreva mensagens de commit no imperativo.
3. Teste o que mudou e descreva resultados reais.
4. Abra uma [issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) para relatar um problema ou uma contribuição no repositório para propor a alteração.

## Capturas e prévias

Adicione capturas em `assets/screenshots/`. Remova notificações e dados pessoais antes de publicar. O arquivo `assets/screenshots/screenshot-slot.svg` é apenas uma moldura substituível para os READMEs. As prévias do instalador são geradas por `tools/ansi2svg.py`; consulte o [guia de recursos visuais](assets/VISUAL-GUIDE.md).
