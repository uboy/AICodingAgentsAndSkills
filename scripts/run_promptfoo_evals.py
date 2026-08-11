from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = REPO_ROOT / "promptfooconfig.yaml"
DEFAULT_OUTPUT_DIR = REPO_ROOT / "evals" / "results" / "promptfoo"
DEFAULT_SCRATCH_DIR = REPO_ROOT / ".scratchpad" / "promptfoo-run"


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Expected mapping in {path}")
    return data


def build_eval_config(base_config: dict, suite_config: dict) -> dict:
    merged = {
        key: value
        for key, value in base_config.items()
        if key not in {"configs", "outputPath", "outputDirectory"}
    }
    if "providers" in suite_config or "targets" in suite_config:
        merged.pop("providers", None)
        merged.pop("targets", None)
    merged.update(suite_config)
    return merged


def suite_output_path(output_dir: Path, suite_path: Path) -> Path:
    return output_dir / f"{suite_path.stem}.json"


def suite_name(suite_path: Path) -> str:
    return suite_path.stem


def resolve_suite_paths(base_config: dict, selected_suites: list[str] | None) -> list[Path]:
    suite_paths = [REPO_ROOT / rel for rel in base_config.get("configs", [])]
    if selected_suites:
        wanted = set(selected_suites)
        suite_paths = [path for path in suite_paths if suite_name(path) in wanted]
    return suite_paths


def ensure_promptfoo_binary(binary: str) -> str:
    resolved = shutil.which(binary)
    if not resolved:
        raise FileNotFoundError(f"promptfoo binary not found: {binary}")
    return resolved


def write_yaml(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        yaml.safe_dump(data, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )


def run_suite(promptfoo_bin: str, merged_config_path: Path, output_path: Path) -> int:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        promptfoo_bin,
        "eval",
        "-c",
        str(merged_config_path),
        "--output",
        str(output_path),
    ]
    completed = subprocess.run(command, cwd=REPO_ROOT)
    return completed.returncode


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compose the repo promptfoo base config with tracked suite files and run evals."
    )
    parser.add_argument("--config", default=str(DEFAULT_CONFIG))
    parser.add_argument("--suite", action="append", default=[])
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--scratch-dir", default=str(DEFAULT_SCRATCH_DIR))
    parser.add_argument("--promptfoo-bin", default="promptfoo")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    base_config_path = Path(args.config).resolve()
    base_config = load_yaml(base_config_path)
    suite_paths = resolve_suite_paths(base_config, args.suite or None)

    if not suite_paths:
        print("No suite files selected.", file=sys.stderr)
        return 1

    output_dir = Path(args.output_dir).resolve()
    scratch_dir = Path(args.scratch_dir).resolve()

    for suite_path in suite_paths:
        if not suite_path.exists():
            print(f"Missing suite file: {suite_path}", file=sys.stderr)
            return 1

    if args.check:
        print(f"Base config: {base_config_path}")
        for suite_path in suite_paths:
            print(f"Suite: {suite_path}")
        print(f"Output dir: {output_dir}")
        return 0

    promptfoo_bin = ensure_promptfoo_binary(args.promptfoo_bin)
    failures = 0
    for suite_path in suite_paths:
        suite_config = load_yaml(suite_path)
        merged = build_eval_config(base_config, suite_config)
        merged_path = scratch_dir / f"{suite_name(suite_path)}.merged.yaml"
        output_path = suite_output_path(output_dir, suite_path)
        write_yaml(merged_path, merged)
        print(f"Running suite: {suite_name(suite_path)}", flush=True)
        exit_code = run_suite(promptfoo_bin, merged_path, output_path)
        if exit_code != 0:
            failures += 1

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
