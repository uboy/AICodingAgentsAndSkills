# Scratchpad Policy

Scratchpad is a local workspace for transient notes, drafts, and intermediate artifacts.

## Location

- `.scratchpad/` under repository root.

## Allowed Content

1. Temporary planning notes.
2. Intermediate transformed text.
3. Temporary command outputs required for local analysis.

## Not Allowed

1. Secrets/credentials in plaintext.
2. Long-term canonical docs (move those to `docs/`, `reviews/`, or `coordination/`).

## Lifecycle

1. Create scratchpad files only when needed.
2. Delete obsolete scratchpad files after task completion.
3. Do not treat scratchpad as source of truth.

## Version Control

- Scratchpad content is ignored by git by default.
- Keep only `.scratchpad/README.md` tracked for discoverability.
