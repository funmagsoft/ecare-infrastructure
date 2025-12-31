#!/usr/bin/env bash

validate_conventional_commit() {
  local commit_msg="$1"
  local pattern='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}'

  if [[ ! "$commit_msg" =~ $pattern ]]; then
    log_error "Commit message does not follow Conventional Commits format"
    log_info "Expected format: type(scope): description"
    log_info "Valid types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    return 1
  fi
  return 0
}
