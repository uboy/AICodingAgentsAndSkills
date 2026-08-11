import subprocess
import tempfile
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
POWERSHELL = ["pwsh", "-NoProfile", "-NonInteractive"]


def run_pwsh(script_rel: str, *args: str) -> subprocess.CompletedProcess[str]:
    command = POWERSHELL + ["-File", str(REPO_ROOT / script_rel), *args]
    return subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )


class GenerationContractTests(unittest.TestCase):
    def test_sync_adapters_generates_cursor_tier_rules_from_policy_content(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            out_dir = Path(temp_dir) / "out"
            result = run_pwsh(
                "scripts/sync-adapters.ps1",
                "-OutDir",
                str(out_dir),
            )
            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)

            hot_text = (out_dir / ".cursor" / "rules" / "01-agents-policy.mdc").read_text(encoding="utf-8")
            warm_text = (out_dir / ".cursor" / "rules" / "02-agents-warm.mdc").read_text(encoding="utf-8")
            cold_text = (out_dir / ".cursor" / "rules" / "03-agents-cold.mdc").read_text(encoding="utf-8")

            for text in (hot_text, warm_text, cold_text):
                self.assertIn("---", text)
                self.assertNotIn("{{SYSTEM_LABEL}}", text)
                self.assertNotIn("{{EXTRA_FOOTER}}", text)

            self.assertIn("CRITICAL BOOTSTRAP INSTRUCTION", hot_text)
            self.assertIn("Cross-OS support is required by default.", warm_text)
            self.assertIn("Skills governance is mandatory.", cold_text)

    def test_runtime_configs_are_not_generated_in_supported_outputs(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            out_dir = Path(temp_dir) / "out"
            result = run_pwsh(
                "scripts/sync-adapters.ps1",
                "-OutDir",
                str(out_dir),
            )
            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)

            retired_outputs = [
                ".claude/settings.json",
                ".codex/config.toml",
                ".codex/hooks.json",
                ".cursor/settings.json",
                ".cursor/hooks.json",
                ".gemini/settings.json",
                ".gemini/extensions/ai-coding-agents/manifest.json",
                "opencode.json",
                ".cline/settings.json",
            ]
            for rel in retired_outputs:
                self.assertFalse((out_dir / rel).exists(), rel)

    def test_skill_manifest_generator_matches_checked_in_tsv(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            out_path = Path(temp_dir) / "skill-deployment-manifest.tsv"
            result = run_pwsh(
                "scripts/generate-skill-deployment-manifest.ps1",
                "-OutPath",
                str(out_path),
            )
            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)

            expected = (REPO_ROOT / "deploy" / "skill-deployment-manifest.tsv").read_text(encoding="utf-8")
            generated = out_path.read_text(encoding="utf-8")
            self.assertEqual(expected, generated)


if __name__ == "__main__":
    unittest.main()
