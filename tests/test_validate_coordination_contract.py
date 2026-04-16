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


def write_handoff(repo_root: Path, rel_path: str, body: str) -> str:
    handoff_path = repo_root / rel_path
    handoff_path.parent.mkdir(parents=True, exist_ok=True)
    handoff_path.write_text(body, encoding="utf-8")
    return rel_path.replace("\\", "/")


class ValidateCoordinationContractTests(unittest.TestCase):
    def test_powershell_rejects_false_commit_pending_claim(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            rel = write_handoff(
                repo_root,
                "coordination/handoffs/sample.md",
                """## Summary
Changed something.

## Files Touched
- foo.txt

## Verification
- `pwsh -NoProfile -File .\\scripts\\security-review-gate.ps1` -> fail

## Commit Readiness
Ready to commit.

## Delivery Contract
Commit pending user approval.
""",
            )
            result = run_pwsh(
                "scripts/validate-coordination.ps1",
                "-RepoRoot",
                str(repo_root),
                "-FilesToValidate",
                rel,
            )
        self.assertNotEqual(0, result.returncode, msg=result.stdout)
        self.assertIn("claims 'Commit pending user approval'", result.stdout)

    def test_powershell_accepts_ready_commit_claim_with_passing_gate(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            rel = write_handoff(
                repo_root,
                "coordination/handoffs/sample.md",
                """## Summary
Changed something.

## Files Touched
- foo.txt

## Verification
- `pwsh -NoProfile -File .\\scripts\\security-review-gate.ps1` -> pass

## Commit Readiness
Ready to commit.

## Delivery Contract
Commit pending user approval.
""",
            )
            result = run_pwsh(
                "scripts/validate-coordination.ps1",
                "-RepoRoot",
                str(repo_root),
                "-FilesToValidate",
                rel,
            )
        self.assertEqual(0, result.returncode, msg=result.stderr or result.stdout)

    def test_bash_rejects_false_commit_pending_claim_if_bash_is_usable(self):
        probe = subprocess.run(
            ["bash", "-lc", "true"],
            cwd=REPO_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        if probe.returncode != 0:
            self.skipTest("bash is not runnable in this environment")

        with tempfile.TemporaryDirectory() as temp_dir:
            repo_root = Path(temp_dir)
            rel = write_handoff(
                repo_root,
                "coordination/handoffs/sample.md",
                """## Summary
Changed something.

## Files Touched
- foo.txt

## Verification
- `bash ./scripts/security-review-gate.sh` -> fail

## Commit Readiness
Ready to commit.

## Delivery Contract
Commit pending user approval.
""",
            )
            result = subprocess.run(
                [
                    "bash",
                    str(REPO_ROOT / "scripts" / "validate-coordination.sh"),
                    "--repo-root",
                    str(repo_root),
                    "--files-to-validate",
                    rel,
                ],
                cwd=REPO_ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
        self.assertNotEqual(0, result.returncode, msg=result.stdout)
        self.assertIn("claims 'Commit pending user approval'", result.stdout)


if __name__ == "__main__":
    unittest.main()
