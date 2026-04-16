# Blocked Layers Pending Owner Decision

Last updated: 2026-04-16

This repository has two intentionally blocked layers that are no longer treated as active, reproducible parts of the supported architecture.

Status for both layers: `BLOCKED pending owner decision`

The owner must choose one outcome per layer:
- `RESTORE`: return real tracked inputs and restore a verified generation path.
- `RETIRE`: remove the layer from the supported architecture and stop presenting it as recoverable runtime behavior.

## 1. Shared Agents Source-Of-Truth

Current status:
- `BLOCKED pending owner decision`
- The shared `agents/` source layer has no canonical tracked source files in the current checkout.
- Generated agent outputs must not be treated as authoritative source data.

Why blocked:
- There is no verified tracked source directory that can safely replace `agents/`.
- Reconstructing source definitions from generated outputs would guess author intent and break source-of-truth discipline.

Option A - Restore:
- Provide the authoritative tracked source directory for shared agents.
- If `agents/` is still the intended source, restore the missing tracked files there.
- If another tracked directory is intended, update generators, manifests, and docs to point to that directory.
- Add an objective verification step that proves the generator no longer depends on an empty `agents/`.

Required inputs to restore:
- Owner confirmation of the canonical tracked source path.
- The missing tracked source files, or an explicit migration target already present in the repository.

Option B - Retire:
- Remove shared-agent deployment/install contract from supported manifests and docs.
- Keep platform-specific tracked agent artifacts only where they have their own authoritative source.
- Remove remaining warnings and compatibility scaffolding once the layer is formally out of scope.

What changes if retired:
- The repository stops presenting shared generated agent directories as deployable outputs.
- New contributors are told that shared agents are not part of the supported generation architecture.

Risk of leaving in limbo:
- Contributors may assume the repository can regenerate or deploy shared agents when it cannot.
- Stale generated outputs can be mistaken for source-of-truth.

Recommendation:
- `RETIRE` unless the owner can immediately supply the missing tracked canonical source.

## 2. Promptfoo Suites And Skill Manifest Generation

Current status:
- `BLOCKED pending owner decision`
- `promptfooconfig.yaml` is intentionally inactive because referenced suite YAML files are not present in the repository.
- `deploy/skill-deployment-manifest.tsv` is a checked-in static artifact because no authoritative manifest generator is present.

Why blocked:
- No runnable promptfoo suite set is available in the repository.
- No verified generator path exists for the skill deployment manifest.
- Recreating either contract without source artifacts would require invention.

Option A - Restore:
- Add the missing promptfoo suite YAML files and confirm the intended active entrypoint.
- Restore the authoritative generator for `deploy/skill-deployment-manifest.tsv`.
- Add runnable verification that the promptfoo path and manifest generation both work from tracked inputs.

Required inputs to restore:
- The real suite YAML files and their intended entrypoint contract.
- The authoritative manifest generator path or a replacement approved by the owner.

Option B - Retire:
- Remove promptfoo from supported workflows and docs.
- Mark the skill deployment manifest as manual/static in repository policy, not only in local comments and README text.
- Remove inactive placeholder config once no workflow points to it.

What changes if retired:
- Promptfoo is no longer presented as part of the supported eval pipeline.
- The skill deployment manifest becomes an explicitly manual repository artifact until a future redesign.

Risk of leaving in limbo:
- Contributors may try to run a non-existent promptfoo pipeline.
- Static manifest data may be mistaken for generated output and silently drift.

Recommendation:
- `RETIRE` unless the owner can provide the missing suites and manifest generator in the near term.
