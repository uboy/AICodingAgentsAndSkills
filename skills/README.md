# Skills

Shared reusable skills for AI agents in this repository.

Deployment model:

- canonical source of truth: `skills/`
- cross-system deploy mapping: `deploy/skill-deployment-map.json`
- checked-in static deploy manifest: `deploy/skill-deployment-manifest.tsv`
- `always_on` skills are auto-deployed into runtime skill paths
- the broader catalog is deployed into per-system `skill-library` paths for explicit/on-demand use
- deprecated skills remain in repo only until fully retired and are removed from active runtime/library targets during install
- installers/audits/backups consume the checked-in TSV manifest, and tests must keep it synced with the canonical JSON mapping
- no manifest generator is currently present in this checkout; treat the TSV manifest as a manually maintained tracked artifact until an authoritative generator is restored

Current `always_on` set:

- `agent-system-coach`
- `code-review`
- `lecture-transcript`
- `meeting-notes`
- `text-cleanup`

All other active skills are library-first and should be selected explicitly by task intent.

## Standards And Shared Components

- Quality baseline: `skills/QUALITY-STANDARD.md`
- New skill template: `skills/_template/SKILL.md`
- Shared guardrails for text workflows: `skills/_shared/TEXT_GUARDRAILS.md`
- Shared rules for homework/academic skills: `skills/_shared/HOMEWORK_BASE.md`

## Available Skills

- `text-cleanup`: constrained text editing and normalization.
- `text-humanize`: transform AI-generated Russian text into natural human-sounding prose, removing template patterns, forbidden phrases, and fixing typography.
- `lecture-transcript`: unified lecture transcript processing with mode-based output.
- `meeting-notes`: meeting transcript extraction into structured decisions and actions.
- `homework-management`: source-grounded academic homework for management program (essays, business cases, presentations) with explicit citations from lectures and materials.
- `code-review`: generic PR/commit/local code review workflow with severity-based findings.
- `android-code-review`: Android-focused review for correctness, lifecycle safety, performance, security, and tests.
- `ios-code-review`: iOS-focused review for correctness, lifecycle safety, performance, security, and tests.
- `java-code-review`: Java-focused review for correctness, concurrency safety, performance, security, and tests.
- `performance-review`: performance-focused review for regressions, bottlenecks, and scalability risks.
- `security-review`: security-focused review for vulnerabilities, trust boundaries, and secret handling.
- `ci-failure-debugger`: root-cause analysis workflow for CI failures with minimal fix plans.
- `api-contract-review`: API compatibility and schema contract review.
- `build-system-analysis`: analyze large multi-tool build pipelines and produce target-change recipes.
- `large-codebase-context`: context-budgeted workflow for reliable work in very large repositories.
- `agent-system-coach`: teaches safe and efficient multi-agent workflow, verification commands, review discipline, and rule-refresh process.
- `task-specifier`: improve one tracker task description via guiding questions, recommendations, and a clean final draft.
- `openharmony-task-specifier`: OpenHarmony/ArkUI/Ace-specific task description assistant with lifecycle/performance risk checks.
- `task-progress`: interactive assistant for writing high-quality English task progress comments (ArkUI/OpenHarmony focus, questions in Russian).
- `gitcode-pr-workflow`: developer-facing GitCode PR workflow through existing `gitee_util` automation, including live PR URL state inspection, comment/reply flows, OpenHarmony bot and `self check` interpretation, DCP/static-check handling, build-status summaries, and follow-up patchset guidance.
- `gitcode-pr-review`: review GitCode PR by URL using local checkout/diff evidence, existing PR comments, service-comment classification, OpenHarmony bot/self-check summaries, DCP static-check extraction, build-status fallback handling, and PR-level code-specific comment guidance.

## External Skills

You can fetch additional skills from the OpenAI repository using the provided scripts:

- Windows: `pwsh -NoProfile -File .\scripts\fetch-openai-skills.ps1`
- Linux/macOS: `bash ./scripts/fetch-openai-skills.sh`

Supported flags:
- `-DryRun` / `--dry-run`: show what would be done.
- `-Force` / `--force`: overwrite existing skills.

## Why this structure

- Reduces duplicate prompts with overlapping logic.
- Keeps one canonical rule set per task family.
- Makes outputs more predictable for automation and review.
# Owner Decision Pending

The promptfoo/eval path and skill-manifest generation path are intentionally blocked pending owner decision.
See `docs/BLOCKED-LAYERS-DECISION.md` before treating either path as active.
