#!/bin/bash

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Allow merge commits
if echo "$COMMIT_MSG" | grep -qE '^Merge branch'; then
    exit 0
fi

# Conventional commit pattern regex: feat|fix|perf|refactor|docs|test|chore|ci|style|build|revert(\(scope\))?!?: message
CONVENTIONAL_REGEX='^(feat|fix|perf|refactor|docs|test|chore|ci|style|build|revert)(\([a-zA-Z0-9_-]+\))?!?: .+$'

if ! echo "$COMMIT_MSG" | grep -qE "$CONVENTIONAL_REGEX"; then
    echo ""
    echo "❌ INVALID COMMIT MESSAGE FORMAT!"
    echo "--------------------------------------------------------"
    echo "Your commit message: \"$COMMIT_MSG\""
    echo ""
    echo "Commit messages must follow Conventional Commits format:"
    echo "  <type>(<optional-scope>): <description>"
    echo ""
    echo "Examples:"
    echo "  feat: add player AI Insights capsule button"
    echo "  fix(library): resolve bookshelf pagination state bug"
    echo "  perf: parallelize network requests in viewmodel"
    echo "  chore: update dependencies"
    echo "--------------------------------------------------------"
    exit 1
fi

exit 0
