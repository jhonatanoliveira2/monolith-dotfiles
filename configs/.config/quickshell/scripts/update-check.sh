#!/usr/bin/env bash
# Settings > Update. key=value lines; never hides a failure (error=… with the real message).
#   update-check.sh <clone> [fallback-url]
# Uses the clone's own remote URL and branch (upstream if configured, otherwise origin/<current branch>),
# and asks the GitHub API about the same repository / branch to report connectivity and rate limits.
export LC_ALL=C GIT_TERMINAL_PROMPT=0
dir=$1 fallback=$2
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
        else
            echo "fetch=fail"
            echo "error=git fetch: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-300)"
        fi
    fi
else
    echo "clone=0"; url=$fallback; branch=main
    echo "url=$url"; echo "branch=$branch"
fi
# GitHub API (works without a clone; 60 unauthenticated requests per hour per IP)
if [[ $url =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?/?$ ]]; then
    slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    echo "slug=$slug"
    hdr=$(mktemp); body=$(curl -sS --max-time 10 -D "$hdr" -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$slug/commits/${branch:-main}" -w '\n%{http_code}' 2>&1)
    code=${body##*$'\n'}
    echo "api=$code"
    echo "ratelimit=$(sed -n 's/^x-ratelimit-remaining: *\([0-9]*\).*/\1/Ip' "$hdr")"
    echo "ratereset=$(sed -n 's/^x-ratelimit-reset: *\([0-9]*\).*/\1/Ip' "$hdr")"
    rm -f "$hdr"
    case $code in
        200) echo "apihead=$(printf '%s' "$body" | sed -n 's/^  "sha": "\([0-9a-f]\{7\}\).*/\1/p' | head -1)" ;;
        000) echo "apierror=$(printf '%s' "$body" | head -1 | cut -c1-200)" ;;
        *) echo "apierror=$(printf '%s' "$body" | sed -n 's/.*"message": *"\([^"]*\)".*/\1/p' | head -1)" ;;
    esac
fi
