import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class BlockedContractTests(unittest.TestCase):
    def test_empty_agents_source_disables_agent_deploy_entries(self):
        agents_dir = REPO_ROOT / "agents"
        self.assertEqual(0, len(list(agents_dir.rglob("*.*"))))

        manifest_text = (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8")
        self.assertNotIn("out/.claude/agents|.claude/agents", manifest_text)
        self.assertNotIn("out/.codex/agents|.codex/agents", manifest_text)
        self.assertNotIn("out/.gemini/extensions/ai-coding-agents/agents|.gemini/extensions/ai-coding-agents/agents", manifest_text)
        self.assertNotIn("out/.opencode/agents|.opencode/agents", manifest_text)
        self.assertIn("canonical tracked source", manifest_text)

    def test_promptfoo_config_is_explicitly_inactive_without_missing_suite_refs(self):
        config_text = (REPO_ROOT / "promptfooconfig.yaml").read_text(encoding="utf-8")
        self.assertIn("inactive promptfoo placeholder", config_text)
        self.assertIn("configs: []", config_text)
        self.assertNotRegex(config_text, r"(?m)^\s*-\s+evals/.+\.ya?ml\s*$")

    def test_skills_readme_marks_manifest_as_static_without_generator(self):
        readme_text = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
        self.assertIn("checked-in static deploy manifest", readme_text)
        self.assertIn("no manifest generator is currently present", readme_text)


if __name__ == "__main__":
    unittest.main()
