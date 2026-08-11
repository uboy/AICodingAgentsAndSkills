import re
import unittest
from pathlib import Path
import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]


class BlockedContractTests(unittest.TestCase):
    def test_restored_agents_source_enables_agent_deploy_entries(self):
        agents_dir = REPO_ROOT / "agents"
        self.assertTrue((agents_dir / "agent-architect.md").exists())
        self.assertTrue((agents_dir / "implementation-developer.md").exists())
        self.assertTrue((agents_dir / "weak-model" / "wm-orchestrator.md").exists())

        manifest_text = (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8")
        self.assertIn("out/.claude/agents|.claude/agents", manifest_text)
        self.assertIn("out/.codex/agents|.codex/agents", manifest_text)
        self.assertIn("out/.gemini/extensions/ai-coding-agents/agents|.gemini/extensions/ai-coding-agents/agents", manifest_text)
        self.assertIn("out/.opencode/agents|.opencode/agents", manifest_text)

    def test_promptfoo_config_references_restored_suite_files(self):
        config = yaml.safe_load((REPO_ROOT / "promptfooconfig.yaml").read_text(encoding="utf-8"))
        suite_paths = config["configs"]

        self.assertEqual(
            [
                "evals/promptfoo/suites/lecture-transcript.yaml",
                "evals/promptfoo/suites/homework-management.yaml",
                "evals/promptfoo/suites/case-analyzer.yaml",
            ],
            suite_paths,
        )
        for rel in suite_paths:
            self.assertTrue((REPO_ROOT / rel).exists(), rel)

    def test_skills_readme_marks_manifest_as_generated_from_json_map(self):
        readme_text = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
        self.assertIn("checked-in generated deploy manifest", readme_text)
        self.assertIn("generate-skill-deployment-manifest.ps1", readme_text)


if __name__ == "__main__":
    unittest.main()
