# Critical Review Prompt Pattern

> A prompt pattern that shifts an AI coding agent from a blind executor into a critical
> co-reviewer: before performing a task, the agent challenges the request's assumptions,
> surfaces risks, and proposes alternatives.
>
> **Source:** adapted from the "critical review mode" prompt pattern
> (`KB/01_Sources/_by_domain/ai/2026-08/codex-critical-review-prompt/`, ai-tracker KB).
> **Status:** adoptable reference, not a hard rule of this repository.

## When to apply

- Vibe-coding / rapid prototyping where scope drift is costly.
- Architectural decisions with high rework cost.
- Tasks with incomplete or contradictory requirements.
- Any context where the LLM is a co-author, not an autonomous executor.

## The pattern (7 beats)

Inject this stance into the system or turn prompt before the agent acts:

1. **Independent assessment first.** Before executing, form an independent evaluation of the
   request — do not start from the user's framing.
2. **Hunt for flawed assumptions.** Check the requirements for erroneous assumptions, logical
   problems, missing information, and hidden risks. Name them explicitly.
3. **Don't accept the default plan.** If a more reliable approach than the one requested exists,
   propose it directly.
4. **Separate epistemic layers.** Clearly distinguish confirmed facts, justified inferences,
   and unverified assumptions in your reasoning.
5. **Verify, don't fabricate.** For code, data, versions, and technical claims — verify first;
   never invent.
6. **Ask, don't fill gaps.** When information is insufficient, list the questions that must be
   answered; do not fill gaps by guessing.
7. **Assess long-term cost.** Before executing, estimate the maintenance burden and downstream
   consequences of the solution.

## Expected outcomes

- Catch problems before development (shift-left for AI-assisted work).
- Improve technical decisions by surfacing more reliable alternatives.
- Reduce rework by solving problems before code is written.

## Adoption guidance (selective, not wholesale)

Not every beat belongs in every canon. **Hard deterministic gates are stronger than soft
behavioral prompts** — a soft rule that depends on the agent's memory drifts, while a gate that
blocks at a call point does not. Map each beat to what existing policy already enforces before
adding anything:

| Beat | Typical existing enforcement | Action |
|---|---|---|
| 5. Verify, don't fabricate | Definition-of-Done with evidence; verification fields | usually already covered |
| 6. Ask, don't fill gaps | "stop on missing mapping"; reason codes; blocked-with-reason | usually already covered |
| 3. Don't accept default plan | plan-first / show-plan-before-implement gate | partly covered |
| 1. Independent assessment | pre-flight classification gate | partly covered |
| 2. Hunt flawed assumptions | — | **gap — highest leverage** |
| 4. Separate epistemic layers | — | gap, hard to enforce (advisory) |
| 7. Long-term cost | — | gap, better as a `plan.md` field |

**Rule of thumb:** encode beat #2 as a concrete one-line beat in the first-hop classification
gate (highest leverage, small footprint). Treat #4 and #7 as advisory — they drift when they
depend on the agent's memory; prefer a deterministic gate or a plan-template field over a soft
rule. Do not duplicate a hard gate as a soft rule — the soft copy rots and the hard gate stays,
so you gain drift and lose nothing.

## Relation to this repository's policy

- `policy/team-lead-orchestrator.md` — the first-hop "Classify Before Doing" gate; natural home
  for beat #2.
- `policy/agent-checkpoint-policy.md` — Definition-of-Done enforcement (beat #5).
- `policy/source-of-truth-matrix.md` — conflict resolution that supports beat #4's epistemic
  discipline (API contracts > code; schema > ORM; behavior > tests > implementation).

## Provenance

- **Original pattern:** `KB/01_Sources/_by_domain/ai/2026-08/codex-critical-review-prompt/`
  (ai-tracker KB; user-provided article, author/date unknown).
- **Selective adoption example:** ai-tracker `policy/team-lead-orchestrator.md` §3 Global
  Guardrails — "Challenge premise" (beat #2 only, commit `0c65dbb`, 2026-08-11). Beats #5 and #6
  were already enforced harder by that tracker's Checkpoint 5 and resolver reason codes; #4 and
  #7 were deliberately left out of the core canon as advisory/drift-prone.
