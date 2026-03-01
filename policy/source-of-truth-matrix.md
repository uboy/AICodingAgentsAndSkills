# Source Of Truth Matrix

Defines which artifact is authoritative when specifications and implementation disagree.

## Priority Rules

1. API contracts:
   - Primary: `openapi.yaml` (or equivalent API schema file)
   - Secondary: implementation code
2. Data schema:
   - Primary: migration/schema definitions (`schema.prisma`, DDL, migration files)
   - Secondary: ORM models in application code
3. Functional behavior:
   - Primary: `AGENTS.md` + feature/task docs
   - Secondary: tests
   - Tertiary: implementation
4. Process and quality gates:
   - Primary: `AGENTS.md`, `policy/*.md`, `scripts/*-gate*`
   - Secondary: templates in `coordination/templates/`

## Conflict Handling

When two sources conflict:

1. Record conflict in review report (`coordination/reviews/*.md`).
2. Stop implementation for that scope.
3. Request explicit user decision.
4. Apply the decision and update the authoritative source.

## Change Control Notes

- Existing tests are frozen by default.
- Existing architecture/design artifacts are frozen by default.
- Any exception requires user approval in `coordination/approval-overrides.json`.
