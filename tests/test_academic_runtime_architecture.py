import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_academic_core_files_exist_and_noncore_claims_are_not_active():
    assert (REPO_ROOT / "skills" / "lecture-transcript" / "SKILL.md").exists()
    assert (REPO_ROOT / "skills" / "homework-management" / "SKILL.md").exists()
    assert (REPO_ROOT / "skills" / "case-analyzer" / "SKILL.md").exists()
    assert (REPO_ROOT / "evals" / "skills" / "cases" / "case-analyzer.md").exists()

    assert not (REPO_ROOT / "skills" / "academic-tutor" / "SKILL.md").exists()
    assert not (REPO_ROOT / "skills" / "thesis-assistant" / "SKILL.md").exists()
    assert not (REPO_ROOT / "skills" / "test-solver" / "SKILL.md").exists()
    assert (REPO_ROOT / "agents" / "homework-manager.md").exists()
    assert (REPO_ROOT / "agents" / "homework-indexer.md").exists()


def test_content_task_routing_points_only_to_real_academic_components():
    data = json.loads((REPO_ROOT / "policy" / "task-routing-matrix.json").read_text(encoding="utf-8"))
    content_task = data["profiles"]["content_task"]

    assert "homework-manager" in content_task["recommended_agents"]
    assert "homework-indexer" not in content_task["recommended_agents"]

    assert "homework-management" in content_task["recommended_skills"]
    assert "case-analyzer" in content_task["recommended_skills"]
    assert "lecture-transcript" in content_task["recommended_skills"]
    assert "academic-tutor" not in content_task["recommended_skills"]
    assert "thesis-assistant" not in content_task["recommended_skills"]
    assert "test-solver" not in content_task["recommended_skills"]


def test_qwen_installers_no_longer_claim_missing_homework_manager_file():
    ps1 = (REPO_ROOT / "scripts" / "install-qwen-user.ps1").read_text(encoding="utf-8")
    sh = (REPO_ROOT / "scripts" / "install-qwen-user.sh").read_text(encoding="utf-8")

    assert ".qwen/homework-manager.md" not in ps1
    assert ".qwen/homework-manager.md" not in sh


def test_homework_base_no_longer_claims_dedicated_indexer_agent():
    content = (REPO_ROOT / "skills" / "_shared" / "HOMEWORK_BASE.md").read_text(encoding="utf-8")
    assert "`homework-indexer` agent" in content
    assert "homework-management" in content


def test_case_analyzer_is_registered_as_library_skill():
    deploy_map = json.loads((REPO_ROOT / "deploy" / "skill-deployment-map.json").read_text(encoding="utf-8"))
    assert "case-analyzer" in deploy_map["library_only"]
