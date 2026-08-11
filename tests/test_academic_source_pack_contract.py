import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_shared_academic_source_pack_contract_exists_and_mentions_prep_outputs():
    contract = (REPO_ROOT / "skills" / "_shared" / "ACADEMIC_SOURCE_PACK.md").read_text(encoding="utf-8")

    assert "scripts/study-materials-prep.py" in contract
    assert "index.json" in contract
    assert "README.md" in contract
    assert "originals/" in contract
    assert "extracted/" in contract
    assert "lecture-transcript" in contract
    assert "homework-management" in contract
    assert "case-analyzer" in contract


def test_active_academic_skills_reference_shared_source_pack_contract():
    for rel_path in [
        "skills/lecture-transcript/SKILL.md",
        "skills/homework-management/SKILL.md",
        "skills/case-analyzer/SKILL.md",
    ]:
        text = (REPO_ROOT / rel_path).read_text(encoding="utf-8")
        assert "../_shared/ACADEMIC_SOURCE_PACK.md" in text
        assert "## Preferred Source Forms" in text


def test_skills_define_consistent_but_distinct_source_handling():
    lecture = (REPO_ROOT / "skills" / "lecture-transcript" / "SKILL.md").read_text(encoding="utf-8")
    homework = (REPO_ROOT / "skills" / "homework-management" / "SKILL.md").read_text(encoding="utf-8")
    case = (REPO_ROOT / "skills" / "case-analyzer" / "SKILL.md").read_text(encoding="utf-8")

    assert "raw lecture transcript" in lecture
    assert "optional when the user already has readable transcript text or notes" in lecture

    assert "prepared Markdown source packs produced by `scripts/study-materials-prep.py`" in homework
    assert "recommended for multi-source assignments" in homework

    assert "prepared Markdown outputs from `scripts/study-materials-prep.py`" in case
    assert "recommended for multi-document cases" in case


def test_docs_and_status_represent_shared_source_pack_layer_honestly():
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    skills_readme = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
    routing = (REPO_ROOT / "policy" / "task-routing-matrix.md").read_text(encoding="utf-8")
    status_doc = (REPO_ROOT / "docs" / "REPOSITORY-STATUS.md").read_text(encoding="utf-8")
    status_json = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))
    prep_script = (REPO_ROOT / "scripts" / "study-materials-prep.py").read_text(encoding="utf-8")

    assert "skills/_shared/ACADEMIC_SOURCE_PACK.md" in readme
    assert "scripts/study-materials-prep.py" in readme
    assert "scripts/study-materials-prep.py" in skills_readme
    assert "Recommend `scripts/study-materials-prep.py` before skill execution" in routing
    assert "scripts/study-materials-prep.py" in status_doc
    assert "skills/_shared/ACADEMIC_SOURCE_PACK.md" in status_doc
    assert "shared upstream" in prep_script

    shared = {item["path"]: item for item in status_json["shared_infrastructure"]}
    assert shared["scripts/study-materials-prep.py"]["status"] == "active"
    assert shared["skills/_shared/ACADEMIC_SOURCE_PACK.md"]["status"] == "active"
