import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_ingestion_workflow_contract_and_status_are_active():
    workflow = (REPO_ROOT / "skills" / "_shared" / "ACADEMIC_INGESTION_WORKFLOW.md").read_text(encoding="utf-8")
    source_pack = (REPO_ROOT / "skills" / "_shared" / "ACADEMIC_SOURCE_PACK.md").read_text(encoding="utf-8")
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    skills_readme = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
    routing = (REPO_ROOT / "policy" / "task-routing-matrix.md").read_text(encoding="utf-8")
    status_doc = (REPO_ROOT / "docs" / "REPOSITORY-STATUS.md").read_text(encoding="utf-8")
    status_json = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))

    assert "scripts/study-materials-prep.py" in workflow
    assert "verify" in workflow.lower()
    assert "originals/" in workflow
    assert "duplicate_of" in workflow
    assert "merged-packs/" in workflow

    assert "ACADEMIC_INGESTION_WORKFLOW.md" in source_pack
    assert "prepared_trusted" in source_pack
    assert "review_needed" in source_pack
    assert "original_fallback_required" in source_pack

    assert "ACADEMIC_INGESTION_WORKFLOW.md" in readme
    assert "agent or workflow may launch `scripts/study-materials-prep.py`" in readme
    assert "review `index.json`" in readme

    assert "ACADEMIC_INGESTION_WORKFLOW.md" in skills_readme
    assert "review `index.json`, `README.md`, and any `review_needed` entries" in skills_readme

    assert "review `index.json`, `README.md`, and any `review_needed` entries" in routing
    assert "Keep `originals/` available as fallback" in routing
    assert "ACADEMIC_INGESTION_WORKFLOW.md" in status_doc

    shared = {item["path"]: item for item in status_json["shared_infrastructure"]}
    assert shared["skills/_shared/ACADEMIC_INGESTION_WORKFLOW.md"]["status"] == "active"


def test_active_academic_skills_align_to_trusted_vs_review_needed_sources():
    lecture = (REPO_ROOT / "skills" / "lecture-transcript" / "SKILL.md").read_text(encoding="utf-8")
    homework = (REPO_ROOT / "skills" / "homework-management" / "SKILL.md").read_text(encoding="utf-8")
    case = (REPO_ROOT / "skills" / "case-analyzer" / "SKILL.md").read_text(encoding="utf-8")

    for text in (lecture, homework, case):
        assert "prepared_trusted" in text
        assert "review_needed" in text
        assert "originals/" in text


def test_study_materials_prep_marks_review_needed_duplicates_and_merged_packs(tmp_path):
    source = tmp_path / "sources"
    output = tmp_path / "prepared"
    source.mkdir()

    module_dir = source / "module-a"
    module_dir.mkdir()
    (module_dir / "part1.txt").write_text(
        "Market entry case notes. The company considers expansion into a neighboring region. "
        "Costs are moderate and the teaching note stresses channel risk and staffing constraints.",
        encoding="utf-8",
    )
    (module_dir / "part2.txt").write_text(
        "Additional lecture-derived evidence. Students should compare timing, operating capacity, "
        "and partner dependence before recommending a phased rollout in the case discussion.",
        encoding="utf-8",
    )

    dup_dir = source / "dups"
    dup_dir.mkdir()
    duplicate_text = (
        "This duplicate packet contains the same source paragraph about procurement delays, "
        "supplier concentration, and working-capital pressure for the scenario analysis."
    )
    (dup_dir / "dup1.txt").write_text(duplicate_text, encoding="utf-8")
    (dup_dir / "dup2.md").write_text(duplicate_text, encoding="utf-8")

    broken_dir = source / "broken"
    broken_dir.mkdir()
    (broken_dir / "bad.fb2").write_text("<FictionBook><broken>", encoding="utf-8")

    subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "study-materials-prep.py"),
            "--source",
            str(source),
            "--output",
            str(output),
        ],
        cwd=REPO_ROOT,
        check=True,
    )

    index = json.loads((output / "index.json").read_text(encoding="utf-8"))
    entries = {entry["file"]: entry for entry in index["entries"]}

    assert index["ingestion_workflow"]["launch_mode"] == "agent_launched_orchestrated_step"
    assert index["ingestion_workflow"]["verification_required"] is True
    assert index["ingestion_workflow"]["originals_retained"] is True

    bad_entry = entries["broken/bad.md"]
    assert bad_entry["prepared_status"] == "review_needed"
    assert "extraction_error" in bad_entry["review_flags"]
    assert bad_entry["original_fallback_required"] is True
    assert bad_entry["original_fallback"] == "originals/broken/bad.fb2"
    assert "broken/bad.md" in index["review_before_use_files"]
    assert (output / "originals" / "broken" / "bad.fb2").exists()

    assert entries["dups/dup2.md"]["duplicate_of"] == "dups/dup1.md"
    assert {"file": "dups/dup2.md", "duplicate_of": "dups/dup1.md"} in index["duplicate_files"]
    assert "dups/dup2.md" not in index["preferred_context_files"]

    merged_path = "merged-packs/module-a.md"
    assert merged_path in entries
    assert entries[merged_path]["source_kind"] == "merged_pack"
    assert entries[merged_path]["prepared_status"] == "prepared_trusted"
    assert entries[merged_path]["merged_from"] == ["module-a/part1.md", "module-a/part2.md"]
    assert merged_path in index["preferred_context_files"]
    assert entries["module-a/part1.md"]["merged_into"] == merged_path
    assert entries["module-a/part2.md"]["merged_into"] == merged_path

    readme = (output / "README.md").read_text(encoding="utf-8")
    assert "Review needed before trusting for precise academic claims" in readme
    assert "merged-packs/module-a.md" in readme
