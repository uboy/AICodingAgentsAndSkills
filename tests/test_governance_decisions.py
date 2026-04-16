from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_blocked_layers_decision_record_exists_and_marks_pending_owner_decision():
    decision_doc = (REPO_ROOT / "docs" / "BLOCKED-LAYERS-DECISION.md").read_text(encoding="utf-8")
    assert "BLOCKED pending owner decision" in decision_doc
    assert "## 1. Shared Agents Source-Of-Truth" in decision_doc
    assert "## 2. Promptfoo Suites And Skill Manifest Generation" in decision_doc
    assert "Option A - Restore" in decision_doc
    assert "Option B - Retire" in decision_doc


def test_readme_and_blocked_artifacts_point_to_owner_decision_record():
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    skills_readme = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
    manifest = (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8")
    promptfoo = (REPO_ROOT / "promptfooconfig.yaml").read_text(encoding="utf-8")

    assert "Blocked Layers Pending Owner Decision" in readme
    assert "docs/BLOCKED-LAYERS-DECISION.md" in readme
    assert "docs/BLOCKED-LAYERS-DECISION.md" in skills_readme
    assert "docs/BLOCKED-LAYERS-DECISION.md" in manifest
    assert "docs/BLOCKED-LAYERS-DECISION.md" in promptfoo
