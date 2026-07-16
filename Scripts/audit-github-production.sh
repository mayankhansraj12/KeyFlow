#!/bin/zsh

set -euo pipefail

REPOSITORY="${1:-mayankhansraj12/KeyFlow}"
PROTECTED_BRANCHES=(
    main
    dev
)
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

function audit_branch_protection() {
    local branch="$1"
    local protection

    gh api "repos/$REPOSITORY/branches/$branch" >/dev/null \
        || fail "$branch branch is unavailable"
    protection="$(gh api "repos/$REPOSITORY/branches/$branch/protection")" \
        || fail "$branch branch protection is unavailable"
    jq -e '.required_status_checks.strict == true' <<<"$protection" >/dev/null \
        || fail "$branch does not require branches to be current before merging"
    jq -e '.required_status_checks.contexts | index("Build, test, and package") != null' \
        <<<"$protection" >/dev/null || fail "$branch is missing the required CI check"
    jq -e '.required_pull_request_reviews != null' <<<"$protection" >/dev/null \
        || fail "$branch does not require pull requests"
    jq -e '.enforce_admins.enabled == true' <<<"$protection" >/dev/null \
        || fail "$branch rules do not include administrators"
    jq -e '.required_linear_history.enabled == true' <<<"$protection" >/dev/null \
        || fail "$branch does not require linear history"
    jq -e '.required_conversation_resolution.enabled == true' <<<"$protection" >/dev/null \
        || fail "$branch does not require resolved conversations"
    jq -e '.allow_force_pushes.enabled == false and .allow_deletions.enabled == false' \
        <<<"$protection" >/dev/null \
        || fail "$branch permits force-push or deletion"

    print "Protected branch controls passed for $branch"
}

for branch in "${PROTECTED_BRANCHES[@]}"; do
    audit_branch_protection "$branch"
done

PUSH_COLLABORATOR_COUNT="$(
    gh api --paginate "repos/$REPOSITORY/collaborators?affiliation=all&per_page=100" \
        | jq -s '[.[][] | select(.permissions.push == true or .permissions.admin == true)] | length'
)"
if (( PUSH_COLLABORATOR_COUNT >= 2 )); then
    for branch in "${PROTECTED_BRANCHES[@]}"; do
        BRANCH_PROTECTION="$(gh api "repos/$REPOSITORY/branches/$branch/protection")"
        jq -e '.required_pull_request_reviews.required_approving_review_count >= 1' \
            <<<"$BRANCH_PROTECTION" >/dev/null \
            || fail "$branch does not require at least one approving review"
        jq -e '.required_pull_request_reviews.require_code_owner_reviews == true' \
            <<<"$BRANCH_PROTECTION" >/dev/null \
            || fail "$branch does not require CODEOWNER review"
    done
else
    print "Independent review gate deferred: repository has one push-capable maintainer"
fi

PRODUCTION_ENVIRONMENT="$(gh api "repos/$REPOSITORY/environments/production")" \
    || fail "production environment is not configured"
jq -e '.deployment_branch_policy.protected_branches == true' \
    <<<"$PRODUCTION_ENVIRONMENT" >/dev/null \
    || fail "production deployments are not restricted to protected branches"
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
