#!/usr/bin/env bash
# Create an isolated git worktree pinned to a fixed base SHA.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create.sh <id> [base]

Creates a worktree for <id> at ../<repo-name>-worktrees/<id>, branched from
<base> (default: HEAD), pinned to that commit's resolved SHA.

Prints two lines on success:
  path=<worktree-path>
  branch=worktree/<id>

Exit codes:
  0  worktree created
  1  usage error
  2  <base> did not resolve to a commit
  3  a worktree or branch for <id> already exists
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
base="${2:-HEAD}"

base_sha="$(git rev-parse --verify "${base}^{commit}" 2>/dev/null)" || {
  echo "error: base '${base}' did not resolve to a commit" >&2
  exit 2
}

repo_name="$(basename "$(git rev-parse --show-toplevel)")"
repo_root="$(git rev-parse --show-toplevel)"
worktree_path="$(dirname "${repo_root}")/${repo_name}-worktrees/${id}"
branch="worktree/${id}"

if git worktree list --porcelain | grep -qx "worktree ${worktree_path}"; then
  echo "error: worktree already exists at ${worktree_path}" >&2
  exit 3
fi
if git show-ref --verify --quiet "refs/heads/${branch}"; then
  echo "error: branch ${branch} already exists" >&2
  exit 3
fi

mkdir -p "$(dirname "${worktree_path}")"
git worktree add -b "${branch}" "${worktree_path}" "${base_sha}" >&2

echo "path=${worktree_path}"
echo "branch=${branch}"
