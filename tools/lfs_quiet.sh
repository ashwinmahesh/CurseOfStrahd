#!/bin/sh
# Clears Git LFS "should have been a pointer" noise in this checkout (make lfs-quiet). An old image or clip under the
# LFS paths in .gitattributes is still a plain blob in the history; when its timestamp moves (a fresh worktree, a tool
# that rewrites files unchanged) git reruns the LFS filter on it and shows it as modified although its bytes are the
# same. This refreshes the index with the LFS filter switched off for one command, so files whose bytes match the
# committed blob read as unchanged again. Real edits stay modified, and nothing is converted, staged or uploaded.
set -e
before=$(git status --porcelain --untracked-files=no | wc -l | tr -d ' ')
git -c filter.lfs.process= -c filter.lfs.clean=cat -c filter.lfs.required=false update-index -q --refresh >/dev/null || true
after=$(git status --porcelain --untracked-files=no | wc -l | tr -d ' ')
echo "lfs-quiet: $before changed file(s) shown before, $after after"
