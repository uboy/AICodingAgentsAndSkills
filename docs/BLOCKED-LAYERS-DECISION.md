# Blocked Layers Pending Owner Decision

Last updated: 2026-04-17

This repository now has one remaining intentionally blocked layer. Shared tracked `agents/` sources were restored and are again part of the supported reproducible architecture.

The owner must choose one outcome for each blocked layer:
- `RESTORE`: return real tracked inputs and restore a verified generation path.
- `RETIRE`: remove the layer from the supported architecture and stop presenting it as recoverable runtime behavior.

## Restored Layers

### Shared Agents Source-Of-Truth

Current status:
- `RESTORED on 2026-04-17`
- `agents/` is again a tracked canonical source directory.
- Generated `.claude/agents`, `.codex/agents`, `.gemini/.../agents`, and `.opencode/agents` outputs may now be treated as supported deploy/install artifacts.

Restoration notes:
- Restored tracked role-agent files under `agents/*.md`
- Restored tracked weak-model overlays under `agents/weak-model/*.md`
- Re-enabled agent deploy paths in `deploy/manifest.txt`
- Updated repository status docs and regression checks to treat `agents/` as active source-of-truth

### Skill Deployment Manifest Generation

Current status:
- `RESTORED on 2026-04-17`
- `deploy/skill-deployment-manifest.tsv` is generated from `deploy/skill-deployment-map.json`.

Restoration notes:
- Added `scripts/generate-skill-deployment-manifest.ps1`
- Added `scripts/generate-skill-deployment-manifest.sh`
- Added deterministic generation from the JSON deploy map
- Updated docs/status/tests to stop treating the TSV as manual/static

### Promptfoo Suites And Active Entrypoint

Current status:
- `RESTORED on 2026-04-17`
- `promptfooconfig.yaml` is an active tracked entrypoint again.
- Tracked suites exist under `evals/promptfoo/suites/`.

Restoration notes:
- Added `evals/promptfoo/README.md`
- Added first-wave academic core suites for:
  - `lecture-transcript`
  - `homework-management`
  - `case-analyzer`
- Replaced the inactive placeholder root config with an active promptfoo config that references the restored suites

## Remaining Blocked Layers

None currently.
