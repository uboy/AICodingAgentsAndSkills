# AICodingAgentsAndSkills

Shared configuration repository that deploys **agents, skills, policies, and validation scripts** to 7 AI coding systems on the user's machine.

## Supported Academic Scenarios

The current academic runtime core is intentionally small and source-grounded:

| Skill | Scenario | Modes |
|-------|----------|-------|
| **homework-management** | Source-grounded assignment help from provided materials | answer_plan, essay, business_case, short_answer, comparison |
| **case-analyzer** | Source-grounded case and scenario reasoning | case_brief, issue_map, options_analysis, recommendation, evidence_gaps |
| **lecture-transcript** | ASR transcript → structured materials | study_notes, narrative, review, terms, flashcards, exam_prep, outline |
| **text-humanize** | Remove AI patterns from Russian text | default |
| **text-cleanup** | Clean text preserving facts | default |

Deferred ideas such as `academic-tutor`, `thesis-assistant`, and `test-solver` are not active runtime components in this checkout.

Prepared Markdown outputs from `scripts/study-materials-prep.py` are treated as a shared upstream source-preparation layer for academic skills, especially `lecture-transcript`, `homework-management`, and `case-analyzer`.

## Academic Source Handling

Shared source-pack contract:
- `skills/_shared/ACADEMIC_SOURCE_PACK.md`
- `skills/_shared/ACADEMIC_INGESTION_WORKFLOW.md`

Use this model:
- raw lecture transcript or notes: acceptable direct input for `lecture-transcript`
- prepared Markdown source pack: preferred input for `homework-management` and `case-analyzer`
- raw curated excerpts: acceptable fallback when the material set is already small and structured

Recommend `scripts/study-materials-prep.py` before skill execution when:
- materials are spread across many files,
- archives, PDFs, scans, or OCR-heavy inputs are involved,
- the same sources will be reused across multiple academic tasks.

Agent-launched ingestion model:
- an agent or workflow may launch `scripts/study-materials-prep.py` as the shared study-material ingestion step
- the launching workflow must review `index.json` and flagged outputs before trusting the pack
- `originals/` remain available as fallback when conversion is weak
- `merged-packs/` and duplicate markers reduce clutter for downstream academic skills when safe

## Coordinator Execution Model

Shared coordinator contracts:
- `policy/execution-brief-contract.md`
- `coordination/templates/execution-brief.json`

Use this model:
- refine the raw user request into an execution brief before delegation
- include objective, output, constraints, relevant sources, prep recommendation, verification, and chunking mode
- refresh that brief during long work after verified chunks, scope changes, blockers, and resume events
- default code changes to small isolated verified chunks instead of broad monolithic passes

## Supported Systems

| System | Adapter Source | Generated Deploy Target |
|--------|----------------|-------------------------|
| **Claude Code** | `adapters/Claude/` | `out/CLAUDE.md` -> `~/CLAUDE.md` |
| **Codex CLI** | `adapters/Codex/` | `out/.codex/AGENTS.md` -> `~/.codex/AGENTS.md` |
| **Cursor** | `adapters/Cursor/` | `out/.cursorrules` + `out/.cursor/rules/*` |
| **Gemini CLI** | `adapters/Gemini/` | `out/GEMINI.md` + `out/.gemini/GEMINI.md` |
| **OpenCode** | `adapters/OpenCode/` | `out/OPENCODE.md` |
| **Qwen Code** | `adapters/Qwen/` | `out/.qwen/AGENTS.md` |
| **Cline** | `adapters/Cline/` | `out/CLINE.md` |

## How It Works

```
┌─────────────┐     ┌────────────┐     ┌─────────┐     ┌──────────┐
│  AGENTS.md   │────▶│  adapters/ │────▶│  out/   │────▶│  install │
│  (SSOT)      │     │ + skills/  │     │ (build) │     │  deploy  │
└─────────────┘     └────────────┘     └─────────┘     └──────────┘
                       source files      generated        to user's
                       (tracked)         (gitignored)     machine
```

1. **Source of truth:** `AGENTS.md` — policy rules with tier markers (hot/warm/cold)
2. **Source files:** `adapters/`, `skills/`, `agents/`, `policy/`, `scripts/`
   - the active academic runtime is skill-first: `lecture-transcript` + `homework-management` + `case-analyzer`
   - `agents/` is restored as an on-demand role layer and is generated into supported targets
3. **Build:** `sync-adapters.ps1` reads `adapters/systems.json` and generates ALL system-specific files into `out/`
4. **Generate skill manifest:** `generate-skill-deployment-manifest.ps1` / `generate-skill-deployment-manifest.sh` regenerates `deploy/skill-deployment-manifest.tsv` from `deploy/skill-deployment-map.json`
5. **Deploy:** `install.ps1` / `install.sh` links generated adapter/policy outputs from `deploy/manifest.txt` and skill runtime/library targets from `deploy/skill-deployment-manifest.tsv`

## Repository Structure

```
AGENTS.md                  ← Single source of truth (37 rules, 3 tiers)
README.md                  ← Project overview and build/deploy usage
LICENSE                    ← Repository license

agents/                    ← tracked shared role-agent source layer
  restored on-demand agents + weak-model overlays

adapters/                  ← System adapter sources
  systems.json             ← Generation rules for all 7 systems
  templates/               ← Shared templates
  Claude/                  ← Claude Code (adapter docs only)
  Codex/                   ← Codex CLI (adapter docs only)
  Cursor/                  ← Cursor (MDC rules)
  Gemini/                  ← Gemini CLI (adapter docs only)
  OpenCode/                ← OpenCode (adapter docs only)
  Qwen/                    ← Qwen Code (domain extension)

policy/                    ← repository policy files
skills/                    ← 20 active skills + shared/template support files
scripts/                   ← 15 script pairs (.ps1 + .sh)
configs/                   ← Configuration files
  subscription-limits.json ← Token monitoring config

deploy/
  manifest.txt             ← Source → destination mapping for install
  skill-deployment-manifest.tsv ← Generated tracked skill deploy/install mapping

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

```bash
# Build all generated files
bash ./scripts/sync-adapters.sh

# Install to your machine (dry run first)
bash ./scripts/install.sh --dry-run
bash ./scripts/install.sh
```

Install behavior:
- main install flow consumes both `deploy/manifest.txt` and `deploy/skill-deployment-manifest.tsv`
- regenerate the skill TSV from `deploy/skill-deployment-map.json` via `scripts/generate-skill-deployment-manifest.ps1` or `scripts/generate-skill-deployment-manifest.sh` when the JSON map changes
- before replacement, install creates a structured backup directory and a single timestamped archive under `~/.ai-agent-config-backups/`
- for bulk repo-managed replacement without per-file prompts, use `-NonInteractive -ConflictAction replace` on PowerShell or `--non-interactive --conflict-action replace` on shell
- auxiliary Qwen helper currently deploys only generated `out/.qwen/AGENTS.md`
- tool-owned runtime configs are intentionally not shipped or installed from this repository

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

The checked-in `promptfooconfig.yaml` is the shared base config for tracked suites under `evals/promptfoo/suites/`.
Run the repository wrapper to execute real promptfoo evals:

If `promptfoo` is installed locally, run:

```powershell
pwsh -File scripts/run-promptfoo-evals.ps1
```

```bash
bash ./scripts/run-promptfoo-evals.sh
```

Actual promptfoo execution still requires:
- a local `promptfoo` binary
- a configured provider that can serve the model declared in the base config or a local override

## Architecture Principles

- **Tracked sources live outside generated outputs** — adapter sources stay under `adapters/`, generated deploy files stay under `out/`
- **Every script has both .ps1 and .sh** — cross-platform by default
- **Shell scripts use LF line endings** — CRLF breaks bash on Git Bash/WSL
- **Tier system** — hot (~always loaded), warm (coding sessions), cold (rare cases) — extracted from `AGENTS.md` by `extract-agents-tier`
- **All 7 systems must be mentioned in AGENTS.md** — consistency is validated

## Academic Core

Supported academic runtime components in this checkout:
- `skills/lecture-transcript/SKILL.md`
- `skills/homework-management/SKILL.md`
- `skills/case-analyzer/SKILL.md` (library-first)

Not currently active:
- `academic-tutor`
- `thesis-assistant`
- `test-solver`

## Adding a New Agent

1. Create `agents/your-agent.md` as a role contract, not as a skill substitute.
2. Keep the boundary explicit:
   - agents define orchestration or execution roles
   - skills define narrow reusable capabilities
3. Regenerate outputs with `pwsh -File scripts/sync-adapters.ps1`.
4. Run `python -m pytest tests -q` and `pwsh -File scripts/validate-parity.ps1`.

## Adding a New Skill

1. Create `skills/your-skill/SKILL.md` following `skills/QUALITY-STANDARD.md`
2. Run `pwsh -File scripts/validate-skills.ps1` to verify

## License

See [LICENSE](LICENSE).

## Restoration Record

Previously blocked restore tracks are recorded in:
- `docs/BLOCKED-LAYERS-DECISION.md`

No blocked owner-decision layers remain in the current supported architecture.

## Repository Status

For the current supported workflow and the exact status of active, blocked, inactive, generated, and static/manual layers, see:
- `docs/REPOSITORY-STATUS.md`
- `configs/repository-status.json`
- `docs/BLOCKED-LAYERS-DECISION.md`
Install safety note: backups for replaced files are kept under `~/.ai-agent-config-backups/`, and the installer does not leave `*.backup-*` sidecar files next to live target configs.
