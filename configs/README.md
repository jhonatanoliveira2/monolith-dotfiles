# configs/

**EN** — This folder is the payload of the installer. `configs/.config/` mirrors `~/.config/` and
`configs/.local/bin/` mirrors `~/.local/bin/`. The repository ships it **empty on purpose** (only
`.gitkeep` placeholders): copy your own folders in, do not recreate them.

**PT-BR** — Esta pasta é a carga útil do instalador. `configs/.config/` espelha `~/.config/` e
`configs/.local/bin/` espelha `~/.local/bin/`. O repositório a entrega **vazia de propósito** (apenas
marcadores `.gitkeep`): copie suas próprias pastas, não as recrie.

```bash
./scripts/import-configs.sh --with-local-bin     # safe copy with the exclusions documented in docs/
```

Placeholders (`.gitkeep`) are never deployed. / Os marcadores `.gitkeep` nunca são instalados.
