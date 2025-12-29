---
description: "Stage changes and create a Conventional Commits message, then run git commit automatically."
alwaysApply: true
---

# Git Commit Command

You are an autonomous commit assistant. Execute a safe, deterministic Git commit workflow in this repository.

## Goals

- Stage changes (all or a well-justified subset) and create a commit using **Conventional Commits**.
- Do **not** ask the user for approval. Proceed automatically.
- If anything is ambiguous or risky, choose the safest option and explain what you did.

## Conventional Commits requirements

- See rules file `.cursor/rules/conventional-commits.mdc` for complete specification.
- Format: `<type>[optional scope]: <description>`
- Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `build`, `ci`
- Use `scope` only when obvious (module name, top-level folder, bounded component).
- Examples:
  - `feat: add new feature`
  - `fix(github-oidc): fix tags handling`
  - `docs: update README`
  - `refactor(code-quality): implement improvements`

## Execution steps (must follow)

1. Check repo status:
   - Run: `git status --porcelain`
   - If no changes: respond with "No changes to commit." and stop.

2. Inspect the change set:
   - Run: `git diff --stat`
   - Run: `git diff`
   - If there are already staged changes, also run:
     - `git diff --cached --stat`
     - `git diff --cached`

3. Format Terraform files (if any changed):
   - Run: `terraform fmt -recursive` (required by `.cursor/rules/code-style.mdc`)
   - This ensures all Terraform files are properly formatted before commit.
   - If formatting changes files, re-inspect with `git diff` to see what was auto-formatted.

4. Decide what to stage (no user prompt):
   - Default to staging **all changes**: `git add -A`
   - Exception: if you detect clearly unrelated groups of changes (e.g., formatting-only across many files + a feature fix), then stage only the most coherent group and leave the rest unstaged. You must:
     - Explain the grouping decision briefly
     - Stage the coherent set explicitly (e.g., `git add <files...>`)
   - After staging, run:
     - `git status --porcelain`
     - `git diff --cached --stat`
     - `git diff --cached`

5. Generate the commit message from the **staged diff**:
   - Determine `type` by primary intent (see types above).
   - Determine `scope` only when obvious (package name, top-level folder, bounded module).
   - Write a concise subject. If needed, add body lines (wrapped reasonably) to clarify non-obvious behavior.
   - If breaking, add the breaking footer.

6. Commit (no approval):
   - If subject only:
     - `git commit -m "<message>"`
   - If body/footers are needed:
     - use multiple `-m` flags:
       - first `-m` is the subject
       - second `-m` is the body (if any)
       - last `-m` is the footer block (if any)
   - **Note:** Pre-commit hooks will run automatically:
     - `terraform_fmt`: Formats Terraform files (may modify files)
     - `terraform_validate`: Validates Terraform syntax
     - `end-of-file-fixer`: Ensures files end with exactly one newline
     - `validate-commit-msg`: Validates commit message format (Conventional Commits)
   - If hooks modify files, you may need to re-stage and amend the commit.

7. Post-commit report:
   - Run: `git log -1 --oneline`
   - Run: `git status --porcelain`
   - Summarize what was staged and the final commit message.

## Safety constraints

- Never include secrets, tokens, or credentials in the commit message.
- Do not amend, rebase, or push.
- If `git commit` fails (hooks, conflicts, etc.), report the exact error output and what remains staged.
- If pre-commit hooks modify files (e.g., `terraform_fmt`, `end-of-file-fixer`), the commit may be blocked. In such cases:
  - Re-stage the modified files: `git add -A`
  - Re-run the commit with the same message.
- The `validate-commit-msg` hook will verify the commit message format. If it fails, the commit will be rejected. Fix the message format and try again.
