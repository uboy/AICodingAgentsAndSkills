#!/usr/bin/env python3
"""
reorg-module.py — Restructure and rename study materials in a module directory.

For each subject in модуль3:
1. Extract RAR archives (using WinRAR from C:\Program Files\WinRAR\)
2. Match transcripts/summaries with their lecture by date
3. Rename all files to: YYYY-MM-DD_lectureNN_name.ext
4. Organize into: NN_YYYY-MM-DD_Name/ (archive + extracted + output.md)
5. Move standalone materials to materials/ subdirectory

Usage:
    python reorg-module.py --source <module3_path>
    python reorg-module.py --source <module3_path> --dry-run
"""

import argparse
import json
import logging
import os
import re
import shutil
import subprocess
import zipfile
from datetime import datetime
from pathlib import Path

log = logging.getLogger("reorg")
LOG_FORMAT = "[%(levelname)s] %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)

# WinRAR path
WINRAR = r"C:\Program Files\WinRAR\UnRAR.exe"

# --- Lecture name mapping ---
# Maps "лекция N" to a short topic name per subject
LECTURE_TOPICS = {
    "HR-менеджмент": {
        1: "Введение",
        2: "Компетентностный_подход",
        3: "Интервью_по_компетенциям",
        4: "Мотивация",
        5: "Командная_работа",
        6: "Управление_конфликтами",
        7: "Оценка_персонала",
        8: "HR_аналитика",
    },
    "Автоматизация бизнес-процессов": {
        1: "Введение",
        2: "Учет_и_регламентация",
        3: "BPMN",
        4: "TBD",
        5: "RPA_кейсы",
        6: "TBD",
        7: "TBD",
        8: "TBD",
    },
    "Маркетинговые стратегии": {
        1: "Введение",
        2: "Конкурентные_стратегии",
        3: "TBD",
        4: "TBD",
        5: "Позиционирование",
        6: "Маркетинговые_программы",
        7: "TBD",
        8: "TBD",
    },
    "Управление бизнес-процессами": {
        1: "Управление_процессами",
        2: "TBD",
        3: "TBD",
        4: "TBD",
        5: "TBD",
        6: "TBD",
        7: "TBD",
        8: "TBD",
    },
    "Управление проектами": {
        1: "Введение_в_УП",
        2: "TBD",
        3: "TBD",
        4: "TBD",
        5: "TBD",
        6: "TBD",
        7: "TBD",
        8: "TBD",
        9: "TBD",
    },
}


def extract_rar(rar_path: Path, dest: Path) -> list[Path]:
    """Extract RAR archive using WinRAR."""
    if not os.path.isfile(WINRAR):
        log.warning("WinRAR not found at %s — cannot extract %s", WINRAR, rar_path.name)
        return []
    try:
        subprocess.run(
            [WINRAR, "x", "-y", str(rar_path), str(dest) + os.sep],
            check=True, capture_output=True, timeout=120
        )
        return list(dest.rglob("*"))
    except Exception as e:
        log.error("RAR extract failed %s: %s", rar_path.name, e)
        return []


def find_archives(subject_dir: Path) -> list[dict]:
    """Find all lecture archives and parse date/number from filename."""
    archives = []
    pattern = re.compile(
        r"Материалы[ _]к[ _](\d{2})\.(\d{2})\.(\d{4})[ _-]?лекция[ _]?(\d+)",
        re.IGNORECASE
    )
    reorg_pattern = re.compile(r"^\d{2}_\d{4}-\d{2}-\d{2}_")
    for f in sorted(subject_dir.iterdir()):
        if not f.is_file():
            continue
        # Skip already-reorg'd directories
        if f.is_dir() and reorg_pattern.match(f.name):
            continue
        m = pattern.search(f.name)
        if m:
            day, month, year, lec_num = m.groups()
            archives.append({
                "path": f,
                "date": f"{year}-{month}-{day}",
                "date_obj": datetime(int(year), int(month), int(day)),
                "lec_num": int(lec_num),
                "ext": f.suffix.lower(),
            })
    return sorted(archives, key=lambda x: x["date_obj"])


def find_standalone_transcripts(subject_dir: Path) -> list[Path]:
    """Find transcript/summary txt files not inside archives."""
    results = []
    for f in subject_dir.rglob("*.txt"):
        name = f.name.lower()
        if any(kw in name for kw in ["транскрипц", "пересказ"]):
            # Skip if inside extracted/ or knowledge-base/
            parts = f.parts
            if any(p in ("extracted", "knowledge-base", ".scratchpad", "ДР УП-52 2026") for p in parts):
                continue
            results.append(f)
    return results


def match_transcripts_to_archives(transcripts: list[Path], archives: list[dict]) -> dict:
    """Match transcript files to their lecture by date proximity."""
    matched = {}  # archive_idx -> list of transcript paths

    for t in transcripts:
        # Try to extract date from filename
        date_m = re.search(r"(\d{2})\.(\d{2})\.(\d{4})", t.name)
        if date_m:
            t_date = datetime(int(date_m.group(3)), int(date_m.group(2)), int(date_m.group(1)))
            # Find closest archive
            best_idx = None
            best_diff = float("inf")
            for i, a in enumerate(archives):
                diff = abs((t_date - a["date_obj"]).days)
                if diff < best_diff:
                    best_diff = diff
                    best_idx = i
            if best_idx is not None and best_diff <= 14:
                matched.setdefault(best_idx, []).append(t)
    return matched


def is_transcript(path: Path) -> str:
    """Classify a txt file. Returns 'transcript', 'summary', or ''."""
    name = path.name.lower()
    if "транскрипц" in name:
        return "transcript"
    if "пересказ" in name:
        return "summary"
    return ""


def is_presentation(path: Path) -> bool:
    """Check if file is a presentation."""
    return path.suffix.lower() in (".pptx", ".ppt")


def is_lecture_doc(path: Path) -> bool:
    """Check if file is a lecture document (PDF/DOCX that is a lecture, not a case)."""
    name = path.name.lower()
    if path.suffix.lower() not in (".pdf", ".docx"):
        return False
    # Skip books, cases, trend reports
    skip_kw = ["иванова", "оценка компетенций", "тренды", "кейс", "территория полета",
               "голд", "pmbok", "prince", "ipma", "ла", "druck", "гоут"]
    if any(kw in name for kw in skip_kw):
        return False
    if "лекция" in name or "lecture" in name:
        return True
    # Numbered PDFs like "05_Управление_процессами.pdf"
    if re.match(r"\d{2}_", path.stem):
        return True
    return False


def is_standalone_material(path: Path) -> bool:
    """Check if file is a standalone material (book, case, trend report)."""
    name = path.name.lower()
    keep_kw = ["иванова", "оценка компетенций", "тренды", "кейс", "территория полета",
               "pmbok", "prince", "ipma", "голд", "гоут", "druck", "la"]
    return any(kw in name for kw in keep_kw)


def sanitize_name(name: str) -> str:
    """Make filename safe: replace spaces with _, remove special chars."""
    name = name.replace(" ", "_")
    name = re.sub(r"[^\w\-.]", "_", name)
    name = re.sub(r"_+", "_", name)
    return name.strip("_")


def reorg_subject(subject_dir: Path, dry_run: bool, subject_name: str) -> dict:
    """Reorganize one subject directory."""
    stats = {
        "archives_found": 0,
        "archives_extracted": 0,
        "lectures_created": 0,
        "files_renamed": 0,
        "materials_moved": 0,
        "errors": [],
    }

    archives = find_archives(subject_dir)
    transcripts = find_standalone_transcripts(subject_dir)
    matched = match_transcripts_to_archives(transcripts, archives)

    stats["archives_found"] = len(archives)
    topics = LECTURE_TOPICS.get(subject_name, {})

    for i, arch in enumerate(archives):
        lec_num = arch["lec_num"]
        date_str = arch["date"]
        topic = topics.get(lec_num, "TBD")
        dir_name = f"{lec_num:02d}_{date_str}_{topic}"
        lecture_dir = subject_dir / dir_name

        # Skip if already reorg'd
        if lecture_dir.exists() and any(lecture_dir.iterdir()):
            log.info("Skipping existing: %s/", dir_name)
            continue

        if dry_run:
            log.info("[DRY] Would create: %s/", dir_name)
            continue

        lecture_dir.mkdir(exist_ok=True)

        # Create extracted/ subdirectory
        extracted_dir = lecture_dir / "extracted"
        extracted_dir.mkdir(exist_ok=True)

        # Copy archive with meaningful name
        arch_name = f"{date_str}_лекция{lec_num:02d}_{sanitize_name(topic)}{arch['ext']}"
        arch_dest = lecture_dir / arch_name
        shutil.copy2(arch["path"], arch_dest)

        # Extract archive contents
        if arch["ext"] == ".zip":
            try:
                with zipfile.ZipFile(arch["path"]) as zf:
                    zf.extractall(extracted_dir)
                stats["archives_extracted"] += 1
            except Exception as e:
                stats["errors"].append(f"{arch['path'].name}: {e}")
        elif arch["ext"] == ".rar":
            files = extract_rar(arch["path"], extracted_dir)
            if files:
                stats["archives_extracted"] += 1

        # Rename files inside extracted/
        renamed_transcript = None
        renamed_summary = None
        lec_pdfs = []
        pres_count = 0
        doc_count = 0

        for f in extracted_dir.iterdir():
            if not f.is_file():
                continue
            try:
                ftype = is_transcript(f)
                if ftype == "transcript":
                    new_name = f"{date_str}_лекция{lec_num:02d}_транскрипция.txt"
                    f.rename(f.parent / new_name)
                    renamed_transcript = new_name
                    stats["files_renamed"] += 1
                elif ftype == "summary":
                    new_name = f"{date_str}_лекция{lec_num:02d}_пересказ.txt"
                    f.rename(f.parent / new_name)
                    renamed_summary = new_name
                    stats["files_renamed"] += 1
                elif is_presentation(f):
                    pres_count += 1
                    suffix = f"_{pres_count}" if pres_count > 1 else ""
                    new_name = f"{date_str}_лекция{lec_num:02d}_презентация{suffix}{f.suffix}"
                    target = f.parent / new_name
                    if target.exists():
                        base = new_name.rsplit(f.suffix, 1)[0]
                        new_name = f"{base}_{pres_count}{f.suffix}"
                    f.rename(target)
                    stats["files_renamed"] += 1
                elif is_lecture_doc(f):
                    doc_count += 1
                    suffix = f"_{doc_count}" if doc_count > 1 else ""
                    new_name = f"{date_str}_лекция{lec_num:02d}_материал{suffix}{f.suffix}"
                    target = f.parent / new_name
                    if target.exists():
                        base = new_name.rsplit(f.suffix, 1)[0]
                        new_name = f"{base}_{doc_count}{f.suffix}"
                    f.rename(target)
                    lec_pdfs.append(new_name)
                    stats["files_renamed"] += 1
            except Exception as e:
                stats["errors"].append(f"Rename {f.name}: {e}")
                log.warning("Rename error %s: %s", f.name, e)

        # Handle matched standalone transcripts
        for t in matched.get(i, []):
            ftype = is_transcript(t)
            if ftype == "transcript" and not renamed_transcript:
                new_name = f"{date_str}_лекция{lec_num:02d}_транскрипция.txt"
                shutil.copy2(t, extracted_dir / new_name)
                stats["files_renamed"] += 1
            elif ftype == "summary" and not renamed_summary:
                new_name = f"{date_str}_лекция{lec_num:02d}_пересказ.txt"
                shutil.copy2(t, extracted_dir / new_name)
                stats["files_renamed"] += 1

        # Create output.md with meaningful name
        output_name = f"{date_str}_лекция{lec_num:02d}_{sanitize_name(topic)}.md"
        output_md = lecture_dir / output_name
        if not output_md.exists():
            content = f"""---
title: "Лекция {lec_num}: {topic.replace('_', ' ')}"
subject: "{subject_name}"
date: "{date_str}"
lecture_number: {lec_num}
---

# Лекция {lec_num}: {topic.replace('_', ' ')}

## Источник
- Дата: {date_str}
- Архив: `{arch_name}`

## Файлы
- Транскрипция: `extracted/{renamed_transcript or 'N/A'}`
- Пересказ: `extracted/{renamed_summary or 'N/A'}`
- Материалы: {', '.join(f'`extracted/{p}`' for p in lec_pdfs) or 'N/A'}

## Содержание
*(Заполняется автоматически при обработке через study-materials-prep.py)*
"""
            output_md.write_text(content, encoding="utf-8")

        stats["lectures_created"] += 1

    # Move standalone materials to materials/
    materials_dir = subject_dir / "materials"
    for f in subject_dir.iterdir():
        if not f.is_file():
            continue
        if is_standalone_material(f):
            if not dry_run:
                materials_dir.mkdir(exist_ok=True)
                shutil.copy2(f, materials_dir / f.name)
            stats["materials_moved"] += 1
        elif f.suffix.lower() in (".url", ".lnk", ".ini"):
            pass  # skip shortcuts

    # Clean up old knowledge-base dirs (optional — just log)
    for cleanup_dir in ["knowledge-base", ".scratchpad"]:
        old = subject_dir / cleanup_dir
        if old.exists() and not dry_run:
            log.info("Keeping %s/ (may contain manual work)", cleanup_dir)

    return stats


def main():
    parser = argparse.ArgumentParser(
        description="Restructure module3 study materials into lecture-folders."
    )
    parser.add_argument("--source", required=True, help="Path to модуль3 directory")
    parser.add_argument("--dry-run", action="store_true", help="Preview only")
    args = parser.parse_args()

    source = Path(args.source).expanduser().resolve()
    if not source.is_dir():
        log.error("Source not found: %s", source)
        return

    log.info("Source: %s", source)
    log.info("Dry run: %s", args.dry_run)

    SKIP_DIRS = {".qwen", ".scratchpad", "__pycache__", "node_modules",
                 "coordination", "knowledge-base", "study-output"}

    subjects = [
        d for d in source.iterdir()
        if d.is_dir()
        and not d.name.startswith((".", "_"))
        and d.name not in SKIP_DIRS
    ]

    for subj in sorted(subjects, key=lambda x: x.name):
        log.info("=== %s ===", subj.name)
        stats = reorg_subject(subj, args.dry_run, subj.name)
        log.info("Archives: %d | Extracted: %d | Lectures: %d | Renamed: %d | Materials: %d",
                 stats["archives_found"], stats["archives_extracted"],
                 stats["lectures_created"], stats["files_renamed"], stats["materials_moved"])
        if stats["errors"]:
            log.warning("Errors: %s", stats["errors"])


if __name__ == "__main__":
    main()
