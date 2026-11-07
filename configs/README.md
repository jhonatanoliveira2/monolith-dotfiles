# configs/

**EN** — The desktop configuration. `configs/.config/` mirrors `~/.config/` and `configs/.local/bin/` mirrors
`~/.local/bin/`. The Home Manager module (`nix/modules/home.nix`) links these files from the Nix store; the ones
programs rewrite are copied once instead (`programs.monolith.mutableFiles`). See [docs/nixos.md](../docs/nixos.md).

**PT-BR** — A configuração do desktop. `configs/.config/` espelha `~/.config/` e `configs/.local/bin/` espelha
`~/.local/bin/`. O módulo Home Manager (`nix/modules/home.nix`) liga esses arquivos da Nix store; os que os
programas reescrevem são copiados uma vez (`programs.monolith.mutableFiles`). Veja
[docs/nixos.pt-br.md](../docs/nixos.pt-br.md).
