from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_blocked_layers_decision_record_exists_and_tracks_only_remaining_pending_layer():
    decision_doc = (REPO_ROOT / "docs" / "BLOCKED-LAYERS-DECISION.md").read_text(encoding="utf-8")
    assert "## Restored Layers" in decision_doc
    assert "Shared Agents Source-Of-Truth" in decision_doc
    assert "RESTORED on 2026-04-17" in decision_doc
    assert "Skill Deployment Manifest Generation" in decision_doc
    assert "Promptfoo Suites And Active Entrypoint" in decision_doc
    assert "## Remaining Blocked Layers" in decision_doc
    assert "None currently." in decision_doc
    assert "Option A - Restore" not in decision_doc
    assert "Option B - Retire" not in decision_doc


def test_readme_and_blocked_artifacts_point_to_owner_decision_record():
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    skills_readme = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
    manifest = (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8")
    promptfoo = (REPO_ROOT / "promptfooconfig.yaml").read_text(encoding="utf-8")

    assert "## Restoration Record" in readme
    assert "Blocked Layers Pending Owner Decision" not in readme
    assert "docs/BLOCKED-LAYERS-DECISION.md" in readme
    assert "docs/BLOCKED-LAYERS-DECISION.md" in skills_readme
    assert "inactive promptfoo placeholder" not in promptfoo
