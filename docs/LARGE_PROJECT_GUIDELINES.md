# Large Project Guidelines

## Scope Limits

This project's agents and skills are optimised for small-to-medium repositories. For large codebases, be aware of context limitations.

| Metric | Safe Range | Caution | Likely Fails |
|--------|-----------|---------|-------------|
| Files in repo | < 500 | 500-2000 | > 2000 |
| Files changed in PR | < 50 | 50-200 | > 200 |
| Single file size | < 500 lines | 500-2000 lines | > 2000 lines |
| Total changed lines | < 500 | 500-2000 | > 2000 |

## What Works Well

| Task | Limit | Strategy |
|------|-------|----------|
| Code review (single file) | Any size | Agent reads only the changed file |
| Bug fix (known location) | Any size | User points to relevant files |
| Feature design (new code) | Any size | No existing code to read |
| Text/homework tasks | Any size | Text processing is not code-bound |
| Small refactors | < 5 files changed | Agent reads targeted files |

## What Requires Manual Guidance

| Task | Problem | Workaround |
|------|---------|-----------|
| "Find the bug somewhere in this 10K-file project" | Agent cannot scan all files | User narrows down to 3-5 candidate files |
| "Review this PR with 500 changed files" | Context overflow | Break into logical sub-PRs |
| "Explain the full architecture" | Repo map too large | User selects key entry points |
| "Process a 500-page PDF" | Input exceeds context | Split document into sections |

## Tools Available

| Tool | Purpose | Script |
|------|---------|--------|
| Repo map | Skeleton index of code structure | `scripts/build-repo-map.ps1/.sh` |
| Query repo map | Search map by keyword | `scripts/query-repo-map.ps1/.sh` |
| Context compact | Compress input code/logs/configs | `skills/context-compact/SKILL.md` |
| Startup ritual | Resume from last checkpoint | `scripts/startup-ritual.ps1/.sh` |

## Best Practices

1. **Narrow the scope yourself.** Before asking an agent, identify 2-5 relevant files or directories.
2. **Use repo map first.** Build a map, query by keyword, then read only matched files.
3. **Chunk large inputs.** Split 500+ line files into logical sections (by function/class).
4. **Iterate.** Do a broad pass first (read map), then deep dive into specific files.
5. **Trust your judgment.** You know the project better than any agent — guide it to the right places.

## Weak Model Additional Limits

For weak-model agents (tier1/tier2):

| Metric | Tier1 (~7B) | Tier2 (~27B) | Tier3 (~120B) |
|--------|------------|-------------|---------------|
| Max files per step | 1 | 1 | 2 |
| Max lines per edit | 15 | 30 | 50 |
| Max plan tasks | 5 | 7 | 7 |
| Context cap | ~200 lines | ~500 lines | ~1000 lines |

Weak models cannot handle large codebase exploration effectively. Always provide specific file paths.
