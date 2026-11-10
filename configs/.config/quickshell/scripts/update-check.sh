#!/usr/bin/env bash
# Settings > Update. key=value lines; never hides a failure (error=… with the real message).
#   update-check.sh <clone> [fallback-url] [fallback-branch]
# Without a clone (e.g. NixOS, where the flake pins a revision), only the API part runs, for fallback-url / branch.
# Uses the clone's own remote URL and branch (upstream if configured, otherwise origin/<current branch>),
# and asks the GitHub API about the same repository / branch to report connectivity and rate limits.
# When the clone is behind, what the update would bring is listed, so it can be read before anything runs:
#   target=<full revision of the upstream at this check>   the update fast-forwards to exactly this revision
#   change=<hash> <date> <subject>                          one line per new commit (at most 30; more=<n> for the rest)
#   installer=<n>                                           files under scripts/ that change (the code the update runs)
export LC_ALL=C GIT_TERMINAL_PROMPT=0
dir=$1 fallback=$2 fallbackBranch=${3:-main}
if [ -d "$dir/.git" ]; then
    url=$(git -C "$dir" remote get-url origin 2>&1) || { echo "error=git remote: $url"; url=""; }
    branch=$(git -C "$dir" symbolic-ref --short -q HEAD || echo "")
    upstream=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    [ -z "$upstream" ] && [ -n "$branch" ] && upstream="origin/$branch"
    echo "clone=1"; echo "url=$url"; echo "branch=${branch:-(detached)}"; echo "upstream=$upstream"
    echo "local=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
    echo "dirty=$(git -C "$dir" status --porcelain 2>/dev/null | grep -vc '^??')"
    if [ -n "$branch" ]; then
        if out=$(timeout 40 git -C "$dir" fetch --quiet origin "$branch" 2>&1); then
            echo "fetch=ok"
            echo "behind=$(git -C "$dir" rev-list --count "HEAD..$upstream" 2>/dev/null || echo -1)"
            echo "ahead=$(git -C "$dir" rev-list --count "$upstream..HEAD" 2>/dev/null || echo -1)"
            echo "remote=$(git -C "$dir" log -1 --format='%h %cs %s' "$upstream" 2>/dev/null)"
            if target=$(git -C "$dir" rev-parse --verify -q "$upstream^{commit}"); then
                echo "target=$target"
                n=$(git -C "$dir" rev-list --count "HEAD..$target" 2>/dev/null || echo 0)
                git -C "$dir" log --no-merges --format='change=%h %cs %s' -n 30 "HEAD..$target" 2>/dev/null
                (( n > 30 )) && echo "more=$(( n - 30 ))"
                echo "installer=$(git -C "$dir" diff --name-only "HEAD...$target" -- scripts 2>/dev/null | grep -c .)"
            fi
        else
            echo "fetch=fail"
            echo "error=git fetch: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-300)"
        fi
    fi
else
    echo "clone=0"; url=$fallback; branch=$fallbackBranch
    echo "url=$url"; echo "branch=$branch"
fi
# GitHub API (works without a clone; 60 unauthenticated requests per hour per IP)
if [[ $url =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?/?$ ]]; then
    slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    echo "slug=$slug"
    hdr=$(mktemp); trap 'rm -f "$hdr"' EXIT
    body=$(curl -sS --max-time 10 -D "$hdr" -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$slug/commits/${branch:-main}" -w '\n%{http_code}' 2>&1)
    code=${body##*$'\n'}
    echo "api=$code"
    echo "ratelimit=$(sed -n 's/^x-ratelimit-remaining: *\([0-9]*\).*/\1/Ip' "$hdr")"
    echo "ratereset=$(sed -n 's/^x-ratelimit-reset: *\([0-9]*\).*/\1/Ip' "$hdr")"
    case $code in
        200)   # the JSON is read with jq when there is one (the sed fallback depends on GitHub's indentation)
            if command -v jq >/dev/null 2>&1; then echo "apihead=$(printf '%s' "${body%$'\n'*}" | jq -r '.sha // "" | .[0:7]' 2>/dev/null)"
            else echo "apihead=$(printf '%s' "$body" | sed -n 's/^  "sha": "\([0-9a-f]\{7\}\).*/\1/p' | head -1)"; fi ;;
        000) echo "apierror=$(printf '%s' "$body" | head -1 | cut -c1-200)" ;;
        *) echo "apierror=$(printf '%s' "$body" | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p' | head -1)" ;;
    esac
fi
