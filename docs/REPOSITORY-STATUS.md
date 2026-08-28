# Repository Status Map

Last updated: 2026-04-17

This document describes the repository as it exists now.
It is not a future design document.

## Authoritative Source-Of-Truth

Supported authoritative inputs:
- `AGENTS.md` - repository policy and behavior contract
- `adapters/systems.json` - adapter generation manifest
- `adapters/*` - platform-specific adapter source files referenced by `adapters/systems.json`
- `skills/*` - tracked skill source content
- `agents/*` - tracked on-demand role-agent source content
- `deploy/skill-deployment-map.json` - tracked mapping from skills to target systems

Not authoritative:
- `out/*` generated outputs
- inactive placeholders
- checked-in generated artifacts that are outputs, not source-of-truth

## Supported Generators

Supported generator entrypoints:
- `scripts/sync-adapters.ps1` - canonical adapter generation path
- `scripts/sync-adapters.sh` - shell entrypoint; delegates to the PowerShell generator when available
- `scripts/generate-skill-deployment-manifest.ps1` - canonical skill deployment manifest generator
- `scripts/generate-skill-deployment-manifest.sh` - shell entrypoint for the same manifest generator

Supported deployment/install entrypoints:
- `scripts/install.ps1` - installs generated adapter/config outputs plus skill runtime/library targets from the tracked deploy manifests
- `scripts/install.sh` - shell installer for the same supported deploy surface
- `scripts/audit-installed-config.ps1` - verifies installed home-directory state against both deploy manifests
- `scripts/audit-installed-config.sh` - shell audit entrypoint for the same installed-state check

Shared academic infrastructure:
- `scripts/study-materials-prep.py` - shared source-preparation layer for academic skills
- `skills/_shared/ACADEMIC_SOURCE_PACK.md` - shared source-pack contract for academic runtime consumers
- `skills/_shared/ACADEMIC_INGESTION_WORKFLOW.md` - shared agent-launched ingestion, verification, fallback, and consolidation contract

Shared coordinator infrastructure:
- `policy/execution-brief-contract.md` - request refinement, anti-drift refresh, and chunked execution contract
- `coordination/templates/execution-brief.json` - machine-readable execution-brief template for downstream delegation

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
- active shared agents must stay in deploy/install contracts
- `deploy/skill-deployment-manifest.tsv` must stay in sync with `deploy/skill-deployment-map.json`
- promptfoo entrypoint must reference real tracked suite YAML files

## Blocked Layers

There are currently no blocked owner-decision layers in the supported reproducible architecture.

## Active Eval Entry Points

- `promptfooconfig.yaml`
  - Status: active tracked promptfoo base config
  - Suite sources: `evals/promptfoo/suites/*`
  - Runtime note: actual execution is performed through `scripts/run-promptfoo-evals.ps1` / `.sh`, and still requires a local `promptfoo` binary plus a configured provider

## Generated / Checked-In Artifacts

- `deploy/skill-deployment-manifest.tsv`
  - Status: checked-in generated artifact
  - Canonical source: `deploy/skill-deployment-map.json`
  - Generator: `scripts/generate-skill-deployment-manifest.ps1` / `.sh`

## Generated Outputs

- `out/*`
  - Status: generated
  - These files are outputs of the supported adapter pipeline, not the canonical source-of-truth

## Operational Reading Guide

If a contributor needs to know whether a layer is active:
- read `configs/repository-status.json` for machine-readable status
- read `docs/BLOCKED-LAYERS-DECISION.md` for blocked-layer owner decisions
- treat `AGENTS.md`, `adapters/systems.json`, `adapters/*`, `skills/*`, `agents/*`, and `deploy/skill-deployment-map.json` as the current tracked sources unless a file explicitly says otherwise

## Adapter Pipeline Repair, 2026-08-28

Three defects were making the adapter pipeline generate a partial `out/` and the pre-commit
integrity gate fail on every commit. All three came in with the April history-rewrite
recovery, not with a deliberate change.

1. **`adapters/systems.json` was not valid JSON.** The `Cursor` block ended with a stray `}`
   left over from the deleted `settings`/`hooks` entries, and the file was missing its final
   closing brace. Everything after the `Cursor` block — Gemini, OpenCode, Qwen, Cline,
   `shared_agents`, `tier_files` — was unreachable, so those adapters were never generated.
   Both braces are fixed; the file parses again.
2. **`scripts/sync-adapters.ps1` read two config keys one level too high.** It used
   `$Config.shared_agents` and `$Config.tier_files`, but both live under `$Config.systems`.
   The agents copy step was therefore skipped for every system. Both paths are corrected.
3. **`CURSOR.md` had no entry in `systems.json`.** `scripts/sync-adapters.sh` writes it from
   a hardcoded block, the data-driven PowerShell generator did not, and `validate-parity`
   requires it — so the gate failed on Windows only. The output is now declared in the
   `Cursor` block, and both generators produce it.

Also added: **`.gitattributes` pinning `*.sh` to LF.** With `core.autocrlf=true` on a Windows
checkout every shell script arrived with CRLF, and bash refused them with
`set: pipefail\r: invalid option name`. Windows-native `*.ps1`, `*.cmd` and `*.bat` stay CRLF.

Result: `bash scripts/run-integrity-fast.sh` reports `PASS=1 WARN=0 FAIL=0` and generates 99
files, against 51 files and `FAIL=7` before the repair.

**Still failing, not repaired:**
`tests/test_validate_coordination_contract.py::test_bash_rejects_false_commit_pending_claim_if_bash_is_usable`
fails on a Windows checkout. The test hands a Windows temp path to
`scripts/validate-coordination.sh`; the script then reports `No local handoffs found` for a
directory that does exist. It reproduces on a clean clone and is unrelated to the fixes above.
