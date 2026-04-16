import subprocess
import tempfile
from pathlib import Path
import tomllib
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

    def test_codex_config_source_and_generated_output_are_valid_toml(self):
        source_data = tomllib.loads((REPO_ROOT / "adapters" / "Codex" / "config.toml").read_text(encoding="utf-8"))
        self.assertEqual("never", source_data["approval_policy"])
        self.assertEqual("workspace-write", source_data["sandbox_mode"])
        self.assertTrue(source_data["command_safety"]["check_command_safety"])

        with tempfile.TemporaryDirectory() as temp_dir:
            out_dir = Path(temp_dir) / "out"
            result = run_pwsh(
                "scripts/sync-adapters.ps1",
                "-OutDir",
                str(out_dir),
            )
            self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)
            generated = tomllib.loads((out_dir / ".codex" / "config.toml").read_text(encoding="utf-8"))

        self.assertEqual(source_data, generated)


if __name__ == "__main__":
    unittest.main()
