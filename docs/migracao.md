# Atualizar a partir de uma branch antiga

**Português (Brasil)** · [English](migrating.md)

Tudo o que estava em `feature/nixos-support`, `feature/nothing-theme` e `unify/main` agora está na **`main`**, e
essas branches foram removidas do GitHub. Arch Linux / CachyOS e NixOS são instalados a partir da `main`.
Encontre o seu caso abaixo; cada um leva um minuto.

| Você instalou a partir de | O que fazer |
|---|---|
| `main`, Arch Linux / CachyOS | [Arch: a partir da `main`](#arch-linux--cachyos-a-partir-da-main), uma atualização normal |
| outra branch, Arch Linux / CachyOS | [Arch: a partir de outra branch](#arch-linux--cachyos-a-partir-de-outra-branch) |
| `feature/nixos-support`, `feature/nothing-theme` ou `?ref=unify/main`, NixOS | [NixOS](#nixos) |

## Arch Linux / CachyOS a partir da `main`

A `main` avançou sem reescrever o histórico, então uma atualização comum funciona:

```sh
cd ~/monolith-dotfiles          # o seu clone
git pull --ff-only
./scripts/install.sh
```

Ou **Configurações > Atualização**. O instalador agora pergunta o tema (padrão ou [Nothing](nothing-theme.pt-br.md));
seus arquivos passam por backup antes, como sempre.

## Arch Linux / CachyOS a partir de outra branch

**Configurações > Atualização** falha com `couldn't find remote ref ...`, porque a branch não existe mais. Leve o
clone para a `main`:

```sh
cd ~/monolith-dotfiles
git stash                       # só se você alterou arquivos no clone
git fetch origin --prune
git switch main                 # ou: git switch -c main --track origin/main
git pull --ff-only
git branch -D unify/main 2>/dev/null; git branch -D feature/nothing-theme feature/nixos-support 2>/dev/null
./scripts/install.sh
```

Depois, `git stash pop` traz suas alterações de volta.

## NixOS

A entrada `monolith` do `/etc/nixos/flake.nix` ainda aponta para a branch antiga, então `nix flake update` (e
Configurações > Atualização) falha. O `flake.lock` continua fixando o commit antigo: o sistema segue iniciando e
reconstruindo, só as atualizações param. Aponte a entrada para a `main`:

```sh
sudo sed -i -E 's#monolith-dotfiles(/feature/(nixos-support|nothing-theme)|\?ref=unify/main)#monolith-dotfiles#' /etc/nixos/flake.nix
grep -n 'monolith-dotfiles' /etc/nixos/flake.nix     # url = "github:jhonatanoliveira2/monolith-dotfiles";
sudo nix flake update monolith --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos
```

O que muda:

- **Tema Nothing:** vinha ligado por padrão na `feature/nothing-theme`; na `main` fica desligado, a menos que seja
  escolhido. Para mantê-lo, acrescente `nothingTheme.enable = true;` ao bloco `monolith = { ... };` do
  `/etc/nixos/configuration.nix` (ou `monolith.nothingTheme.enable = true;` fora dele) antes de reconstruir.
- **Barra:** a posição e o estilo já estão salvos nas suas configurações e continuam como estão.
- Instalações novas: `sudo nix --extra-experimental-features "nix-command flakes" run github:jhonatanoliveira2/monolith-dotfiles#install`
  (sem `?ref=`).

## Outros casos

Se um passo falhar, veja os [problemas conhecidos](problemas-conhecidos.md) ou abra uma
[issue](https://github.com/jhonatanoliveira2/monolith-dotfiles/issues) com o comando e a saída.
