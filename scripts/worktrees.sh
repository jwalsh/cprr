#!/usr/bin/env bash
# worktrees.sh - Manage git worktrees under worktrees/
set -euo pipefail

WORKTREE_DIR="worktrees"

usage() {
    cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  list      List all worktrees (default)
  sync      Fetch/prune remote, show available branches
  add NAME  Create worktree for branch NAME
  prune     Remove worktrees for deleted branches
  clean     Remove all worktrees

Examples:
  $(basename "$0")              # List worktrees
  $(basename "$0") sync         # Fetch and show remote branches
  $(basename "$0") add feature  # Create worktree for origin/feature
EOF
}

cmd_list() {
    echo "==> Current worktrees"
    git worktree list
}

cmd_sync() {
    echo "==> Fetching and pruning remote"
    git fetch --prune origin

    echo ""
    echo "==> Remote branches (excluding HEAD)"
    git branch -r | grep -v HEAD | sed 's/origin\//  /'

    echo ""
    echo "==> Local worktrees"
    git worktree list
}

cmd_add() {
    local branch="${1:-}"
    if [[ -z "$branch" ]]; then
        echo "Error: branch name required" >&2
        echo "Usage: $(basename "$0") add BRANCH" >&2
        exit 1
    fi

    local worktree_path="${WORKTREE_DIR}/${branch}"

    if [[ -d "$worktree_path" ]]; then
        echo "Worktree already exists: $worktree_path"
        exit 0
    fi

    # Check if remote branch exists
    if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        echo "==> Creating worktree for origin/${branch}"
        git worktree add "$worktree_path" "origin/${branch}"
    elif git show-ref --verify --quiet "refs/heads/${branch}"; then
        echo "==> Creating worktree for local branch ${branch}"
        git worktree add "$worktree_path" "$branch"
    else
        echo "==> Creating new branch ${branch} with worktree"
        git worktree add -b "$branch" "$worktree_path"
    fi

    echo "Created: $worktree_path"
}

cmd_prune() {
    echo "==> Pruning stale worktrees"
    git worktree prune -v
}

cmd_clean() {
    echo "==> Removing all worktrees in ${WORKTREE_DIR}/"

    if [[ ! -d "$WORKTREE_DIR" ]]; then
        echo "No worktrees directory"
        exit 0
    fi

    for wt in "${WORKTREE_DIR}"/*; do
        [[ -d "$wt" ]] || continue
        echo "Removing: $wt"
        git worktree remove "$wt" --force 2>/dev/null || rm -rf "$wt"
    done

    git worktree prune
    echo "Done"
}

# Main
cmd="${1:-list}"
shift || true

case "$cmd" in
    list)   cmd_list ;;
    sync)   cmd_sync ;;
    add)    cmd_add "$@" ;;
    prune)  cmd_prune ;;
    clean)  cmd_clean ;;
    -h|--help|help) usage ;;
    *)
        echo "Unknown command: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
