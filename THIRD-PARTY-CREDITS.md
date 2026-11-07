# Créditos e avisos de terceiros

[English](#third-party-credits-and-notices) · **Português (Brasil)**

Partes do conteúdo em `configs/` e suas dependências podem ter licenças próprias. Preserve os avisos que acompanham os arquivos e confira os termos aplicáveis antes de redistribuir ou modificar esses componentes.

| Caminho | Componente | Aviso de licença |
|---|---|---|
| `configs/.config/ghostty/shaders/` | Shaders de cursor para Ghostty e Kitty | MIT; aviso mantido em `shaders/LICENSE` |
| `configs/.config/nvim/` | Starter de configuração do Neovim | Apache License 2.0; texto incluído em `nvim/LICENSE` |
| `configs/.config/nvim/lazy-lock.json` | Versões fixadas de plugins externos | Cada plugin mantém seus próprios termos de licença. |
| `nix/fetch/logo.txt` (NixOS) | Logo ASCII clássico do NixOS (`nixos_old`), do [fastfetch](https://github.com/fastfetch-cli/fastfetch); animado pelo [fetch](https://github.com/areofyl/fetch) (ISC), instalado do nixpkgs | fastfetch: MIT; a marca NixOS pertence à NixOS Foundation |
| `branding/` (NixOS) | Logo do NixOS (floco de neve), lido do pacote `nixos-icons` do nixpkgs no build; não é copiado para o repositório | NixOS artwork, CC-BY 4.0; a marca NixOS pertence à NixOS Foundation |
| `nix/nothing/dotmatrix.py` (tema Nothing) | Conversor de wallpapers em matriz de LEDs, adaptado do `theme/dotmatrix.py` do [NIHIL Shell](https://github.com/poligle/Nihil-Shell), de poligle (Pol Iglesias) | MIT; aviso mantido em `nix/nothing/LICENSE.NIHIL` |
| `nix/nothing/tokens.nix`, `components/EdgeGlow.qml`, `DotMeter.qml`, `LedRing.qml` (tema Nothing) | Paleta em cinzas, as três vozes tipográficas, medidores de LEDs e a luz que percorre a borda: ideias do NIHIL Shell, reescritas para o Monolith (nenhum arquivo QML copiado) | NIHIL Shell: MIT |
| fontes do tema Nothing (`nix/pkgs/nothing-fonts.nix`) | [Doto](https://github.com/oliverlalan/Doto), [Space Grotesk](https://github.com/floriankarsten/space-grotesk) e [Space Mono](https://github.com/googlefonts/spacemono), baixadas do repositório google/fonts no build; não estão no repositório | SIL Open Font License 1.1 (textos instalados com as fontes) |

### Programas usados pelo shell (não distribuídos aqui)

Instalados pelo gerenciador de pacotes (nixpkgs), cada um com a sua licença: [Quickshell](https://quickshell.org) (LGPL-3.0), [Hyprland](https://hyprland.org), hyprlock e hypridle (BSD-3-Clause), [awww](https://codeberg.org/LGFae/awww) (GPL-3.0), [mpvpaper](https://github.com/GhostNaN/mpvpaper) (GPL-3.0), [rofi](https://github.com/davatorium/rofi) (MIT), [wpgtk](https://github.com/deviantfero/wpgtk) (GPL-2.0), [cava](https://github.com/karlstav/cava) (MIT), [fetch](https://github.com/areofyl/fetch) (ISC), [fastfetch](https://github.com/fastfetch-cli/fastfetch) (MIT), [Ghostty](https://ghostty.org) (MIT), [fish](https://fishshell.com) (GPL-2.0), [Starship](https://starship.rs) (ISC), [Atuin](https://atuin.sh) (MIT), [JetBrains Mono](https://www.jetbrains.com/lp/mono/) (OFL-1.1) com [Nerd Fonts](https://www.nerdfonts.com) (MIT), Material Icons (Apache-2.0), [NumPy](https://numpy.org) (BSD-3-Clause) e [Pillow](https://python-pillow.github.io) (MIT-CMU).

**Aviso:** Este projeto não é afiliado à Nothing Technology Limited. "Nothing" é usado apenas para descrever o estilo visual (matriz de pontos / LEDs); nenhum logotipo, fonte proprietária (como a Ndot) ou outro material da Nothing é usado.

Esta lista é informativa, não é aconselhamento jurídico e pode não cobrir todo componente transitivo. Revise os arquivos de licença junto de cada dependência. Os arquivos próprios do projeto na raiz usam a licença MIT indicada em [`LICENSE`](LICENSE).

## Third-party credits and notices

Parts of the content in `configs/` and its dependencies may carry their own licenses. Preserve the notices shipped with those files and review the applicable terms before redistributing or modifying those components.

| Path | Component | License notice |
|---|---|---|
| `configs/.config/ghostty/shaders/` | Cursor shaders for Ghostty and Kitty | MIT; notice kept in `shaders/LICENSE` |
| `configs/.config/nvim/` | Neovim configuration starter | Apache License 2.0; text included in `nvim/LICENSE` |
| `configs/.config/nvim/lazy-lock.json` | Pinned versions of external plugins | Each plugin retains its own license terms. |
| `nix/fetch/logo.txt` (NixOS) | Classic NixOS ASCII logo (`nixos_old`), from [fastfetch](https://github.com/fastfetch-cli/fastfetch); animated by [fetch](https://github.com/areofyl/fetch) (ISC), installed from nixpkgs | fastfetch: MIT; the NixOS mark belongs to the NixOS Foundation |
| `branding/` (NixOS) | NixOS logo (snowflake), read from nixpkgs' `nixos-icons` package at build time; not copied into the repository | NixOS artwork, CC-BY 4.0; the NixOS mark belongs to the NixOS Foundation |
| `nix/nothing/dotmatrix.py` (Nothing theme) | LED-matrix wallpaper converter, adapted from `theme/dotmatrix.py` of [NIHIL Shell](https://github.com/poligle/Nihil-Shell) by poligle (Pol Iglesias) | MIT; notice kept in `nix/nothing/LICENSE.NIHIL` |
| `nix/nothing/tokens.nix`, `components/EdgeGlow.qml`, `DotMeter.qml`, `LedRing.qml` (Nothing theme) | Grey palette, the three type voices, LED meters and the light running along the edge: ideas from NIHIL Shell, rewritten for Monolith (no QML file copied) | NIHIL Shell: MIT |
| Nothing theme fonts (`nix/pkgs/nothing-fonts.nix`) | [Doto](https://github.com/oliverlalan/Doto), [Space Grotesk](https://github.com/floriankarsten/space-grotesk) and [Space Mono](https://github.com/googlefonts/spacemono), downloaded from the google/fonts repository at build time; not in the repository | SIL Open Font License 1.1 (texts installed with the fonts) |

### Programs the shell uses (not distributed here)

Installed by the package manager (nixpkgs), each under its own license: [Quickshell](https://quickshell.org) (LGPL-3.0), [Hyprland](https://hyprland.org), hyprlock and hypridle (BSD-3-Clause), [awww](https://codeberg.org/LGFae/awww) (GPL-3.0), [mpvpaper](https://github.com/GhostNaN/mpvpaper) (GPL-3.0), [rofi](https://github.com/davatorium/rofi) (MIT), [wpgtk](https://github.com/deviantfero/wpgtk) (GPL-2.0), [cava](https://github.com/karlstav/cava) (MIT), [fetch](https://github.com/areofyl/fetch) (ISC), [fastfetch](https://github.com/fastfetch-cli/fastfetch) (MIT), [Ghostty](https://ghostty.org) (MIT), [fish](https://fishshell.com) (GPL-2.0), [Starship](https://starship.rs) (ISC), [Atuin](https://atuin.sh) (MIT), [JetBrains Mono](https://www.jetbrains.com/lp/mono/) (OFL-1.1) with [Nerd Fonts](https://www.nerdfonts.com) (MIT), Material Icons (Apache-2.0), [NumPy](https://numpy.org) (BSD-3-Clause) and [Pillow](https://python-pillow.github.io) (MIT-CMU).

**Notice:** This project is not affiliated with Nothing Technology Limited. "Nothing" only describes the visual style (dot matrix / LEDs); no Nothing logo, proprietary font (such as Ndot) or other Nothing material is used.

This list is informational, is not legal advice and may not cover every transitive component. Review the license files accompanying each dependency. The project's own root-level files use the MIT license shown in [`LICENSE`](LICENSE).
