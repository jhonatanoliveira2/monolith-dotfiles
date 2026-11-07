#!/usr/bin/env bash
# test-docs.sh - documentation consistency: links, anchors, script references, bilingual pairs, branch structure.
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
mapfile -t MDFILES < <(find . -name '*.md' -not -path './.git/*' -not -path './configs/*' | LC_ALL=C sort)
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
done < <(grep -rhoP '(?<![\w./-])(\./)?(scripts|tools|tests)/[A-Za-z0-9_./-]+\.(sh|py)' --include='*.md' . 2>/dev/null | sed 's#^\./##' | sort -u)

echo "== bilingual pairs"
[[ -f README.md && -f README.pt-br.md ]] && ok || ko "missing README pair"
[[ -f CONTRIBUTING.md && -f CONTRIBUTING.en.md ]] && ok || ko "missing CONTRIBUTING pair"
for f in docs/*.md; do
    case $f in *.pt-br.md) other=${f%.pt-br.md}.md ;; *) other=${f%.md}.pt-br.md ;; esac
    [[ -f $other ]] && ok || ko "missing docs pair: $f <-> $other"
done

echo "== structure of the NixOS branch"
for p in flake.nix flake.lock nix/meta.nix nix/packages.nix nix/pkgs/default.nix nix/modules/home.nix \
    nix/modules/nixos/default.nix nix/install/monolith-install.sh nix/checks templates/nixos/flake.nix \
    templates/nixos/configuration.nix configs/.config/hypr configs/.config/quickshell branding/build.sh \
    greeter/shell.qml wallpapers docs/nixos.md docs/nixos.pt-br.md \
    .gitignore LICENSE README.md README.pt-br.md CONTRIBUTING.md CONTRIBUTING.en.md THIRD-PARTY-CREDITS.md; do
    [[ -e $p ]] && ok || ko "missing: $p"
done
# NixOS only: the Arch installer and its previews live on main
for p in scripts packages.txt tools assets tests/test-installer.sh; do
    [[ ! -e $p ]] && ok || ko "Arch-only path present on the NixOS branch: $p"
done

echo
printf 'checks passed: %s   failed: %s\n' "$PASS" "$FAIL"
(( FAIL == 0 ))
