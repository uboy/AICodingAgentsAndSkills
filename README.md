# AICodingAgentsAndSkills

Shared configuration repository that deploys **agents, skills, policies, and validation scripts** to 7 AI coding systems on the user's machine.

## Supported Academic Scenarios

The project includes specialized skills for educational use cases:

| Skill | Scenario | Modes |
|-------|----------|-------|
| **homework-management** | Academic assignments with source citations | essay, case, test, comparison, argumentation, terms, plan, short_answer |
| **lecture-transcript** | ASR transcript → structured materials | study_notes, narrative, review, terms, flashcards, exam_prep, outline |
| **text-humanize** | Remove AI patterns from Russian text | default |
| **text-cleanup** | Clean text preserving facts | default |
| **meeting-notes** | Meeting transcript → protocol | default |

## Supported Systems

| System | Adapter Source | Generated Deploy Target |
|--------|----------------|-------------------------|
| **Claude Code** | `adapters/Claude/` | `out/CLAUDE.md` -> `~/CLAUDE.md` |
| **Codex CLI** | `adapters/Codex/` | `out/.codex/AGENTS.md` -> `~/.codex/AGENTS.md` |
| **Cursor** | `adapters/Cursor/` | `out/.cursorrules` + `out/.cursor/rules/*` |
| **Gemini CLI** | `adapters/Gemini/` | `out/GEMINI.md` + `out/.gemini/GEMINI.md` |
| **OpenCode** | `adapters/OpenCode/` | `out/OPENCODE.md` + `out/opencode.json` |
| **Qwen Code** | `adapters/Qwen/` | `out/.qwen/AGENTS.md` |
| **Cline** | `adapters/Cline/` | `out/CLINE.md` |

## How It Works

```
┌─────────────┐     ┌────────────┐     ┌─────────┐     ┌──────────┐
│  AGENTS.md   │────▶│  adapters/ │────▶│  out/   │────▶│  install │
│  (SSOT)      │     │  + agents/ │     │ (build) │     │  deploy  │
└─────────────┘     └────────────┘     └─────────┘     └──────────┘
                       source files      generated        to user's
                       (tracked)         (gitignored)     machine
```

1. **Source of truth:** `AGENTS.md` — policy rules with tier markers (hot/warm/cold)
2. **Source files:** `adapters/`, `skills/`, `policy/`, `scripts/`
   - `agents/` is still referenced by the generator as the shared agent source layer, but this checkout does not contain canonical tracked agent definitions there.
3. **Build:** `sync-adapters.ps1` reads `adapters/systems.json` and generates ALL system-specific files into `out/`
4. **Deploy:** `install.ps1` / `install.sh` copies files from `out/` to the user's machine following `deploy/manifest.txt`

## Repository Structure

```
AGENTS.md                  ← Single source of truth (37 rules, 3 tiers)
README.md                  ← Project overview and build/deploy usage
LICENSE                    ← Repository license

agents/                    ← referenced shared agent source layer
  currently empty in this checkout; canonical tracked agent source is unresolved

adapters/                  ← System adapter sources
  systems.json             ← Generation rules for all 7 systems
  templates/               ← Shared templates
  Claude/                  ← Claude Code (settings, hooks)
  Codex/                   ← Codex CLI (config, hooks)
  Cursor/                  ← Cursor (MDC rules)
  Gemini/                  ← Gemini CLI (settings, hooks, extensions)
  OpenCode/                ← OpenCode (config)
  Qwen/                    ← Qwen Code (domain extension)

policy/                    ← repository policy files
skills/                    ← 20 active skills + shared/template support files
scripts/                   ← 15 script pairs (.ps1 + .sh)
configs/                   ← Configuration files
  subscription-limits.json ← Token monitoring config

deploy/
  manifest.txt             ← Source → destination mapping for install

coordination/              ← Coordination templates and protocols

out/                       ← BUILD OUTPUT (gitignored)
  CLAUDE.md, CURSOR.md, GEMINI.md, OPENCODE.md, .cursorrules, CLINE.md
  .claude/, .codex/, .cursor/, .gemini/, .opencode/, .qwen/
  AGENTS-hot.md, AGENTS-warm.md, AGENTS-cold.md
```

## Quick Start

```powershell
# Build all generated files
pwsh -File scripts/sync-adapters.ps1

# Run all validations
pwsh -File scripts/run-integrity-fast.ps1

# Install to your machine (dry run first)
pwsh -File scripts/install.ps1 -DryRun
pwsh -File scripts/install.ps1
```

## Validation Commands

| Command | What it checks |
|---------|---------------|
| `pwsh -File scripts/sync-adapters.ps1` | Regenerates all files in `out/` |
| `pwsh -File scripts/run-integrity-fast.ps1` | Full build + all validations |
| `pwsh -File scripts/validate-skills.ps1` | All tracked skills have required sections and eval-case files |
| `pwsh -File scripts/validate-coordination.ps1` | Coordination templates are valid |
| `pwsh -File scripts/validate-parity.ps1` | Generated adapters exist, stay thin, reference policy, and contain no unresolved template markers |
| `bash -n scripts/*.sh` | Syntax check all shell scripts |

## Eval Framework

Repository-backed automated coverage currently comes from:

- `python -m pytest tests -q`
- structural skill cases under `evals/skills/cases/`

```powershell
python -m pytest tests -q
```

The checked-in `promptfooconfig.yaml` still references suite files that are not present in this checkout, so promptfoo is not currently a reliable runnable evaluation entrypoint.

## Architecture Principles

- **Tracked sources live outside generated outputs** — adapter sources stay under `adapters/`, generated deploy files stay under `out/`
- **Every script has both .ps1 and .sh** — cross-platform by default
- **Shell scripts use LF line endings** — CRLF breaks bash on Git Bash/WSL
- **Tier system** — hot (~always loaded), warm (coding sessions), cold (rare cases) — extracted from `AGENTS.md` by `extract-agents-tier`
- **All 6 systems must be mentioned in AGENTS.md** — consistency is validated

## Adding a New Agent

The shared `agents/` source layer is currently unresolved in this checkout. Do not add generated agent outputs as a substitute for missing canonical tracked source files.

## Adding a New Skill

1. Create `skills/your-skill/SKILL.md` following `skills/QUALITY-STANDARD.md`
2. Run `pwsh -File scripts/validate-skills.ps1` to verify

## License

See [LICENSE](LICENSE).
# Blocked Layers Pending Owner Decision

The following layers are intentionally blocked and are not part of the currently supported reproducible pipeline:
- shared agents source-of-truth
- promptfoo suites / skill manifest generation

Owner decision package:
- see `docs/BLOCKED-LAYERS-DECISION.md`
- each layer requires an explicit `RESTORE` or `RETIRE` decision

Until that decision is made, contributors must not treat these layers as active architecture.
# Repository Status

For the current supported workflow and the exact status of active, blocked, inactive, generated, and static/manual layers, see:
- `docs/REPOSITORY-STATUS.md`
- `configs/repository-status.json`
- `docs/BLOCKED-LAYERS-DECISION.md`
