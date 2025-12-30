#!/usr/bin/env bash
# ============================================================================
# Validate Commit Message
# ============================================================================
# Validates that commit messages follow the Conventional Commits format:
# <type>[optional scope]: <description>
#
# Types: feat, fix, docs, style, refactor, perf, test, chore, build, ci
#
# This script is used by pre-commit hooks and can be called directly for
# manual validation.
#
# Usage:
#   ./validate-commit-msg.sh <commit-msg-file>

# ============================================================================
# Get Commit Message File Path
# ============================================================================
# Pre-commit passes the commit message file as the first argument
if [ -n "$1" ] && [ -f "$1" ]; then
    commit_msg_file="$1"
elif [ -n "$COMMIT_MSG_FILE" ] && [ -f "$COMMIT_MSG_FILE" ]; then
    commit_msg_file="$COMMIT_MSG_FILE"
else
    # Fallback: try to read from .git/COMMIT_EDITMSG (if available)
    if [ -f ".git/COMMIT_EDITMSG" ]; then
        commit_msg_file=".git/COMMIT_EDITMSG"
    else
        echo "Error: Cannot find commit message file" >&2
        exit 1
    fi
fi

# ============================================================================
# Read and Validate Commit Message
# ============================================================================
# Read commit message (first line only for validation)
commit_msg=$(head -n1 "$commit_msg_file" 2>/dev/null || echo "")

# Pattern: type(scope): description
# Examples: feat: add feature, fix(module): fix bug, docs: update README
pattern="^(feat|fix|docs|style|refactor|perf|test|chore|build|ci)(\(.+\))?: .+"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Commit message must follow Conventional Commits format:"
    echo "  <type>[optional scope]: <description>"
    echo ""
    echo "Valid types: feat, fix, docs, style, refactor, perf, test, chore, build, ci"
    echo ""
    echo "Examples:"
    echo "  feat: add new feature"
    echo "  fix(github-oidc): fix tags handling"
    echo "  docs: update README"
    echo "  refactor(code-quality): implement improvements"
    echo ""
    echo "Your commit message:"
    echo "  $commit_msg"
    echo ""
    exit 1
fi

exit 0

