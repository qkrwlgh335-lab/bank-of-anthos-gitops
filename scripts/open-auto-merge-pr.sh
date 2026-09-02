#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <branch> <title> <body>" >&2
  exit 2
fi

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

branch="$1"
title="$2"
body="$3"

git switch -C "$branch"
git fetch origin "$branch:refs/remotes/origin/$branch" 2>/dev/null || true
git push --force-with-lease="refs/heads/$branch" origin "HEAD:refs/heads/$branch"

pr_url=$(gh pr list --repo "$GITHUB_REPOSITORY" --state open --head "$branch" \
  --json url --jq '.[0].url')
if [[ -z "$pr_url" ]]; then
  pr_url=$(gh pr create --repo "$GITHUB_REPOSITORY" --head "$branch" --base main \
    --title "$title" --body "$body")
fi

gh pr merge "$pr_url" --auto --squash --delete-branch
echo "Waiting for protected-branch checks: $pr_url"

merge_oid=""
for attempt in {1..120}; do
  read -r state merge_oid < <(gh pr view "$pr_url" --repo "$GITHUB_REPOSITORY" \
    --json state,mergeCommit --jq '[.state, (.mergeCommit.oid // "")] | @tsv')
  if [[ "$state" == "MERGED" && "$merge_oid" == ?* ]]; then
    break
  fi
  [[ "$state" == "CLOSED" ]] && { echo "PR closed without merging: $pr_url" >&2; exit 1; }
  sleep 5
done
[[ "$merge_oid" == ?* ]] || { echo "Timed out waiting for auto-merge: $pr_url" >&2; exit 1; }

git fetch origin main
git switch main
git reset --hard origin/main
[[ "$(git rev-parse HEAD)" == "$merge_oid" ]] || {
  echo "Merged commit mismatch: local=$(git rev-parse HEAD) expected=$merge_oid" >&2
  exit 1
}

echo "Merged protected-branch change: $pr_url ($merge_oid)"
