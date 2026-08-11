#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


SUPPORT_RUNTIME_PATHS = [
    "skills/_shared",
]

SUPPORT_LIBRARY_PATHS = [
    "skills/_shared",
    "skills/_template",
    "skills/QUALITY-STANDARD.md",
    "skills/README.md",
]


def build_lines(mapping: dict) -> list[str]:
    systems = mapping["systems"]
    always_on = mapping["always_on"]
    library_only = mapping["library_only"]
    deprecated = mapping["deprecated"]

    lines: list[str] = []

    for system_name, system in systems.items():
        runtime_dir = system["runtime_dir"]
        library_dir = system["library_dir"]

        for support_path in SUPPORT_RUNTIME_PATHS:
            target_name = Path(support_path).name
            lines.append(
                "\t".join(
                    ["deploy", "support", system_name, "runtime", support_path, f"{runtime_dir}/{target_name}"]
                )
            )

        for support_path in SUPPORT_LIBRARY_PATHS:
            target_name = Path(support_path).name
            lines.append(
                "\t".join(
                    ["deploy", "support", system_name, "library", support_path, f"{library_dir}/{target_name}"]
                )
            )

        for skill_name in always_on:
            skill_path = f"skills/{skill_name}"
            lines.append(
                "\t".join(
                    ["deploy", "skill", system_name, "runtime", skill_path, f"{runtime_dir}/{skill_name}"]
                )
            )
        for skill_name in always_on:
            skill_path = f"skills/{skill_name}"
            lines.append(
                "\t".join(
                    ["deploy", "skill", system_name, "library", skill_path, f"{library_dir}/{skill_name}"]
                )
            )

        for skill_name in library_only:
            skill_path = f"skills/{skill_name}"
            lines.append(
                "\t".join(
                    ["deploy", "skill", system_name, "library", skill_path, f"{library_dir}/{skill_name}"]
                )
            )

        for skill_name in deprecated:
            lines.append(
                "\t".join(
                    ["cleanup", "deprecated-skill", system_name, "runtime", "", f"{runtime_dir}/{skill_name}"]
                )
            )
        for skill_name in deprecated:
            lines.append(
                "\t".join(
                    ["cleanup", "deprecated-skill", system_name, "library", "", f"{library_dir}/{skill_name}"]
                )
            )

    return lines


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate deploy/skill-deployment-manifest.tsv from deploy/skill-deployment-map.json"
    )
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    mapping_path = repo_root / "deploy" / "skill-deployment-map.json"
    out_path = Path(args.out).resolve()

    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    rendered = "\n".join(build_lines(mapping)) + "\n"

    if args.check:
        existing = out_path.read_text(encoding="utf-8") if out_path.exists() else ""
        if existing == rendered:
            print(f"PASS manifest-generation {out_path} matches deploy/skill-deployment-map.json")
            return 0
        print(f"FAIL manifest-generation {out_path} is out of sync with deploy/skill-deployment-map.json")
        return 1

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(rendered, encoding="utf-8", newline="\n")
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
