import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_repository_status_json_parses_and_marks_blocked_layers():
    status = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))

    assert status["schema_version"] == 1

    layers = {layer["id"]: layer for layer in status["layers"]}
    assert layers["shared_agents_source_of_truth"]["status"] == "blocked"
    assert layers["shared_agents_source_of_truth"]["requires_owner_decision"] is True
    assert layers["promptfoo_eval_and_skill_manifest_generation"]["status"] == "blocked"
    assert layers["promptfoo_eval_and_skill_manifest_generation"]["requires_owner_decision"] is True


def test_repository_status_json_marks_inactive_and_static_artifacts_honestly():
    status = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))

    inactive = {item["path"]: item for item in status["inactive_placeholders"]}
    static_manual = {item["path"]: item for item in status["static_manual_artifacts"]}

    assert inactive["promptfooconfig.yaml"]["runnable"] is False
    assert inactive["promptfooconfig.yaml"]["status"] == "inactive"
    assert static_manual["deploy/skill-deployment-manifest.tsv"]["generated"] is False
    assert static_manual["deploy/skill-deployment-manifest.tsv"]["authoritative_generator_present"] is False


def test_repository_status_docs_exist_and_reference_current_status_contracts():
    status_doc = (REPO_ROOT / "docs" / "REPOSITORY-STATUS.md").read_text(encoding="utf-8")
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")

    assert "Repository Status Map" in status_doc
    assert "configs/repository-status.json" in status_doc
    assert "docs/BLOCKED-LAYERS-DECISION.md" in status_doc
    assert "docs/REPOSITORY-STATUS.md" in readme
    assert "configs/repository-status.json" in readme
