from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_runtime_config_sources_are_removed_from_repo() -> None:
    retired_paths = [
        "adapters/Claude/settings.json",
        "adapters/Cline/settings.json",
        "adapters/Codex/config.toml",
        "adapters/Codex/hooks.json",
        "adapters/Cursor/settings.json",
        "adapters/Cursor/hooks.json",
        "adapters/Gemini/settings.json",
        "adapters/Gemini/extension-manifest.json",
        "adapters/OpenCode/config.json",
        ".cline/settings.json",
        "configs/codex/config.toml",
    ]
    for rel in retired_paths:
        assert not (REPO_ROOT / rel).exists(), rel


def test_runtime_configs_are_removed_from_manifest_and_generation_rules() -> None:
    manifest = (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8")
    systems = (REPO_ROOT / "adapters" / "systems.json").read_text(encoding="utf-8")

    retired_needles = [
        ".claude/settings.json",
        ".codex/config.toml",
        ".codex/hooks.json",
        ".cursor/settings.json",
        ".cursor/hooks.json",
        ".gemini/settings.json",
        ".gemini/extensions/ai-coding-agents/manifest.json",
        "opencode.json",
        ".cline/settings.json",
        "adapters/Claude/settings.json",
        "adapters/Codex/config.toml",
        "adapters/Codex/hooks.json",
        "adapters/Cursor/settings.json",
        "adapters/Cursor/hooks.json",
        "adapters/Gemini/settings.json",
        "adapters/Gemini/extension-manifest.json",
        "adapters/OpenCode/config.json",
    ]

    for needle in retired_needles:
        assert needle not in manifest
        assert needle not in systems
