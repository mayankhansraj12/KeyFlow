#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
INFO_PLIST="$ROOT/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
EXPECTED_TAG="v$VERSION"
BRANCH="${RELEASE_BRANCH:-main}"
REMOTE="${RELEASE_REMOTE:-origin}"

function fail() {
    print -u2 "Release preflight failed: $1"
    exit 1
}

git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || fail "the source directory is not a Git worktree"
[[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ]] \
    || fail "the working tree must be clean, including untracked files"

HEAD_COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
TAG_COMMIT="$(git -C "$ROOT" rev-parse "$EXPECTED_TAG^{commit}" 2>/dev/null)" \
    || fail "create the signed release tag $EXPECTED_TAG on the reviewed commit"
[[ "$TAG_COMMIT" == "$HEAD_COMMIT" ]] \
    || fail "$EXPECTED_TAG points to $TAG_COMMIT instead of HEAD $HEAD_COMMIT"
git -C "$ROOT" verify-tag "$EXPECTED_TAG" >/dev/null 2>&1 \
    || fail "$EXPECTED_TAG must be a cryptographically signed annotated tag"

REMOTE_BRANCH_COMMIT="$(git -C "$ROOT" ls-remote --exit-code "$REMOTE" "refs/heads/$BRANCH" | awk 'NR == 1 { print $1 }')" \
    || fail "could not verify $REMOTE/$BRANCH"
[[ "$REMOTE_BRANCH_COMMIT" == "$HEAD_COMMIT" ]] \
    || fail "$REMOTE/$BRANCH is $REMOTE_BRANCH_COMMIT instead of HEAD $HEAD_COMMIT"

REMOTE_TAG_COMMIT="$(git -C "$ROOT" ls-remote --exit-code "$REMOTE" "refs/tags/$EXPECTED_TAG^{}" | awk 'NR == 1 { print $1 }')" \
    || fail "the signed tag $EXPECTED_TAG has not been pushed to $REMOTE"
[[ "$REMOTE_TAG_COMMIT" == "$HEAD_COMMIT" ]] \
    || fail "the pushed tag $EXPECTED_TAG resolves to $REMOTE_TAG_COMMIT instead of HEAD $HEAD_COMMIT"

"$ROOT/Scripts/audit-production.sh"
print "Release source preflight passed ($EXPECTED_TAG, $HEAD_COMMIT)"
