#!/bin/zsh

set -euo pipefail

REPOSITORY="${1:-mayankhansraj12/KeyFlow}"
DEFAULT_BRANCH="main"
REQUIRED_SECRETS=(
    DEVELOPER_ID_APPLICATION
    DEVELOPER_ID_P12_BASE64
    DEVELOPER_ID_P12_PASSWORD
    DEVELOPER_TEAM_ID
    RELEASE_KEYCHAIN_PASSWORD
    APP_STORE_CONNECT_API_KEY_P8
    APP_STORE_CONNECT_KEY_ID
    APP_STORE_CONNECT_ISSUER_ID
)

function fail() {
    print -u2 "GitHub production audit failed: $1"
    exit 1
}

command -v gh >/dev/null || fail "GitHub CLI is required"
command -v jq >/dev/null || fail "jq is required"
gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated"

BRANCH_PROTECTION="$(gh api "repos/$REPOSITORY/branches/$DEFAULT_BRANCH/protection")" \
    || fail "$DEFAULT_BRANCH branch protection is unavailable"
jq -e '.required_status_checks.strict == true' <<<"$BRANCH_PROTECTION" >/dev/null \
    || fail "strict required status checks are disabled"
jq -e '.required_pull_request_reviews.required_approving_review_count >= 1' <<<"$BRANCH_PROTECTION" >/dev/null \
    || fail "at least one approving review is not required"
jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' <<<"$BRANCH_PROTECTION" >/dev/null \
    || fail "CODEOWNER review is not required"
jq -e '.enforce_admins.enabled == true' <<<"$BRANCH_PROTECTION" >/dev/null \
    || fail "branch rules do not include administrators"
jq -e '.allow_force_pushes.enabled == false and .allow_deletions.enabled == false' \
    <<<"$BRANCH_PROTECTION" >/dev/null || fail "force-push or branch deletion is allowed"

gh api "repos/$REPOSITORY/environments/production" >/dev/null \
    || fail "production environment is not configured"
CONFIGURED_SECRETS="$(gh secret list --env production --repo "$REPOSITORY" --json name --jq '.[].name')"
for secret in "${REQUIRED_SECRETS[@]}"; do
    grep -qx "$secret" <<<"$CONFIGURED_SECRETS" || fail "missing production secret: $secret"
done

gh api "repos/$REPOSITORY/private-vulnerability-reporting" >/dev/null \
    || fail "private vulnerability reporting is not enabled"

REPOSITORY_STATE="$(gh api "repos/$REPOSITORY")"
jq -e '.security_and_analysis.secret_scanning.status == "enabled"' <<<"$REPOSITORY_STATE" >/dev/null \
    || fail "secret scanning is not enabled"
jq -e '.security_and_analysis.secret_scanning_push_protection.status == "enabled"' \
    <<<"$REPOSITORY_STATE" >/dev/null || fail "push protection is not enabled"

print "GitHub production controls passed for $REPOSITORY"
