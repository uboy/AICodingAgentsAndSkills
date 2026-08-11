import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_repository_status_json_parses_and_marks_current_active_layers():
    status = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))

    assert status["schema_version"] == 1

    authoritative_sources = {item["path"]: item for item in status["authoritative_sources"]}
    assert authoritative_sources["agents/"]["status"] == "active"
    assert authoritative_sources["promptfooconfig.yaml"]["status"] == "active"
    assert authoritative_sources["evals/promptfoo/suites/"]["status"] == "active"

    generators = {item["path"]: item for item in status["generators"]}
    assert generators["scripts/generate-skill-deployment-manifest.ps1"]["status"] == "active"
    assert generators["scripts/generate-skill-deployment-manifest.sh"]["status"] == "active"

    assert status["layers"] == []


def test_repository_status_json_marks_promptfoo_active_and_manifest_generated_honestly():
    status = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))

    assert status["inactive_placeholders"] == []
    assert status["static_manual_artifacts"] == []


def test_repository_status_docs_exist_and_reference_current_status_contracts():
    status_doc = (REPO_ROOT / "docs" / "REPOSITORY-STATUS.md").read_text(encoding="utf-8")
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")

    assert "Repository Status Map" in status_doc
    assert "configs/repository-status.json" in status_doc
    assert "docs/BLOCKED-LAYERS-DECISION.md" in status_doc
    assert "docs/REPOSITORY-STATUS.md" in readme
    assert "configs/repository-status.json" in readme
