# Feature Branch Workflow Policy

## Rule: All implementation work MUST be done on feature branches, never on `master` or `main`.

This prevents half-finished work from polluting the main branch and enables clean code review.

## Branch Naming Convention

```
feature/<short-description>
fix/<bug-description>
experiment/<idea-name>
```

Examples:
- `feature/auth-endpoint`
- `fix/null-check-validation`
- `experiment/rag-prototype`

## Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/<name> master
```

### 2. Work on the Branch

- Commit frequently with meaningful messages
- Each commit should pass tests/verification
- Use conventional commits: `feat:`, `fix:`, `chore:`, `docs:`

### 3. Keep Branch Updated

If `master` receives commits during development:

```bash
git fetch origin
git rebase origin/master   # preferred over merge
```

### 4. Verification Before Merge

Before requesting merge:
- All tests pass
- Linting/type-checking passes
- Security review gate passes (if applicable)
- No merge conflicts with `master`

### 5. Merge to Master

```bash
git checkout master
git merge --squash feature/<name>   # single commit on master
git commit -m "feat: <description>"
git push origin master
git branch -d feature/<name>        # delete local branch
git push origin --delete feature/<name>  # delete remote (if pushed)
```

**Why squash:** Master stays clean with one commit per feature, no noisy merge commits.

## Agent-Specific Rules

When an AI agent (Claude, Codex, Gemini, etc.) is implementing code:

1. **ALWAYS** create a feature branch before editing tracked files
2. **NEVER** commit directly to `master` for non-trivial changes
3. **ALWAYS** report the branch name in completion summary
4. **NEVER** delete feature branches until user confirms merge

### Trivial vs Non-Trivial

| Change Type | Branch Required? |
|------------|-----------------|
| Typo in comment | No (can commit to master) |
| Single line fix | No (can commit to master) |
| New function/method | **Yes** |
| New file | **Yes** |
| Multiple file edits | **Yes** |
| Refactoring | **Yes** |
| Dependency change | **Yes** |

## Completion Report Format

When implementation is complete:

```
## Implementation Complete

**Branch:** `feature/<name>`
**Commits:** N
**Files changed:** X files, +N/-M lines
**Verification:** all tests passed / specific commands and results

### To merge:
```bash
git checkout master
git merge --squash feature/<name>
git commit -m "feat: <description>"
git push origin master
```
```

## Enforcement

- `code-review-qa` must verify changes are on a feature branch, not master
- Security review gate warns if commits hit master directly
- CI should block direct pushes to master (branch protection)
