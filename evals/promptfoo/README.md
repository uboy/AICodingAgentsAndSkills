# Promptfoo Suites

Tracked promptfoo suite YAML files for the active local promptfoo evaluation layer.

Scope in this first restored wave:

- `lecture-transcript`
- `homework-management`
- `case-analyzer`

These suites are narrow contract checks derived from the tracked skill cases in `evals/skills/cases/`.
They are not intended to replace the lightweight local `validate-skills` path; they complement it with a real promptfoo suite surface.

Execution model:

- `promptfooconfig.yaml` is the shared base config
- `scripts/run-promptfoo-evals.ps1`
- `scripts/run-promptfoo-evals.sh`
- `scripts/run_promptfoo_evals.py`

The runner composes the base config with each tracked suite into temporary merged promptfoo configs before execution.

Environment note:

- running these suites requires a local `promptfoo` executable
- running model-backed evals also requires a configured provider
