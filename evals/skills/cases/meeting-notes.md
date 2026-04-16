# Eval Case: meeting-notes

## Input Scenario

Meeting transcript where:
- some participants are named,
- one decision is explicit,
- several tasks are discussed but one has no owner and no due date.

## Acceptance Checks

1. Output includes `Meeting Metadata`, `Key Points`, `Decisions`, `Action Items`, `Open Questions / Risks`.
2. Missing owner/due date fields are explicitly `not specified`.
3. Decisions are separated from discussion bullets.
4. No fabricated participants or deadlines.
5. Action items are concrete and source-grounded.
