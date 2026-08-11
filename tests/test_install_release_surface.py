from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_manifest_excludes_retired_runtime_configs() -> None:
    manifest = (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8")

    retired_targets = [
        "out/opencode.json|opencode.json",
        "out/.claude/settings.json|.claude/settings.json",
        "out/.codex/config.toml|.codex/config.toml",
        "out/.codex/hooks.json|.codex/hooks.json",
        "out/.gemini/settings.json|.gemini/settings.json",
        "out/.gemini/extensions/ai-coding-agents/manifest.json|.gemini/extensions/ai-coding-agents/manifest.json",
        "out/.cline/settings.json|.cline/settings.json",
    ]
    for line in retired_targets:
        assert line not in manifest

    assert "out/.qwen/AGENTS.md|.qwen/AGENTS.md" in manifest
    assert "out/.claude/agents|.claude/agents" in manifest
    assert "out/.codex/agents|.codex/agents" in manifest
    assert "out/.gemini/extensions/ai-coding-agents/agents|.gemini/extensions/ai-coding-agents/agents" in manifest
    assert "out/.opencode/agents|.opencode/agents" in manifest


def test_all_active_install_manifest_sources_exist() -> None:
    missing = []

    for raw in (REPO_ROOT / "deploy" / "manifest.txt").read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        source, target = [part.strip() for part in line.split("|", 1)]
        if not (REPO_ROOT / source).exists():
            missing.append(("manifest", source, target))

    for raw in (REPO_ROOT / "deploy" / "skill-deployment-manifest.tsv").read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = raw.split("\t")
        if len(parts) < 6:
            continue
        action, _, _, _, source, target = [part.strip() for part in parts[:6]]
        if action != "deploy":
            continue
        if not (REPO_ROOT / source).exists():
            missing.append(("skill", source, target))

    assert missing == []


def test_main_install_and_backup_scripts_consume_skill_deployment_manifest() -> None:
    install_ps1 = (REPO_ROOT / "scripts" / "install.ps1").read_text(encoding="utf-8")
    install_sh = (REPO_ROOT / "scripts" / "install.sh").read_text(encoding="utf-8")
    backup_ps1 = (REPO_ROOT / "scripts" / "backup-user-config.ps1").read_text(encoding="utf-8")
    backup_sh = (REPO_ROOT / "scripts" / "backup-user-config.sh").read_text(encoding="utf-8")

    assert "SkillManifestPath" in install_ps1
    assert "Parse-SkillDeploymentManifest" in install_ps1
    assert "($entries + $skillEntries)" in install_ps1

    assert "SKILL_MANIFEST_PATH" in install_sh
    assert "deploy_skill_manifest" in install_sh
    assert "Skill deployment entries:" in install_sh
    assert "cygpath -w" in install_sh

    assert "SkillManifestPath" in backup_ps1
    assert "Parse-SkillDeploymentManifest" in backup_ps1
    assert "SKILL_MANIFEST_PATH" in backup_sh


def test_install_scripts_cover_broken_links_batch_prompts_and_backup_archives_without_sidecars() -> None:
    install_ps1 = (REPO_ROOT / "scripts" / "install.ps1").read_text(encoding="utf-8")
    install_sh = (REPO_ROOT / "scripts" / "install.sh").read_text(encoding="utf-8")
    backup_ps1 = (REPO_ROOT / "scripts" / "backup-user-config.ps1").read_text(encoding="utf-8")
    backup_sh = (REPO_ROOT / "scripts" / "backup-user-config.sh").read_text(encoding="utf-8")
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")

    assert "Test-BrokenLink" in install_ps1
    assert "ConflictActionOverride" in install_ps1
    assert "RA" in install_ps1 and "MA" in install_ps1 and "KA" in install_ps1

    assert "CONFLICT_ACTION_OVERRIDE" in install_sh
    assert "RA" in install_sh and "MA" in install_sh and "KA" in install_sh
    assert "ensure_codex_local_trust() {" in install_sh
    assert "ensure_codex_global_trust() {" in install_sh
    assert 'local local_config="$REPO_ROOT/.codex/config.toml"' not in install_sh
    assert 'local global_config="$HOME_DIR/.codex/config.toml"' not in install_sh

    assert "ArchivePath" in backup_ps1
    assert "Compress-Archive" in backup_ps1
    assert "ARCHIVE_PATH" in backup_sh
    assert "python -m zipfile" in backup_sh or "zip -rq" in backup_sh

    assert ".ai-agent-config-backups" in readme
    assert "-NonInteractive -ConflictAction replace" in readme
    assert '$Path.backup-' not in install_ps1
    assert '${target}.backup-' not in install_sh


def test_release_docs_describe_runtime_config_retirement_honestly() -> None:
    readme = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    status_doc = (REPO_ROOT / "docs" / "REPOSITORY-STATUS.md").read_text(encoding="utf-8")
    skills_readme = (REPO_ROOT / "skills" / "README.md").read_text(encoding="utf-8")
    deploy_map = (REPO_ROOT / "deploy" / "skill-deployment-map.json").read_text(encoding="utf-8")
    tool_permissions = (REPO_ROOT / "policy" / "tool-permissions-matrix.md").read_text(encoding="utf-8")
    model_profiles = (REPO_ROOT / "policy" / "model-capability-profiles.md").read_text(encoding="utf-8")

    assert "deploy/skill-deployment-manifest.tsv" in readme
    assert "generate-skill-deployment-manifest.ps1" in readme
    assert "tool-owned runtime configs are intentionally not shipped or installed from this repository" in readme
    assert "auxiliary Qwen helper currently deploys only generated `out/.qwen/AGENTS.md`" in readme
    assert "out/opencode.json" not in readme
    assert "out/.cline/settings.json" not in readme
    assert "Claude/                  ← Claude Code (adapter docs only)" in readme
    assert "Codex/                   ← Codex CLI (adapter docs only)" in readme
    assert "Gemini/                  ← Gemini CLI (adapter docs only)" in readme
    assert "OpenCode/                ← OpenCode (adapter docs only)" in readme
    assert "gitcode-pr-workflow" not in skills_readme
    assert "gitcode-pr-workflow" not in deploy_map

    assert "scripts/install.ps1" in status_doc
    assert "scripts/install.sh" in status_doc
    assert "scripts/audit-installed-config.ps1" in status_doc
    assert "scripts/audit-installed-config.sh" in status_doc
    assert "scripts/generate-skill-deployment-manifest.ps1" in status_doc
    assert "scripts/generate-skill-deployment-manifest.sh" in status_doc
    assert "audit-permissions-policy" not in tool_permissions
    assert "audit-permissions-policy" not in model_profiles
    assert "security-review-gate.ps1" in model_profiles
    assert "security-review-gate.sh" in model_profiles


def test_active_generation_and_validation_scripts_exclude_retired_runtime_configs() -> None:
    validate_parity_ps1 = (REPO_ROOT / "scripts" / "validate-parity.ps1").read_text(encoding="utf-8")
    validate_parity_sh = (REPO_ROOT / "scripts" / "validate-parity.sh").read_text(encoding="utf-8")
    integrity_ps1 = (REPO_ROOT / "scripts" / "run-integrity-fast.ps1").read_text(encoding="utf-8")
    cycle_ps1 = (REPO_ROOT / "scripts" / "validate-cycle-proof.ps1").read_text(encoding="utf-8")
    cycle_sh = (REPO_ROOT / "scripts" / "validate-cycle-proof.sh").read_text(encoding="utf-8")
    change_ps1 = (REPO_ROOT / "scripts" / "change-control-gate.ps1").read_text(encoding="utf-8")
    change_sh = (REPO_ROOT / "scripts" / "change-control-gate.sh").read_text(encoding="utf-8")
    sync_sh = (REPO_ROOT / "scripts" / "sync-adapters.sh").read_text(encoding="utf-8")

    retired_refs = [
        "out/opencode.json",
        "out/.gemini/settings.json",
        "out/.codex/config.toml",
        "adapters/Codex/config.toml",
        "configs/codex/config.toml",
    ]
    for ref in retired_refs:
        assert ref not in validate_parity_ps1
        assert ref not in validate_parity_sh
        assert ref not in integrity_ps1

    assert '"opencode.json",' not in cycle_ps1
    assert '"opencode.json"' not in cycle_sh
    assert '"opencode.json",' not in change_ps1
    assert '"opencode.json"' not in change_sh
    assert '".gemini/settings.json"' not in change_ps1
    assert '".gemini/settings.json"' not in change_sh
    assert '"configs/codex/config.toml"' not in change_ps1
    assert '"configs/codex/config.toml"' not in change_sh
    assert ".codex/config.toml" not in sync_sh
    assert ".gemini/settings.json" not in sync_sh
    assert "opencode.json" not in sync_sh


def test_skill_manifest_generator_scripts_exist_and_target_the_json_map() -> None:
    generator_py = (REPO_ROOT / "scripts" / "generate_skill_deployment_manifest.py").read_text(encoding="utf-8")
    generator_ps1 = (REPO_ROOT / "scripts" / "generate-skill-deployment-manifest.ps1").read_text(encoding="utf-8")
    generator_sh = (REPO_ROOT / "scripts" / "generate-skill-deployment-manifest.sh").read_text(encoding="utf-8")

    assert "deploy/skill-deployment-map.json" in generator_py
    assert "generate_skill_deployment_manifest.py" in generator_ps1
    assert "generate_skill_deployment_manifest.py" in generator_sh


def test_obsolete_runtime_config_helpers_and_docs_are_removed() -> None:
    removed_paths = [
        "scripts/audit-permissions-policy.ps1",
        "scripts/audit-permissions-policy.sh",
        "scripts/fix-codex-trust.ps1",
        "scripts/fix-codex-trust.sh",
        "docs/TOKEN-ECONOMY-SETUP.md",
    ]
    for rel in removed_paths:
        assert not (REPO_ROOT / rel).exists(), rel
