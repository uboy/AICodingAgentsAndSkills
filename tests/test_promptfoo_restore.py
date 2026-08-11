from pathlib import Path
import importlib.util

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_promptfoo_entrypoint_parses_and_references_suite_files():
    config = yaml.safe_load((REPO_ROOT / "promptfooconfig.yaml").read_text(encoding="utf-8"))

    assert config["description"]
    assert config["providers"]
    assert config["configs"] == [
        "evals/promptfoo/suites/lecture-transcript.yaml",
        "evals/promptfoo/suites/homework-management.yaml",
        "evals/promptfoo/suites/case-analyzer.yaml",
    ]
    assert "outputPath" not in config


def test_promptfoo_suite_files_parse_and_expose_basic_contract_shape():
    suite_paths = [
        REPO_ROOT / "evals" / "promptfoo" / "suites" / "lecture-transcript.yaml",
        REPO_ROOT / "evals" / "promptfoo" / "suites" / "homework-management.yaml",
        REPO_ROOT / "evals" / "promptfoo" / "suites" / "case-analyzer.yaml",
    ]

    for suite_path in suite_paths:
        suite = yaml.safe_load(suite_path.read_text(encoding="utf-8"))
        assert suite["description"]
        assert suite["prompts"]
        assert suite["tests"]
        for test_case in suite["tests"]:
            assert test_case["description"]
            assert test_case["vars"]
            assert test_case["assert"]


def test_promptfoo_runner_scripts_exist_and_merge_base_config_with_suite():
    py_runner = REPO_ROOT / "scripts" / "run_promptfoo_evals.py"
    ps_runner = REPO_ROOT / "scripts" / "run-promptfoo-evals.ps1"
    sh_runner = REPO_ROOT / "scripts" / "run-promptfoo-evals.sh"

    assert py_runner.exists()
    assert ps_runner.exists()
    assert sh_runner.exists()

    spec = importlib.util.spec_from_file_location("run_promptfoo_evals", py_runner)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)

    base = yaml.safe_load((REPO_ROOT / "promptfooconfig.yaml").read_text(encoding="utf-8"))
    suite = yaml.safe_load(
        (REPO_ROOT / "evals" / "promptfoo" / "suites" / "lecture-transcript.yaml").read_text(
            encoding="utf-8"
        )
    )
    merged = module.build_eval_config(base, suite)

    assert merged["providers"] == base["providers"]
    assert merged["defaultTest"] == base["defaultTest"]
    assert merged["prompts"] == suite["prompts"]
    assert merged["tests"] == suite["tests"]
    assert "configs" not in merged
    assert "outputPath" not in merged
