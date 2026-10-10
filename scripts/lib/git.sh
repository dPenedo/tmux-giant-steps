#!/bin/sh
# Git worktree helpers for sessionizer and ai-jump.
#
# Everything but repo_main reads .git and HEAD directly: --list runs this for
# every directory, and calling git each time makes the picker slow.

WT_ARROW=$(printf '\342\206\220') # ←

# worktree_read <dir>: if <dir> is the top of a git checkout, sets
#   wt_kind    "main" or "linked" (a `git worktree add` one)
#   wt_main    the repo's main checkout
#   wt_branch  branch name, or "detached"
#   wt_label   "[branch]", or "[branch] ← repo" for a linked worktree
# Returns 1 otherwise. Sets variables instead of printing to avoid a subshell.
worktree_read() {
	wt_dir=${1%/}
	if [ -d "$wt_dir/.git" ]; then
		wt_kind=main
		wt_main=$wt_dir
		wt_gitdir=$wt_dir/.git
	elif [ -f "$wt_dir/.git" ]; then
		read -r wt_gitdir <"$wt_dir/.git" || return 1
		wt_gitdir=${wt_gitdir#gitdir: }
		# worktree.useRelativePaths writes it relative to the worktree.
		case "$wt_gitdir" in
		/*) ;;
		*) wt_gitdir=$(CDPATH='' cd -- "$wt_dir/$wt_gitdir" 2>/dev/null && pwd -P) || return 1 ;;
		esac
		case "$wt_gitdir" in
		# Submodules point into .git/modules/ instead.
		*/worktrees/*) ;;
		*) return 1 ;;
		esac
		wt_kind=linked
		wt_main=${wt_gitdir%/worktrees/*}
		wt_main=${wt_main%/.git}
	else
		return 1
	fi
	read -r wt_head 2>/dev/null <"$wt_gitdir/HEAD" || return 1
	case "$wt_head" in
	"ref: refs/heads/"*) wt_branch=${wt_head#"ref: refs/heads/"} ;;
	*) wt_branch=detached ;;
	esac
	# shellcheck disable=SC2034 # wt_label is read by the scripts sourcing this
	if [ "$wt_kind" = linked ]; then
		wt_label="[$wt_branch] $WT_ARROW ${wt_main##*/}"
	else
		wt_label="[$wt_branch]"
	fi
}

# find_worktree_root <dir>: top of the checkout <dir> is in.
find_worktree_root() {
	wt_root=${1%/}
	while [ -n "$wt_root" ]; do
		if [ -e "$wt_root/.git" ]; then
			printf '%s\n' "$wt_root"
			return 0
		fi
		wt_root=${wt_root%/*}
	done
	return 1
}

# worktree_dir_for_branch /r/repo feat/login -> /r/repo-login
worktree_dir_for_branch() {
	printf '%s/%s-%s\n' "$(dirname -- "$1")" "${1##*/}" "${2##*/}"
}

# repo_main <dir>: main checkout of the repo <dir> is in. Calls git, so not
# for listings.
repo_main() {
	wt_common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
	case "$wt_common" in
	*/.git) printf '%s\n' "${wt_common%/.git}" ;;
	*) printf '%s\n' "$wt_common" ;; # bare repo
	esac
}
