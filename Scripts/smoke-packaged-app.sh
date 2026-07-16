#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
APP_DIR="${1:-$ROOT/dist/KeyFlow.app}"
EXECUTABLE="$APP_DIR/Contents/MacOS/KeyFlowApp"
TEMP_HOME="$(mktemp -d)"
LOG_FILE="$TEMP_HOME/keyflow-smoke.log"
PID=""

function cleanup() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill -TERM "$PID" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -KILL "$PID" 2>/dev/null || true
    fi
    rm -rf "$TEMP_HOME"
}
trap cleanup EXIT INT TERM

[[ -x "$EXECUTABLE" ]] || { print -u2 "Missing packaged executable: $EXECUTABLE"; exit 1; }

HOME="$TEMP_HOME" \
KEYFLOW_DISABLE_RAW_MULTITOUCH=1 \
KEYFLOW_PERFORMANCE_SIGNPOSTS=0 \
    "$EXECUTABLE" >"$LOG_FILE" 2>&1 &
PID=$!

for _ in {1..30}; do
    if ! kill -0 "$PID" 2>/dev/null; then
        print -u2 "Packaged app exited during smoke startup"
        sed -n '1,160p' "$LOG_FILE" >&2
        exit 1
    fi
    sleep 0.1
done

if grep -Ei "fatal error|abort trap|segmentation fault|dyld.*(missing|not loaded)" "$LOG_FILE"; then
    print -u2 "Packaged app emitted a fatal startup diagnostic"
    exit 1
fi

print "Packaged app remained healthy through isolated-home startup"
