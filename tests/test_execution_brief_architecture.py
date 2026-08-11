import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_execution_brief_contract_and_template_are_present():
    contract = (REPO_ROOT / "policy" / "execution-brief-contract.md").read_text(encoding="utf-8")
    template = json.loads((REPO_ROOT / "coordination" / "templates" / "execution-brief.json").read_text(encoding="utf-8"))

    assert "request refinement" in contract.lower()
    assert "after each verified code chunk" in contract
    assert "scripts/study-materials-prep.py" in contract

    required_fields = {
        "task_profile",
        "task_shape",
        "refined_objective",
        "user_intent",
        "output_expectation",
        "hard_constraints",
        "forbidden_assumptions",
        "relevant_sources",
        "source_prep_recommendation",
        "active_rules",
        "subtask_boundary",
        "success_criteria",
        "verification_requirements",
        "chunking_requirement",
        "long_task_refresh",
    }
    assert required_fields.issubset(template.keys())
    assert template["chunking_requirement"]["mode"] == "small_isolated_verified_chunks"
    assert template["long_task_refresh"]["required"] is True


def test_routing_and_orchestrator_require_execution_brief_and_refresh():
    orchestrator = (REPO_ROOT / "policy" / "team-lead-orchestrator.md").read_text(encoding="utf-8")
    routing_json = json.loads((REPO_ROOT / "policy" / "task-routing-matrix.json").read_text(encoding="utf-8"))
    routing_md = (REPO_ROOT / "policy" / "task-routing-matrix.md").read_text(encoding="utf-8")

    assert "create or refresh an execution brief" in orchestrator
    assert "Refine before delegate" in orchestrator
    assert "Execution Brief" in routing_md

    repo_change = routing_json["profiles"]["repo_change"]
    content_task = routing_json["profiles"]["content_task"]
    repo_read = routing_json["profiles"]["repo_read"]
    brief_contract = routing_json["execution_brief_contract"]

    assert repo_change["request_refinement_required"] is True
    assert repo_change["code_execution_mode"] == "small_isolated_verified_chunks"
    assert repo_change["long_task_refresh_required"] is True

    assert content_task["request_refinement_required"] is True
    assert content_task["source_prep_decision_in_brief"] is True
    assert "execution_brief" in content_task["multi_step_contract"]

    assert repo_read["request_refinement_required"] is True
    assert repo_read["context_mode"] == "narrow_scope_progressive_discovery"

    assert brief_contract["required"] is True
    assert brief_contract["template_path"] == "coordination/templates/execution-brief.json"
    assert "after_each_verified_chunk" in brief_contract["refresh_triggers"]
    assert brief_contract["code_chunking_defaults"]["verify_between_chunks"] is True


def test_context_budget_checkpoint_and_coordination_docs_align():
    context_budget = (REPO_ROOT / "policy" / "context-budget-policy.md").read_text(encoding="utf-8")
    checkpoint = (REPO_ROOT / "policy" / "agent-checkpoint-policy.md").read_text(encoding="utf-8")
    protocol = (REPO_ROOT / "coordination" / "PLAN-TASK-PROTOCOL.md").read_text(encoding="utf-8")
    coordination_readme = (REPO_ROOT / "coordination" / "README.md").read_text(encoding="utf-8")
    task_template = json.loads((REPO_ROOT / "coordination" / "templates" / "task.json").read_text(encoding="utf-8"))
    weak_task_template = json.loads((REPO_ROOT / "coordination" / "templates" / "task.weak-model.json").read_text(encoding="utf-8"))

    assert "Refresh the active execution brief before the next chunk" in context_budget
    assert "Code execution mode: one verified chunk at a time." in context_budget
    assert "verified chunk" in checkpoint
    assert "execution brief refresh" in checkpoint

    assert "Execution Brief Schema" in protocol
    assert "execution_brief_ref" in protocol
    assert "briefs/" in coordination_readme
    assert task_template["execution_brief_ref"] == "coordination/briefs/T-000.json"
    assert weak_task_template["execution_brief_ref"] == "coordination/briefs/T-000.json"
    assert weak_task_template["chunking_mode"] == "small_isolated_verified_chunks"


def test_repo_docs_and_status_expose_coordinator_execution_model():
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    status_doc = (REPO_ROOT / "docs" / "REPOSITORY-STATUS.md").read_text(encoding="utf-8")
    status_json = json.loads((REPO_ROOT / "configs" / "repository-status.json").read_text(encoding="utf-8"))

    assert "Coordinator Execution Model" in readme
    assert "policy/execution-brief-contract.md" in readme
    assert "coordination/templates/execution-brief.json" in readme

    assert "Shared coordinator infrastructure" in status_doc
    assert "policy/execution-brief-contract.md" in status_doc
    assert "coordination/templates/execution-brief.json" in status_doc

    shared = {item["path"]: item for item in status_json["shared_infrastructure"]}
    assert shared["policy/execution-brief-contract.md"]["status"] == "active"
    assert shared["coordination/templates/execution-brief.json"]["status"] == "active"
