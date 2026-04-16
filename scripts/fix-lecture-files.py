#!/usr/bin/env python3
"""
fix-lecture-files.py — Fix extracted files, rename properly, and generate
descriptions for all existing lecture folders.

Usage:
    python fix-lecture-files.py --source <module3_path>
    python fix-lecture-files.py --source <module3_path> --dry-run
"""

import argparse
import logging
import os
import re
import shutil
import zipfile
from datetime import datetime
from pathlib import Path

log = logging.getLogger("fix")
logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")

WINRAR = r"C:\Program Files\WinRAR\UnRAR.exe"

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


def extract_zip_proper(zip_path: Path, dest: Path) -> list[Path]:
    """Extract ZIP with proper Cyrillic encoding."""
    extracted = []
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            name = info.filename
            if not (info.flag_bits & 0x800):
                try:
                    name = info.filename.encode('cp437').decode('cp866')
                except:
                    pass
            out = dest / name
            out.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(info) as s, open(out, 'wb') as d:
                shutil.copyfileobj(s, d)
            extracted.append(out)
    return extracted


def classify(path: Path) -> str:
    """Classify file as transcript, summary, presentation, document, pdf, or other."""
    name = path.name.lower()
    ext = path.suffix.lower()
    if any(k in name for k in ["транскрипц", "transcript"]):
        return "transcript"
    if any(k in name for k in ["пересказ", "summary"]):
        return "summary"
    if ext in (".pptx", ".ppt"):
        return "presentation"
    if ext in (".docx", ".doc"):
        return "document"
    if ext == ".pdf":
        return "pdf"
    if ext == ".txt":
        try:
            c = path.read_text(encoding='utf-8', errors='replace')[:500]
            if any(k in c for k in ["транскрипц", "расшифровка"]):
                return "transcript"
            if any(k in c for k in ["пересказ", "резюме"]):
                return "summary"
        except:
            pass
    return "other"


def file_desc(path: Path) -> str:
    """Brief description from file content."""
    try:
        t = path.read_text(encoding='utf-8', errors='replace')[:800]
        lines = [l.strip() for l in t.split('\n') if l.strip() and len(l.strip()) > 20]
        return lines[0][:300] if lines else ""
    except:
        return ""


def gen_md(lec_num, topic, date_str, subj, files: list[Path]) -> str:
    """Generate proper .md with actual content."""
    transcript = ""
    summary = ""
    for f in files:
        ft = classify(f)
        if ft == "transcript":
            transcript = file_desc(f)[:500]
        elif ft == "summary":
            summary = file_desc(f)[:500]
    
    flist = "\n".join(
        f"- `{f.name}` ({f.stat().st_size/1024:.0f} KB)"
        for f in sorted(files, key=lambda x: x.name)
    )
    
    desc = summary if summary else (transcript[:300] if transcript else "*Описание будет добавлено*")
    
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


def fix_lecture(lec_dir: Path, dry_run: bool) -> dict:
    """Fix one lecture folder: extract, rename, regenerate .md."""
    stats = {"extracted": 0, "renamed": 0, "md_generated": 0, "errors": []}
    
    # Find archive in this folder
    archive = None
    for f in lec_dir.iterdir():
        if f.is_file() and f.suffix.lower() in ('.zip', '.rar'):
            archive = f
            break
    
    if not archive:
        return stats
    
    # Extract
    ext_dir = lec_dir / "extracted"
    if ext_dir.exists():
        shutil.rmtree(ext_dir)
    ext_dir.mkdir(exist_ok=True)
    
    extracted = []
    if archive.suffix.lower() == '.zip':
        extracted = extract_zip_proper(archive, ext_dir)
    elif archive.suffix.lower() == '.rar':
        if os.path.isfile(WINRAR):
            import subprocess
            subprocess.run([WINRAR, "x", "-scu", "-y", str(archive), str(ext_dir)+os.sep],
                          check=True, capture_output=True, timeout=120)
            extracted = list(ext_dir.rglob("*"))
    
    stats["extracted"] = len(extracted)
    
    # Rename
    tc = sc = pc = dc = 0
    for f in extracted:
        if not f.is_file():
            continue
        ft = classify(f)
        try:
            # Parse date and lec_num from folder name
            m = re.match(r"(\d{2})_(\d{4}-\d{2}-\d{2})_", lec_dir.name)
            date_str = m.group(2) if m else "2026-01-01"
            lec_num = int(m.group(1)) if m else 1
            
            if ft == "transcript":
                tc += 1
                sfx = f"_{tc}" if tc > 1 else ""
                new = f"{date_str}_лекция{lec_num:02d}_транскрипция{sfx}.txt"
            elif ft == "summary":
                sc += 1
                sfx = f"_{sc}" if sc > 1 else ""
                new = f"{date_str}_лекция{lec_num:02d}_пересказ{sfx}.txt"
            elif ft == "presentation":
                pc += 1
                sfx = f"_{pc}" if pc > 1 else ""
                new = f"{date_str}_лекция{lec_num:02d}_презентация{sfx}{f.suffix}"
            elif ft in ("document", "pdf"):
                dc += 1
                sfx = f"_{dc}" if dc > 1 else ""
                new = f"{date_str}_лекция{lec_num:02d}_материал{sfx}{f.suffix}"
            else:
                new = f.name
            
            target = ext_dir / new
            if target.exists() and target != f:
                base = new.rsplit(f.suffix, 1)[0]
                new = f"{base}_{dc}{f.suffix}"
                target = ext_dir / new
            
            f.rename(target)
            stats["renamed"] += 1
        except Exception as e:
            stats["errors"].append(f"Rename {f.name}: {e}")
    
    # Regenerate .md
    renamed_files = list(ext_dir.iterdir())
    m = re.match(r"(\d{2})_(\d{4}-\d{2}-\d{2})_(.+)", lec_dir.name)
    if m:
        lec_num = int(m.group(1))
        date_str = m.group(2)
        topic = m.group(3)
        
        # Find subject
        subj = "Unknown"
        for s, topics in SUBJECT_TOPICS.items():
            if lec_dir.parent.name in s or s in str(lec_dir.parent):
                subj = s
                break
        
        # Remove old .md files
        for old_md in lec_dir.glob("*.md"):
            old_md.unlink()
        
        md_name = f"{date_str}_лекция{lec_num:02d}_{topic}.md"
        md_path = lec_dir / md_name
        md_path.write_text(gen_md(lec_num, topic, date_str, subj, renamed_files), encoding='utf-8')
        stats["md_generated"] = 1
    
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
    
    SKIP = {".qwen", ".scratchpad", "coordination", "knowledge-base",
            "study-output", "materials", ".agent-memory"}
    
    total = {"extracted": 0, "renamed": 0, "md": 0, "errors": 0}
    
    for subj_dir in sorted(source.iterdir()):
        if not subj_dir.is_dir() or subj_dir.name.startswith((".", "_")) or subj_dir.name in SKIP:
            continue
        
        log.info("=== %s ===", subj_dir.name)
        
        for lec_dir in sorted(subj_dir.iterdir()):
            if not lec_dir.is_dir():
                continue
            if not re.match(r"\d{2}_\d{4}-\d{2}-\d{2}_", lec_dir.name):
                continue
            
            stats = fix_lecture(lec_dir, args.dry_run)
            log.info("  %s: extracted=%d renamed=%d md=%d errors=%d",
                     lec_dir.name, stats["extracted"], stats["renamed"],
                     stats["md_generated"], len(stats["errors"]))
            
            total["extracted"] += stats["extracted"]
            total["renamed"] += stats["renamed"]
            total["md"] += stats["md_generated"]
            total["errors"] += len(stats["errors"])
            
            for e in stats["errors"]:
                log.error("    %s: %s", lec_dir.name, e)
    
    log.info("TOTAL: extracted=%d renamed=%d md=%d errors=%d",
             total["extracted"], total["renamed"], total["md"], total["errors"])


if __name__ == "__main__":
    main()
