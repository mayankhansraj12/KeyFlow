#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
MIN_SOURCE_COVERAGE="${KEYFLOW_MIN_SOURCE_LINE_COVERAGE:-27}"
MIN_CORE_COVERAGE="${KEYFLOW_MIN_CORE_LINE_COVERAGE:-84}"
SUMMARY="$(mktemp)"
trap 'rm -f "$SUMMARY"' EXIT

cd "$ROOT"
swift test --enable-code-coverage

BIN_DIR="$(swift build --show-bin-path)"
TEST_BINARY="$BIN_DIR/KeyFlowPackageTests.xctest/Contents/MacOS/KeyFlowPackageTests"
PROFILE="$BIN_DIR/codecov/default.profdata"
REPORT="$ROOT/.build/coverage-report.txt"

[[ -x "$TEST_BINARY" ]] || { print -u2 "Coverage test binary not found: $TEST_BINARY"; exit 1; }
[[ -f "$PROFILE" ]] || { print -u2 "Coverage profile not found: $PROFILE"; exit 1; }

xcrun llvm-cov export "$TEST_BINARY" -instr-profile "$PROFILE" -summary-only > "$SUMMARY"
xcrun llvm-cov report "$TEST_BINARY" \
    -instr-profile "$PROFILE" \
    -ignore-filename-regex='(Tests/|\.build/)' > "$REPORT"

SOURCE_COVERAGE="$(jq -r '
    [.data[0].files[]
        | select((.filename | contains("/Sources/")) or (.filename | startswith("Sources/")))
        | .summary.lines]
    | reduce .[] as $item ({count: 0, covered: 0};
        .count += $item.count | .covered += $item.covered)
    | if .count == 0 then 0 else (.covered * 100 / .count) end
' "$SUMMARY")"

CORE_COVERAGE="$(jq -r '
    [.data[0].files[]
        | select((.filename | contains("/Sources/KeyFlowCore/")) or (.filename | startswith("Sources/KeyFlowCore/")))
        | .summary.lines]
    | reduce .[] as $item ({count: 0, covered: 0};
        .count += $item.count | .covered += $item.covered)
    | if .count == 0 then 0 else (.covered * 100 / .count) end
' "$SUMMARY")"

function require_coverage() {
    local actual="$1"
    local minimum="$2"
    local label="$3"
    awk -v actual="$actual" -v minimum="$minimum" 'BEGIN { exit(actual + 0 >= minimum + 0 ? 0 : 1) }' \
        || { print -u2 "$label line coverage ${actual}% is below ${minimum}%"; exit 1; }
}

require_coverage "$SOURCE_COVERAGE" "$MIN_SOURCE_COVERAGE" "Source"
require_coverage "$CORE_COVERAGE" "$MIN_CORE_COVERAGE" "KeyFlowCore"

printf 'Coverage passed: source %.2f%% (minimum %.2f%%), KeyFlowCore %.2f%% (minimum %.2f%%)\n' \
    "$SOURCE_COVERAGE" "$MIN_SOURCE_COVERAGE" "$CORE_COVERAGE" "$MIN_CORE_COVERAGE"
print "Detailed report: $REPORT"
