#!/bin/bash

if [ "$#" -eq 0 ]; then
  exit 0
fi

if ! which swiftlint >/dev/null; then
    echo "⚠️ warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
    exit 0
fi

echo "Running SwiftLint on staged files..."
swiftlint lint --strict "$@"
if [ $? -ne 0 ]; then
    echo "❌ SwiftLint failed. Please fix the errors before committing."
    exit 1
fi
