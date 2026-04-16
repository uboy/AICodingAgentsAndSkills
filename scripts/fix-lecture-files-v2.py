#!/usr/bin/env python3
"""
fix-lecture-files-v2.py — Fix extracted files from archives that have
garbled Cyrillic names. Extract, classify by extension, and rename properly.
"""

import argparse
import logging
import os
import re
import shutil
import zipfile
from pathlib import Path

log = logging.getLogger("fix")
logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

SUBJECT_TOPICS = {
    "HR-менеджмент": {1: "Введение", 2: "Компетентностный_подход", 3: "Интервью_по_компетенциям",
                       4: "Мотивация", 5: "Командная_работа", 6: "Управление_конфликтами",
                       7: "Оценка_персонала", 8: "HR_аналитика"},
    "Автоматизация бизнес-процессов": {1: "Введение", 2: "Учет_и_регламентация", 3: "BPMN",
                                        4: "TBD", 5: "RPA_кейсы", 6: "TBD", 7: "TBD", 8: "TBD"},
    "Маркетинговые стратегии": {1: "Введение", 2: "Конкурентные_стратегии", 3: "TBD", 4: "TBD",
                                 5: "Позиционирование", 6: "Маркетинговые_программы", 7: "TBD", 8: "TBD"},
    "Управление бизнес-процессами": {1: "Управление_процессами", 2: "TBD", 3: "TBD", 4: "TBD",
                                      5: "TBD", 6: "TBD", 7: "TBD", 8: "TBD"},
    "Управление проектами": {1: "Введение_в_УП", 2: "TBD", 3: "TBD", 4: "TBD", 5: "TBD",
                              6: "TBD", 7: "TBD", 8: "TBD", 9: "TBD"},
}


def classify_ext(path: Path) -> str:
    """Classify by extension only (ignore garbled names)."""
    ext = path.suffix.lower()
    if ext == ".txt":
        return "txt"
    if ext in (".pptx", ".ppt"):
        return "presentation"
    if ext in (".docx", ".doc"):
        return "document"
    if ext == ".pdf":
        return "pdf"
    return "other"


def classify_txt_content(path: Path) -> str:
    """Read txt file to determine if it's transcript or summary."""
    try:
        content = path.read_text(encoding='utf-8', errors='replace')
        cl = content.lower()
        # Check filename first
        name = path.name.lower()
        if "пересказ" in name or "summary" in name or "резюме" in name:
            return "summary"
        if "транскрипц" in name or "transcript" in name:
            return "transcript"
        # Check content
        if any(k in cl for k in ["транскрипц", "расшифровка"]):
            return "transcript"
        if any(k in cl for k in ["пересказ", "резюме", "конспект"]):
            return "summary"
        # Size heuristic: transcripts are usually 100KB+, summaries 20-50KB
        if len(content) > 100000:
            return "transcript"
        if len(content) < 50000:
            return "summary"
        # Check first line
        first = content.split('\n')[0].strip() if content.split('\n') else ""
        if len(first) > 100:
            return "transcript"
        return "summary"
    except:
        return "txt"


def gen_md(lec_num, topic, date_str, subj, files):
    """Generate .md with actual content."""
    transcript_preview = ""
    summary_preview = ""
    for f in files:
        try:
            ft = classify_ext(f)
            if ft == "txt":
                ct = classify_txt_content(f)
                t = f.read_text(encoding='utf-8', errors='replace')[:600]
                lines = [l.strip() for l in t.split('\n') if l.strip() and len(l.strip()) > 30]
                preview = lines[0][:250] if lines else ""
                if ct == "transcript":
                    transcript_preview = preview
                else:
                    summary_preview = preview
        except:
            pass

    flist = "\n".join(
        f"- `{f.name}` ({f.stat().st_size/1024:.0f} KB)"
        for f in sorted(files, key=lambda x: x.name)
    )

    desc = summary_preview if summary_preview else (transcript_preview[:250] if transcript_preview else "*Описание будет добавлено*")

    return f"""---
title: "Лекция {lec_num}: {topic.replace('_', ' ')}"
subject: "{subj}"
date: "{date_str}"
lecture_number: {lec_num}
---

# Лекция {lec_num}: {topic.replace('_', ' ')}

**Дата:** {date_str}

## Описание

{desc}

## Файлы лекции

{flist}

## Использование

- Загрузить этот файл в AI-агент как контекст
- Использовать транскрипцию для поиска конкретных моментов
- Пересказ — для быстрого ознакомления
"""


def fix_one_lecture(lec_dir: Path, dry_run: bool) -> dict:
    """Fix one lecture folder."""
    stats = {"extracted": 0, "renamed": 0, "md": 0, "errors": []}

    # Find archive
    archive = None
    log.debug("Looking for archive in %s", lec_dir)
    try:
        entries = list(lec_dir.iterdir())
        log.debug("Found %d entries", len(entries))
    except Exception as e:
        log.debug("iterdir failed: %s", e)
        entries = []

    for f in entries:
        log.debug("  Checking: %s is_file=%s suffix=%s", f.name, f.is_file(), f.suffix.lower())
        if f.is_file() and f.suffix.lower() in ('.zip', '.rar'):
            archive = f
            log.debug("Found archive: %s", archive)
            break

    if not archive:
        return stats

    # Extract to temp, then to extracted/
    import tempfile
    tmp = Path(tempfile.mkdtemp(prefix="lec-fix-"))

    ext_dir = lec_dir / "extracted"

    # Check if already extracted
    if ext_dir.exists() and any(ext_dir.iterdir()):
        # Already done — just rename existing files
        extracted_files = [f for f in ext_dir.iterdir() if f.is_file()]
        stats["extracted"] = len(extracted_files)
    else:
        try:
            if archive.suffix.lower() == '.zip':
                with zipfile.ZipFile(archive) as zf:
                    for info in zf.infolist():
                        if info.is_dir():
                            continue
                        out = tmp / info.filename
                        out.parent.mkdir(parents=True, exist_ok=True)
                        with zf.open(info) as s, open(out, 'wb') as d:
                            shutil.copyfileobj(s, d)
            elif archive.suffix.lower() == '.rar':
                import subprocess
                winrar = r"C:\Program Files\WinRAR\UnRAR.exe"
                if os.path.isfile(winrar):
                    subprocess.run([winrar, "x", "-y", str(archive), str(tmp)+os.sep],
                                 check=True, capture_output=True, timeout=120)

            # Move extracted files to extracted/
            if ext_dir.exists():
                shutil.rmtree(ext_dir)
            ext_dir.mkdir(exist_ok=True)

            for f in tmp.rglob("*"):
                if f.is_file():
                    shutil.copy2(f, ext_dir / f.name)
                    stats["extracted"] += 1
        except Exception as e:
            stats["errors"].append(f"Extract: {e}")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    if not stats["extracted"]:
        return stats

    # Rename files
    m = re.match(r"(\d{2})_(\d{4}-\d{2}-\d{2})_(.+)", lec_dir.name)
    date_str = m.group(2) if m else "2026-01-01"
    lec_num = int(m.group(1)) if m else 1
    topic = m.group(3) if m else "TBD"

    tc = sc = pc = dc = 0
    renamed = []

    for f in sorted(ext_dir.iterdir()):
        if not f.is_file():
            continue
        try:
            ext_type = classify_ext(f)
            if ext_type == "txt":
                ct = classify_txt_content(f)
                if ct == "transcript":
                    tc += 1
                    sfx = f"_{tc}" if tc > 1 else ""
                    new = f"{date_str}_лекция{lec_num:02d}_{topic}_транскрипция{sfx}.txt"
                else:
                    sc += 1
                    sfx = f"_{sc}" if sc > 1 else ""
                    new = f"{date_str}_лекция{lec_num:02d}_{topic}_пересказ{sfx}.txt"
            elif ext_type == "presentation":
                pc += 1
                sfx = f"_{pc}" if pc > 1 else ""
                new = f"{date_str}_лекция{lec_num:02d}_{topic}_презентация{sfx}{f.suffix}"
            elif ext_type in ("document", "pdf"):
                dc += 1
                sfx = f"_{dc}" if dc > 1 else ""
                new = f"{date_str}_лекция{lec_num:02d}_{topic}_материал{sfx}{f.suffix}"
            else:
                new = f.name

            target = ext_dir / new
            if target.exists() and target != f:
                base = new.rsplit(f.suffix, 1)[0]
                new = f"{base}_{dc}{f.suffix}"
                target = ext_dir / new

            f.rename(target)
            renamed.append(target)
            stats["renamed"] += 1
        except Exception as e:
            stats["errors"].append(f"Rename {f.name}: {e}")

    # Find subject
    subj = "Unknown"
    parent = lec_dir.parent
    for s in SUBJECT_TOPICS:
        if s in str(parent):
            subj = s
            break
    topic = m.group(3) if m else "TBD"

    # Remove old .md
    for old in lec_dir.glob("*.md"):
        old.unlink()

    # Generate new .md
    md_name = f"{date_str}_лекция{lec_num:02d}_{topic}.md"
    (lec_dir / md_name).write_text(
        gen_md(lec_num, topic, date_str, subj, renamed), encoding='utf-8'
    )
    stats["md"] = 1

    return stats


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    source = Path(args.source).expanduser().resolve()
    if not source.is_dir():
        log.error("Not found: %s", source)
        return

    # Detect if source is a subject dir (contains lecture folders directly)
    # or a module dir (contains subject subdirs)
    has_lectures = any(
        d.is_dir() and re.match(r"\d{2}_\d{4}-\d{2}-\d{2}_", d.name)
        for d in source.iterdir()
    )

    if has_lectures:
        # Source is a subject dir — process lectures directly
        log.info("Source is a subject directory")
        stats = {"extracted": 0, "renamed": 0, "md": 0, "errors": 0}
        for lec_dir in sorted(source.iterdir()):
            if not lec_dir.is_dir():
                continue
            if not re.match(r"\d{2}_\d{4}-\d{2}-\d{2}_", lec_dir.name):
                continue
            s = fix_one_lecture(lec_dir, args.dry_run)
            log.info("  %s: extracted=%d renamed=%d md=%d errors=%d",
                     lec_dir.name, s["extracted"], s["renamed"], s["md"], len(s["errors"]))
            stats["extracted"] += s["extracted"]
            stats["renamed"] += s["renamed"]
            stats["md"] += s["md"]
            stats["errors"] += len(s["errors"])
            for e in s["errors"]:
                log.error("    %s", e)
        log.info("TOTAL: extracted=%d renamed=%d md=%d errors=%d",
                 stats["extracted"], stats["renamed"], stats["md"], stats["errors"])
        return

    # Source is a module dir with subject subdirs
    SKIP = {".qwen", ".scratchpad", "coordination", "knowledge-base",
            "study-output", "materials", ".agent-memory"}
    total = {"extracted": 0, "renamed": 0, "md": 0, "errors": 0}

    for subj_dir in sorted(source.iterdir()):
        log.debug("Checking subj_dir: %s is_dir=%s", subj_dir.name, subj_dir.is_dir())
        if not subj_dir.is_dir() or subj_dir.name.startswith((".", "_")) or subj_dir.name in SKIP:
            log.debug("  Skipping %s", subj_dir.name)
            continue

        log.info("=== %s ===", subj_dir.name)

        for lec_dir in sorted(subj_dir.iterdir()):
            log.debug("  Checking lec_dir: %s is_dir=%s", lec_dir.name, lec_dir.is_dir())
            if not lec_dir.is_dir():
                continue
            if not re.match(r"\d{2}_\d{4}-\d{2}-\d{2}_", lec_dir.name):
                log.debug("    Skipping (no match): %s", lec_dir.name)
                continue

            stats = fix_one_lecture(lec_dir, args.dry_run)
            log.info("  %s: extracted=%d renamed=%d md=%d errors=%d",
                     lec_dir.name, stats["extracted"], stats["renamed"],
                     stats["md"], len(stats["errors"]))

            total["extracted"] += stats["extracted"]
            total["renamed"] += stats["renamed"]
            total["md"] += stats["md"]
            total["errors"] += len(stats["errors"])

            for e in stats["errors"]:
                log.error("    %s", e)

    log.info("TOTAL: extracted=%d renamed=%d md=%d errors=%d",
             total["extracted"], total["renamed"], total["md"], total["errors"])


if __name__ == "__main__":
    main()
