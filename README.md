# AI Coding Agents And Skills

> [!CAUTION]
> **MANDATORY WORKFLOW**: Every session MUST begin by acting as the **Team Lead Orchestrator** (`policy/team-lead-orchestrator.md`). 
> **Rule 21 (Orchestration)** and **Rule 18 (Lifecycle)** are not optional. 
> Non-trivial tasks require an approved plan in `.scratchpad/plan.md` before any code is modified.

Repository for shared AI coding configuration:
- Claude (`.claude/*`)
- Codex (`.codex/*`)
- Gemini (`.gemini/*`)
- Cursor (`.cursor/*`, `.cursorrules`)
- OpenCode (`.config/opencode/*`)
- global git safety templates

## License

This repository is licensed under the GNU General Public License v3.0.
See `LICENSE`.

Policy layering:
- user-level policy: `C:\Users\devl\AGENTS.md`
- project-level extension: `AGENTS.md` (this repo)

Single source of truth model:
- canonical cross-system policy: `AGENTS.md`
- system-specific files (`CLAUDE.md`, `.codex/AGENTS.md`, `CURSOR.md`, `GEMINI.md`, `OPENCODE.md`, `.cursorrules`, `.gemini/*`, `.cursor/rules/*`, `.config/opencode/*`) are thin adapters to canonical files

## Text Agent And Skills

- New Claude agent: `.claude/agents/text-editor.md`
- Shared skills:
  - `skills/text-cleanup/SKILL.md`
  - `skills/lecture-transcript/SKILL.md`
  - `skills/meeting-notes/SKILL.md`
- Skill standards/template/guardrails:
  - `skills/QUALITY-STANDARD.md`
  - `skills/_template/SKILL.md`
  - `skills/_shared/TEXT_GUARDRAILS.md`
- Prompt audit report:
  - `reviews/text-prompts-audit.md`
  - `reviews/community-skills-review.md`

## Skill Validation And Evals

Structure validator scripts:

- Windows 11: `scripts/validate-skills.ps1`
- Linux/macOS: `scripts/validate-skills.sh`

Baseline eval cases:

- `evals/skills/README.md`
- `evals/skills/cases/*.md`

Run:

```powershell
pwsh -NoProfile -File .\scripts\validate-skills.ps1
```

```bash
bash ./scripts/validate-skills.sh
```

## Coordination and Rule Enforcement

Validation for handoffs and state files (Rule 17, 21, 29):

- Windows 11: `scripts/validate-coordination.ps1`
- Linux/macOS: `scripts/validate-coordination.sh`

Checks for:
- Required sections (`## Summary`, `## Files Touched`, `## Verification`, `## Commit Message`)
- Non-empty/placeholder verification and commit blocks.

## Agent Memory and Knowledge Freshness

Policy:
- `AGENTS.md` Rule 20 (Knowledge Retention and Correction Loop)

Storage:
- `.agent-memory/index.jsonl`: compact index
- `.agent-memory/entries/<tech>/`: detailed entries

Freshness check:
- Windows 11: `scripts/check-knowledge-freshness.ps1`
- Linux/macOS: `scripts/check-knowledge-freshness.sh`

## Codex Trust Management

Utility to add the current project to the global Codex trusted list:

- Windows 11: `scripts/fix-codex-trust.ps1`
- Linux/macOS: `scripts/fix-codex-trust.sh`

## Permissions Policy Enforcement

Machine-readable profile:

- `policy/tool-permissions-profiles.json`
- `policy/model-capability-profiles.md`
- `policy/context-budget-policy.md`
- Available profiles:
  - `default`: global baseline for all systems/models
  - `weak_model`: weak-model overlay (same safety floor, stricter execution structure)
  - Codex default in this repository: `approval_policy = "never"` + `sandbox_mode = "workspace-write"` (no interactive approval prompts for in-workspace commands)

Audit scripts:

- Windows 11: `scripts/audit-permissions-policy.ps1`
- Linux/macOS: `scripts/audit-permissions-policy.sh` (requires `jq`)

Run audit:

```powershell
pwsh -NoProfile -File .\scripts\audit-permissions-policy.ps1
```

```bash
bash ./scripts/audit-permissions-policy.sh
```

Run audit with weak-model overlay:

```powershell
pwsh -NoProfile -File .\scripts\audit-permissions-policy.ps1 -ProfileName weak_model
```

```bash
bash ./scripts/audit-permissions-policy.sh --profile-name weak_model
```

Auto-apply supported fixes:

```powershell
pwsh -NoProfile -File .\scripts\audit-permissions-policy.ps1 -Apply
```

```bash
bash ./scripts/audit-permissions-policy.sh --apply
```

## Command Safety Guardrail

Policy:

- `policy/command-injection-guardrail.md`

Check scripts:

- Windows 11: `scripts/check-command-safety.ps1`
- Linux/macOS: `scripts/check-command-safety.sh`

Examples:

```powershell
pwsh -NoProfile -File .\scripts\check-command-safety.ps1 -CommandText "git status"
```

```bash
bash ./scripts/check-command-safety.sh "git status"
```

Exit codes:

- `0`: SAFE
- `10`: WARN
- `20`: BLOCK

## Security Review Gate

Policy:

- `policy/security-review-gate.md`

Gate scripts:

- Windows 11: `scripts/security-review-gate.ps1`
- Linux/macOS: `scripts/security-review-gate.sh`

Run:

```powershell
pwsh -NoProfile -File .\scripts\security-review-gate.ps1
```

```bash
bash ./scripts/security-review-gate.sh
```

## Fast Integrity Checks

Quick checks for project readiness and policy alignment:

- cross-OS script parity (`*.ps1` <-> `*.sh`)
- cross-system adapter coverage (Claude/Codex/Cursor/Gemini/OpenCode)
- script/config syntax checks
- required directory structure checks

Run full fast check:

Windows 11:

```powershell
pwsh -NoProfile -File .\scripts\run-integrity-fast.ps1
```

Linux/macOS:

```bash
bash ./scripts/run-integrity-fast.sh
```

Run parity-only check:

Windows 11:

```powershell
pwsh -NoProfile -File .\scripts\validate-parity.ps1
```

Linux/macOS:

```bash
bash ./scripts/validate-parity.sh
```

## Tool-Use Summary (Compact By Default)

Policy:

- `policy/tool-use-summary-policy.md`

Formatting scripts:

- Windows 11: `scripts/format-tool-summary.ps1`
- Linux/macOS: `scripts/format-tool-summary.sh` (requires `jq`)

Sample input:

- `coordination/tool-usage.sample.jsonl`

Compact mode:

```powershell
pwsh -NoProfile -File .\scripts\format-tool-summary.ps1 -InputFile .\coordination\tool-usage.sample.jsonl -Mode compact
```

```bash
bash ./scripts/format-tool-summary.sh --input-file ./coordination/tool-usage.sample.jsonl --mode compact
```

Full mode:

```powershell
pwsh -NoProfile -File .\scripts\format-tool-summary.ps1 -InputFile .\coordination\tool-usage.sample.jsonl -Mode full
```

```bash
bash ./scripts/format-tool-summary.sh --input-file ./coordination/tool-usage.sample.jsonl --mode full
```

## Scratchpad

Policy:

- `policy/scratchpad-policy.md`

Local transient area:

- `.scratchpad/` (tracked: `.scratchpad/README.md`, runtime files ignored by git)

## Large Codebase Context Toolkit

Policy:

- `policy/context-budget-policy.md`

Tools:

- Windows 11: `scripts/startup-ritual.ps1`, `scripts/build-repo-map.ps1`, `scripts/query-repo-map.ps1`
- Linux/macOS: `scripts/startup-ritual.sh`, `scripts/build-repo-map.sh`, `scripts/query-repo-map.sh`

Examples:

```powershell
pwsh -NoProfile -File .\scripts\startup-ritual.ps1 -Agent opencode
pwsh -NoProfile -File .\scripts\build-repo-map.ps1
pwsh -NoProfile -File .\scripts\query-repo-map.ps1 -Query ninja
```

```bash
bash ./scripts/startup-ritual.sh --agent opencode
bash ./scripts/build-repo-map.sh
bash ./scripts/query-repo-map.sh --query ninja
```

Impacted systems: Claude, Codex, Cursor, Gemini, OpenCode.

## Installer Scripts

- Windows 11: `scripts/install.ps1`
- Linux + macOS: `scripts/install.sh`

Both scripts:
- deploy config files from this repo into user home
- show diff when a target already exists
- offer conflict action: `replace`, `merge`, `keep`
- automatically create pre-install backup of user files (`install-<timestamp>`)
- configure git safety (`core.excludesfile`, `core.hooksPath`)
- can auto-install dependencies (git + gitleaks) unless disabled

## User Config Backup

Before running install/replace, you can save current user-side files that may be overwritten by this repository.

Windows:

```powershell
pwsh -NoProfile -File .\scripts\backup-user-config.ps1
```

Linux/macOS:

```bash
bash ./scripts/backup-user-config.sh
```

Options:

- custom backup root/name (`--backup-root`, `--backup-name` / `-BackupRoot`, `-BackupName`)
- dry run (`--dry-run` / `-DryRun`)

Backup output:

- timestamped backup directory (default: `~/.ai-agent-config-backups/<timestamp>`)
- copied files under `files/`
- `index.tsv` with statuses (`BACKED_UP`, `MISSING`, `SKIP_LINKED_TO_REPO`)

## Conflict Behavior

When target file already exists:

- `replace`: backup existing file, then create link to repo file
- `merge`: backup existing file, write a conflict-marked merged file (no link)
- `keep`: keep local file untouched (no link)

Important:
- if user chooses `merge` or `keep`, script **does not** create a link for that file
- if file is linked, future repo updates apply automatically

## Run

### Windows 11 (PowerShell 7)

```powershell
pwsh -NoProfile -File .\scripts\install.ps1
```

### Linux / macOS

```bash
bash ./scripts/install.sh
```

### Useful Flags

- `--conflict-action ask|replace|merge|keep` (Linux/macOS)
- `-ConflictAction ask|replace|merge|keep` (Windows)
- `--dry-run` / `-DryRun`
- `--non-interactive` / `-NonInteractive`
- `--no-deps` / `-NoDeps`

Examples:

```powershell
pwsh -NoProfile -File .\scripts\install.ps1 -DryRun -NonInteractive -NoDeps -ConflictAction keep
```

```bash
bash ./scripts/install.sh --dry-run --non-interactive --no-deps --conflict-action keep
```

## Installed Config Audit

Audit scripts compare what is installed in user home with repository sources from `deploy/manifest.txt`.

### Windows 11 (PowerShell 7)

```powershell
pwsh -NoProfile -File .\scripts\audit-installed-config.ps1
```

### Linux / macOS

```bash
bash ./scripts/audit-installed-config.sh
```

Audit output includes statuses:

- `MISSING`: target file is absent in user home
- `DIFFERENT`: target exists but content differs from repository source
- `OK-LINKED`: target is a symlink/junction to repository source
- `OK-EQUAL`: target is not linked but content is equal
- `EXTRA`: file exists in deployed target directory but has no source counterpart
- `SOURCE-MISSING`: manifest source entry is missing in repository

## Parallel Multi-Agent Workflow

Goal: run `claude` / `codex` / `gemini` (and optional `cursor`, `opencode`) in isolated contexts and synchronize via files + git.

### 1) Initialize isolated workspaces

Windows:

```powershell
pwsh -NoProfile -File .\scripts\run-multi-agent.ps1
```

Linux/macOS:

```bash
bash ./scripts/run-multi-agent.sh
```

Optional agents:

```powershell
pwsh -NoProfile -File .\scripts\run-multi-agent.ps1 -IncludeCursor -IncludeOpenCode
```

```bash
bash ./scripts/run-multi-agent.sh --include-cursor --include-opencode
```

What this does:

- creates one git worktree per agent under `.worktrees/`
- creates/uses branch `agent/<name>` for each agent
- prepares coordination folders/files under `coordination/`
- if repository has no initial commit yet, it falls back to coordination-only mode and prints a warning

### 2) Run each agent in its own console

Example:

- Console A: `cd .worktrees/claude` -> run `claude`
- Console B: `cd .worktrees/codex` -> run `codex`
- Console C: `cd .worktrees/gemini` -> run `gemini`
- Optional: `cd .worktrees/opencode` -> run `opencode`

This isolates chat/session context while keeping shared repository synchronization through git.

### 3) Sync and integrate

Report:

```powershell
pwsh -NoProfile -File .\scripts\sync-agents.ps1 -Mode report
```

Sync with optional fetch + rebase:

```powershell
pwsh -NoProfile -File .\scripts\sync-agents.ps1 -Mode sync -Fetch -Rebase
```

Integrate agent branches into base branch (clean root tree required):

```powershell
pwsh -NoProfile -File .\scripts\sync-agents.ps1 -Mode integrate -Fetch
```

Include optional agents in report/sync:

```powershell
pwsh -NoProfile -File .\scripts\sync-agents.ps1 -Mode report -IncludeCursor -IncludeOpenCode
```

Linux/macOS variants:

```bash
bash ./scripts/sync-agents.sh --mode report
bash ./scripts/sync-agents.sh --mode sync --fetch --rebase
bash ./scripts/sync-agents.sh --mode integrate --fetch
```

With optional agents:

```bash
bash ./scripts/sync-agents.sh --mode report --include-cursor --include-opencode
```

### 4) Coordination protocol

See `coordination/README.md`.

- `coordination/tasks.jsonl`: task queue
- `coordination/templates/task.weak-model.json`: strict micro-step task template for weak models
- `coordination/state/*.md`: per-agent state
- `coordination/handoffs/`: per-task outputs
- `coordination/locks/`: resource locks

### Interactive Task Generator

Standardized way to create tasks for AI agents.

Windows:
```powershell
pwsh -NoProfile -File .\scripts\generate-task.ps1
```

Linux / macOS:
```bash
bash ./scripts/generate-task.sh
```

## Manifest-Driven Deploy

Deploy map is in:

- `deploy/manifest.txt`

Format:

```text
source|target
```

- `source`: path relative to repository root
- `target`: path relative to user home
- missing `source` entries are skipped
- directory sources are deployed file-by-file (preserves per-file conflict flow)

## Git Safety Templates

Templates in repo:

- `templates/git/.gitignore_global`
- `templates/git/pre-commit`

Installer deploys them to:

- `~/.gitignore_global`
- `~/.githooks/pre-commit`

And sets:

- `git config --global core.excludesfile ~/.gitignore_global`
- `git config --global core.hooksPath ~/.githooks`
