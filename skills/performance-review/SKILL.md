---
name: performance-review
description: Review changes for latency, throughput, memory, allocation, and scalability regressions.
---

# Skill: performance-review

## Purpose

Identify performance regressions and scalability risks in changed code.

## Use When

- User asks for performance review.
- Diff touches hot paths, loops, I/O, DB/network, rendering, or memory-heavy logic.

## Do Not Use When

- Task is purely style/format with no behavior impact.

## Input

- Changed files and expected performance constraints if known.

## Safety Rules

1. Prioritize user-visible latency and resource regressions.
2. Separate measured facts from hypotheses.
3. Do not propose risky micro-optimizations without rationale.

## Workflow

1. Locate likely hotspots introduced/affected by diff.
2. Assess CPU/memory/IO/lock contention risks.
3. Recommend targeted optimizations and benchmarks.
4. Identify required performance tests.

## Output Format

1. Findings by impact and severity.
2. Each finding: `severity | file | bottleneck | impact | fix`.
3. Benchmark/profiling plan.

## Self-Check

- Recommendations are measurable.
- Claimed bottlenecks map to concrete code paths.
