# Repository Status Map

Last updated: 2026-04-16

This document describes the repository as it exists now.
It is not a future design document.

## Authoritative Source-Of-Truth

Supported authoritative inputs:
- `AGENTS.md` - repository policy and behavior contract
- `adapters/systems.json` - adapter generation manifest
- `adapters/*` - platform-specific adapter source files referenced by `adapters/systems.json`
- `skills/*` - tracked skill source content
- `deploy/skill-deployment-map.json` - tracked mapping from skills to target systems

Not authoritative:
- `out/*` generated outputs
- inactive placeholders
- checked-in static/manual artifacts without an authoritative generator

## Supported Generators

Supported generator entrypoints:
- `scripts/sync-adapters.ps1` - canonical adapter generation path
- `scripts/sync-adapters.sh` - shell entrypoint; delegates to the PowerShell generator when available

Supported generated outputs:
- `out/*` platform adapter outputs produced by the adapter generation pipeline

## Supported Validators And Regression Checks

Supported validation paths:
- `scripts/validate-parity.ps1`
- `scripts/validate-parity.sh`
- `scripts/run-integrity-fast.ps1`
- `python -m pytest tests -q`

High-signal regression coverage currently includes:
- generated adapters must not contain unresolved template markers
- declared TOML config must parse as TOML
- blocked layers must stay out of active deploy/install contracts
- inactive placeholder configs must not point to missing runnable suites
- blocked layers must remain marked as pending owner decision

## Blocked Layers

The following layers are intentionally blocked and are not part of the supported reproducible architecture:

1. Shared agents source-of-truth
- Status: `BLOCKED pending owner decision`
- Reason: `agents/` has no canonical tracked source files
- Decision package: `docs/BLOCKED-LAYERS-DECISION.md`

2. Promptfoo / eval suites / skill manifest generation
- Status: `BLOCKED pending owner decision`
- Reason: promptfoo suite YAML files and the authoritative skill-manifest generator are not present
- Decision package: `docs/BLOCKED-LAYERS-DECISION.md`

## Inactive Placeholders

- `promptfooconfig.yaml`
  - Status: inactive placeholder
  - It must not be treated as a runnable eval workflow unless the owner restores the missing suite set

## Static / Manual Artifacts

- `deploy/skill-deployment-manifest.tsv`
  - Status: checked-in static/manual artifact
  - It must not be described as generated until an authoritative generator exists again

## Generated Outputs

- `out/*`
  - Status: generated
  - These files are outputs of the supported adapter pipeline, not the canonical source-of-truth

## Operational Reading Guide

If a contributor needs to know whether a layer is active:
- read `configs/repository-status.json` for machine-readable status
- read `docs/BLOCKED-LAYERS-DECISION.md` for blocked-layer owner decisions
- treat `AGENTS.md`, `adapters/systems.json`, `adapters/*`, `skills/*`, and `deploy/skill-deployment-map.json` as the current tracked sources unless a file explicitly says otherwise
