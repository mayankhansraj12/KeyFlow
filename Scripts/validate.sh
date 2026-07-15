#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

swift format lint --strict --recursive Sources Tests Package.swift
swift test
swift build -c release -Xswiftc -warnings-as-errors -Xcc -Werror

for script in Scripts/*.sh; do
    zsh -n "$script"
done

plutil -lint Resources/Info.plist
plutil -lint Resources/PrivacyInfo.xcprivacy
plutil -lint Resources/KeyFlow.entitlements

print "Validation passed"
