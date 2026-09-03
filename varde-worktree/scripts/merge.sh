#!/usr/bin/env bash
# Merge a worktree's branch back into the target branch.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: merge.sh <id> [into]

Merges worktree/<id> into <into> (default: the branch currently checked out
in this checkout). Commits any uncommitted changes left in the worktree
first, using a placeholder message if the caller made no commit.

Exit codes:
  0  merged cleanly, worktree/<id> is now in <into>
  1  usage error
  2  worktree/<id> has no commits ahead of its base — nothing to merge
  3  merge conflict — resolve via references/RESOLVE.md, then finish the
     merge manually; do NOT run cleanup.sh until it's resolved
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 1
fi

id="$1"
branch="worktree/${id}"
into="${2:-$(git rev-parse --abbrev-ref HEAD)}"

repo_name="$(basename "$(git rev-parse --show-toplevel)")"
repo_root="$(git rev-parse --show-toplevel)"
worktree_path="$(dirname "${repo_root}")/${repo_name}-worktrees/${id}"

if [[ -d "${worktree_path}" ]] && ! git -C "${worktree_path}" diff --quiet HEAD; then
  git -C "${worktree_path}" commit -am "worktree ${id}: uncommitted changes at merge time" >&2
fi

merge_base="$(git merge-base "${into}" "${branch}")"
if [[ "$(git rev-parse "${branch}")" == "${merge_base}" ]]; then
  echo "error: ${branch} has no commits ahead of ${into} — nothing to merge" >&2
  exit 2
fi

if git merge --no-ff --no-edit "${branch}"; then
  echo "merged ${branch} into ${into}"
  exit 0
else
  echo "conflict merging ${branch} into ${into} — see references/RESOLVE.md" >&2
  exit 3
fi
