#!/usr/bin/env bash
# test-docs.sh - documentation consistency: links, anchors, script references, bilingual pairs, package coverage,
# and the structure of both install paths (Arch installer, NixOS flake).
# Usage: bash tests/test-docs.sh
set -uo pipefail
export LC_ALL=C.UTF-8

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0 FAIL=0
ok() { PASS=$(( PASS + 1 )); }
ko() { FAIL=$(( FAIL + 1 )); printf '  FAIL  %s\n' "$1"; }

# GitHub-style heading slug
slug() {
    local s=${1,,}
    s=$(printf '%s' "$s" | sed -E 's/`//g; s/[^[:alnum:] _-]//g; s/ /-/g')
    printf '%s' "$s"
}

has_anchor() { # has_anchor <file> <anchor>
    local line h
    while IFS= read -r line; do
        h=${line#"${line%%[!#]*}"}
        h=${h# }
        [[ $(slug "$h") == "$2" ]] && return 0
    done < <(grep -E '^#{1,6} ' "$1")
    return 1
}

echo "== markdown links and anchors"
# tracked files only (ignored folders such as .claude/ or node_modules/ are not the project's documentation);
# outside a git checkout (release tarball) every *.md is taken
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t MDFILES < <(git ls-files -co --exclude-standard -- '*.md' | grep -v '^configs/' | sed 's#^#./#' | LC_ALL=C sort)
else
    mapfile -t MDFILES < <(find . -name '*.md' -not -path './.git/*' -not -path './configs/*' | LC_ALL=C sort)
fi
for f in "${MDFILES[@]}"; do
    dir=$(dirname "$f")
    # strip fenced code blocks and HTML comments before looking for links
    content=$(awk '/^```/ { skip = !skip; next } !skip' "$f" | sed -E ':a;N;$!ba;s/<!--[^>]*-->//g')
    while IFS= read -r link; do
        target=${link%%#*}
        frag=""
        [[ $link == *"#"* ]] && frag=${link#*#}
        case $link in http*|mailto:*) continue ;; esac
        if [[ -n $target ]]; then
            [[ -e $dir/$target ]] || { ko "$f -> missing path: $target"; continue; }
            dest=$dir/$target
        else
            dest=$f
        fi
        if [[ -n $frag && $dest == *.md ]]; then
            has_anchor "$dest" "$frag" || ko "$f -> missing anchor: $target#$frag"
        fi
        ok
    done < <(printf '%s\n' "$content" | grep -oE '\]\([^)]+\)' | sed -E 's/^\]\(//; s/\)$//' | sed -E 's/ .*$//')
    # raw HTML attributes (img src / href)
    while IFS= read -r src; do
        case $src in http*|mailto:*|\#*) continue ;; esac
        [[ -e $dir/${src%%#*} ]] && ok || ko "$f -> missing file in HTML attribute: $src"
    done < <(printf '%s\n' "$content" | grep -oE '(src|href)="[^"]+"' | sed -E 's/^(src|href)="//; s/"$//')
done

echo "== script and tool references"
while IFS= read -r ref; do
    [[ -e $ref ]] && ok || ko "referenced but missing: $ref"
# only repository-level paths: skip config-relative ones such as hypr/scripts/x.sh or quickshell/scripts/x.sh
done < <(grep -hoP '(?<![\w./-])(\./)?(scripts|tools|tests)/[A-Za-z0-9_./-]+\.(sh|py)' "${MDFILES[@]}" 2>/dev/null | sed 's#^\./##' | sort -u)

echo "== bilingual pairs"
[[ -f README.md && -f README.pt-br.md ]] && ok || ko "missing README pair"
[[ -f CONTRIBUTING.md && -f CONTRIBUTING.en.md ]] && ok || ko "missing CONTRIBUTING pair"
for pair in instalacao.md:installation.md configuracao.md:config.md dependencias.md:dependencies.md \
    problemas-conhecidos.md:troubleshooting.md nixos.pt-br.md:nixos.md nothing-theme.pt-br.md:nothing-theme.md; do
    [[ -f docs/${pair%%:*} && -f docs/${pair#*:} ]] && ok || ko "missing docs pair: $pair"
done

echo "== packages.txt vs. documentation"
source scripts/lib/common.sh
source scripts/lib/packages.sh
for sec in official:required official:optional aur:required aur:optional manual; do
    while IFS= read -r pkg; do
        for d in docs/dependencias.md docs/dependencies.md; do
            grep -qF "$pkg" "$d" && ok || ko "$pkg ($sec) is not documented in $d"
        done
    done < <(pkg_list "$sec")
done

echo "== structure required by the project brief"
for p in assets/screenshots assets/previews \
    configs/.config/hypr configs/.config/quickshell configs/.config/fish configs/.config/ghostty \
    configs/.config/btop configs/.config/nvim configs/.config/micro configs/.config/gtk-3.0 \
    configs/.config/gtk-4.0 configs/.config/nwg-look configs/.config/wal configs/.config/wpg \
    scripts/install.sh scripts/backup.sh scripts/check-dependencies.sh \
    docs/instalacao.md docs/installation.md docs/configuracao.md docs/config.md \
    docs/problemas-conhecidos.md docs/troubleshooting.md \
    .gitignore LICENSE packages.txt README.md README.pt-br.md CONTRIBUTING.md CONTRIBUTING.en.md; do
    [[ -e $p ]] && ok || ko "missing: $p"
done

echo "== structure of the NixOS side (flake)"
for p in flake.nix flake.lock nix/meta.nix nix/packages.nix nix/pkgs/default.nix nix/modules/home.nix \
    nix/modules/nixos/default.nix nix/install/monolith-install.sh nix/checks templates/nixos/flake.nix \
    templates/nixos/configuration.nix branding/build.sh greeter/shell.qml wallpapers \
    docs/nixos.md docs/nixos.pt-br.md docs/nothing-theme.md docs/nothing-theme.pt-br.md THIRD-PARTY-CREDITS.md; do
    [[ -e $p ]] && ok || ko "missing: $p"
done

echo "== one repository: nothing points at the old branches"
# the flake, the template, the installer and the update check follow the default branch; the guides may name the
# old branches only where they explain how to leave them (docs/nothing-theme*.md)
while IFS= read -r hit; do
    ko "reference to a merged branch: $hit"
done < <(grep -rnE 'feature/(nixos-support|nothing-theme)' flake.nix nix templates README.md README.pt-br.md \
    CONTRIBUTING.md CONTRIBUTING.en.md docs/nixos.md docs/nixos.pt-br.md configs/.config/quickshell 2>/dev/null)
grep -q 'branch = "main"' nix/meta.nix && ok || ko "nix/meta.nix does not follow main"

echo
printf 'checks passed: %s   failed: %s\n' "$PASS" "$FAIL"
(( FAIL == 0 ))