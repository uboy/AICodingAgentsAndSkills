# Eval Case: gitcode-pr-review

## User Request

"Сделай ревью PR `https://gitcode.com/owner/repo/pulls/12345`: нужно скачать репозиторий и дать список проблем."

## Expected Skill

- `gitcode-pr-review`

## Pass Criteria

- Parses PR URL and derives `owner/repo/pr_id`.
- Uses local checkout/fetch + diff evidence (not PR text only).
- Reports findings ordered by severity with file references:
  - `severity | file:line | issue | impact | fix`
- If no findings, states that explicitly and includes residual risks/testing gaps.
- Does not run destructive git commands.

## Failure Examples

- Review based only on PR description/comments without diff.
- No file references in findings.
- Uses destructive commands (for example `git reset --hard`) during review.

