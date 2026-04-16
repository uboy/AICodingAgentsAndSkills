---
name: api-contract-review
description: Review API/schema/interface changes for backward compatibility and consumer safety.
---

# Skill: api-contract-review

## Purpose

Validate that API contract changes are safe, explicit, and backward-compatible (or properly versioned).

## Use When

- User asks to review API changes.
- Diff touches endpoints, schemas, DTOs, error contracts, SDK interfaces.

## Do Not Use When

- Changes are strictly internal with no contract exposure.

## Input

- API/spec/schema diffs and related implementation changes.

## Safety Rules

1. Treat silent breaking changes as high risk.
2. Require explicit migration guidance for contract breaks.
3. Confirm spec and implementation consistency.

## Workflow

1. Identify changed contract surface.
2. Check compatibility, versioning, nullability/default semantics, error model.
3. Assess consumer impact and migration burden.
4. Provide fix/migration recommendations and test checks.

## Output Format

1. Contract findings by severity.
2. Each finding: `severity | contract element | break risk | affected consumers | fix/migration`.
3. Required compatibility tests and release-note actions.

## Self-Check

- Breakage findings map to exact contract elements.
- Migration steps are concrete.
