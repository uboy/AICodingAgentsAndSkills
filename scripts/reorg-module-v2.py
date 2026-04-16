#!/usr/bin/env python3
"""
reorg-module-v2.py — Restructure study materials with proper encoding,
file renaming, content-based descriptions, and integrity verification.

Usage:
    python reorg-module-v2.py --source <module3_path>
    python reorg-module-v2.py --source <module3_path> --dry-run
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

WINRAR = r"C:\Program Files\WinRAR\UnRAR.exe"

LECTURE_TOPICS = {
    "HR-менеджмент": {
        1: "Введение", 2: "Компетентностный_подход", 3: "Интервью_по_компетенциям",
        4: "Мотивация", 5: "Командная_работа", 6: "Управление_конфликтами",
        7: "Оценка_персонала", 8: "HR_аналитика",
    },
    "Автоматизация бизнес-процессов": {
        1: "Введение", 2: "Учет_и_регламентация", 3: "BPMN", 4: "TBD",
        5: "RPA_кейсы", 6: "TBD", 7: "TBD", 8: "TBD",
    },
    "Маркетинговые стратегии": {
        1: "Введение", 2: "Конкурентные_стратегии", 3: "TBD", 4: "TBD",
        5: "Позиционирование", 6: "Маркетинговые_программы", 7: "TBD", 8: "TBD",
    },
    "Управление бизнес-процессами": {
        1: "Управление_процессами", 2: "TBD", 3: "TBD", 4: "TBD",
        5: "TBD", 6: "TBD", 7: "TBD", 8: "TBD",
    },
    "Управление проектами": {
        1: "Введение_в_УП", 2: "TBD", 3: "TBD", 4: "TBD", 5: "TBD",
        6: "TBD", 7: "TBD", 8: "TBD", 9: "TBD",
    },
}


def extract_zip(zip_path: Path, dest: Path) -> list[Path]:
    """Extract ZIP archive with proper encoding."""
    extracted = []
    try:
        with zipfile.ZipFile(zip_path) as zf:
            for info in zf.infolist():
                # Fix encoding for Cyrillic filenames
                if info.flag_bits & 0x800:  # UTF-8 flag
                    name = info.filename
                else:
                    # Try CP866 (DOS Cyrillic), fallback to UTF-8
                    try:
                        name = info.filename.encode('cp437').decode('cp866')
                    except:
                        name = info.filename
                out_path = dest / name
                out_path.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(info) as src, open(out_path, 'wb') as dst:
                    shutil.copyfileobj(src, dst)
                extracted.append(out_path)
    except Exception as e:
        log.error("ZIP extract failed %s: %s", zip_path.name, e)
    return [f for f in extracted if f.is_file()]


def extract_rar(rar_path: Path, dest: Path) -> list[Path]:
    """Extract RAR archive using WinRAR with proper encoding."""
    if not os.path.isfile(WINRAR):
        log.warning("WinRAR not found at %s", WINRAR)
        return []
    try:
        # -scu = Unicode filenames
        # -y = yes to all
        subprocess.run(
            [WINRAR, "x", "-scu", "-y", str(rar_path), str(dest) + os.sep],
            check=True, capture_output=True, timeout=120
        )
        return list(dest.rglob("*"))
    except subprocess.CalledProcessError as e:
        # Fallback: try without -scu
        try:
            subprocess.run(
                [WINRAR, "x", "-y", str(rar_path), str(dest) + os.sep],
                check=True, capture_output=True, timeout=120
            )
            return list(dest.rglob("*"))
        except Exception as e2:
            log.error("RAR extract failed %s: %s", rar_path.name, e2)
            return []
    except Exception as e:
        log.error("RAR extract failed %s: %s", rar_path.name, e)
        return []


def classify_extracted_file(path: Path) -> str:
    """Classify file by extension and content."""
    name = path.name.lower()
    ext = path.suffix.lower()
    
    if "транскрипц" in name or "transcript" in name:
        return "transcript"
    if "пересказ" in name or "summary" in name:
        return "summary"
    if ext in (".pptx", ".ppt"):
        return "presentation"
    if ext in (".docx", ".doc"):
        return "document"
    if ext in (".pdf",):
        return "pdf"
    if ext in (".txt",):
        # Check content to distinguish
        try:
            content = path.read_text(encoding='utf-8', errors='replace')[:500]
            if any(kw in content for kw in ["транскрипц", "расшифровка", "запись занятия"]):
                return "transcript"
            if any(kw in content for kw in ["пересказ", "резюме", "summary"]):
                return "summary"
        except:
            pass
    return "other"


def get_file_description(path: Path) -> str:
    """Generate a brief description from file content."""
    try:
        content = path.read_text(encoding='utf-8', errors='replace')[:1000]
        # Get first meaningful line
        lines = [l.strip() for l in content.split('\n') if l.strip()]
        if lines:
            # Take first 2-3 lines as description
            desc = ' '.join(lines[:3])
            if len(desc) > 200:
                desc = desc[:200] + '...'
            return desc
    except:
        pass
    return ""


def generate_lecture_md(path: Path, lec_num: int, topic: str, date_str: str,
                        subject: str, extracted_files: list[Path]) -> str:
    """Generate a proper .md file with actual content description."""
    # Find transcript and summary for preview
    transcript_content = ""
    summary_content = ""
    for f in extracted_files:
        ftype = classify_extracted_file(f)
        if ftype == "transcript":
            transcript_content = get_file_description(f)[:500]
        elif ftype == "summary":
            summary_content = get_file_description(f)[:500]
    
    file_list = []
    for f in sorted(extracted_files, key=lambda x: x.name):
        ftype = classify_extracted_file(f)
        size_kb = f.stat().st_size / 1024
        file_list.append(f"- `{f.name}` ({size_kb:.0f} KB) — {ftype}")
    
    lines = [
        "---",
        f'title: "Лекция {lec_num}: {topic.replace("_", " ")}"',
        f'subject: "{subject}"',
        f'date: "{date_str}"',
        f'lecture_number: {lec_num}',
        "---",
        "",
        f"# Лекция {lec_num}: {topic.replace('_', ' ')}",
        "",
        f"**Дата:** {date_str}",
        "",
        "## Описание",
        "",
    ]
    
    if summary_content:
        lines.append(f"**Пересказ:** {summary_content}")
        lines.append("")
    elif transcript_content:
        # Use first lines of transcript as preview
        lines.append(f"**Транскрипция:** {transcript_content[:300]}...")
        lines.append("")
    else:
        lines.append("*Описание будет добавлено после обработки материалов*")
        lines.append("")
    
    lines.append("## Файлы лекции")
    lines.append("")
    lines.extend(file_list)
    lines.append("")
    lines.append("## Использование")
    lines.append("")
    lines.append("- Загрузить этот файл в AI-агент как контекст")
    lines.append("- Использовать транскрипцию для поиска конкретных моментов")
    lines.append("- Пересказ — для быстрого ознакомления")
    lines.append("")
    
    return "\n".join(lines)


def sanitize_name(name: str) -> str:
    """Make filename safe."""
    name = name.replace(" ", "_")
    name = re.sub(r"[^\w\-.]", "_", name)
    name = re.sub(r"_+", "_", name)
    return name.strip("_")


def verify_lecture_files(lecture_dir: Path, expected_count: int) -> list[str]:
    """Verify that all files are present in extracted folder."""
    issues = []
    extracted = lecture_dir / "extracted"
    if not extracted.exists():
        issues.append("extracted/ folder missing")
        return issues
    
    actual_count = len([f for f in extracted.iterdir() if f.is_file()])
    if actual_count != expected_count:
        issues.append(f"Expected {expected_count} files, found {actual_count}")
    
    return issues


def reorg_subject(subject_dir: Path, dry_run: bool, subject_name: str) -> dict:
    """Reorganize one subject directory with full verification."""
    stats = {
        "archives_found": 0, "archives_extracted": 0,
        "lectures_created": 0, "files_renamed": 0,
        "materials_moved": 0, "errors": [], "warnings": [],
    }
    
    # Find archives
    archives = []
    pattern = re.compile(
        r"Материалы[ _]к[ _](\d{2})\.(\d{2})\.(\d{4})[ _-]?лекция[ _]?(\d+)",
        re.IGNORECASE
    )
    reorg_pattern = re.compile(r"^\d{2}_\d{4}-\d{2}-\d{2}_")
    
    for f in sorted(subject_dir.iterdir()):
        if not f.is_file():
            continue
        if f.is_dir() and reorg_pattern.match(f.name):
            continue
        m = pattern.search(f.name)
        if m:
            day, month, year, lec_num = m.groups()
            archives.append({
                "path": f, "date": f"{year}-{month}-{day}",
                "date_obj": datetime(int(year), int(month), int(day)),
                "lec_num": int(lec_num), "ext": f.suffix.lower(),
            })
    
    stats["archives_found"] = len(archives)
    topics = LECTURE_TOPICS.get(subject_name, {})
    
    for arch in archives:
        lec_num = arch["lec_num"]
        date_str = arch["date"]
        topic = topics.get(lec_num, "TBD")
        dir_name = f"{lec_num:02d}_{date_str}_{topic}"
        lecture_dir = subject_dir / dir_name
        
        if dry_run:
            log.info("[DRY] Would create: %s/", dir_name)
            continue
        
        lecture_dir.mkdir(exist_ok=True)
        extracted_dir = lecture_dir / "extracted"
        extracted_dir.mkdir(exist_ok=True)
        
        # Copy archive with meaningful name
        arch_name = f"{date_str}_лекция{lec_num:02d}_{sanitize_name(topic)}{arch['ext']}"
        shutil.copy2(arch["path"], lecture_dir / arch_name)
        
        # Count original files
        if arch["ext"] == ".zip":
            with zipfile.ZipFile(arch["path"]) as zf:
                expected_count = len([n for n in zf.namelist() if not n.endswith('/')])
        else:
            expected_count = 0  # Will verify after extraction
        
        # Extract
        extracted_files = []
        if arch["ext"] == ".zip":
            extracted_files = extract_zip(arch["path"], extracted_dir)
        elif arch["ext"] == ".rar":
            extracted_files = extract_rar(arch["path"], extracted_dir)
        
        if extracted_files:
            stats["archives_extracted"] += 1
        
        # Rename extracted files
        transcript_count = 0
        summary_count = 0
        pres_count = 0
        doc_count = 0
        renamed_files = []
        
        for f in extracted_files:
            if not f.is_file():
                continue
            ftype = classify_extracted_file(f)
            try:
                if ftype == "transcript":
                    transcript_count += 1
                    suffix = f"_{transcript_count}" if transcript_count > 1 else ""
                    new_name = f"{date_str}_лекция{lec_num:02d}_транскрипция{suffix}.txt"
                elif ftype == "summary":
                    summary_count += 1
                    suffix = f"_{summary_count}" if summary_count > 1 else ""
                    new_name = f"{date_str}_лекция{lec_num:02d}_пересказ{suffix}.txt"
                elif ftype == "presentation":
                    pres_count += 1
                    suffix = f"_{pres_count}" if pres_count > 1 else ""
                    new_name = f"{date_str}_лекция{lec_num:02d}_презентация{suffix}{f.suffix}"
                elif ftype in ("document", "pdf"):
                    doc_count += 1
                    suffix = f"_{doc_count}" if doc_count > 1 else ""
                    new_name = f"{date_str}_лекция{lec_num:02d}_материал{suffix}{f.suffix}"
                else:
                    # Generic rename for unrecognized files
                    new_name = f"{date_str}_лекция{lec_num:02d}_{sanitize_name(f.stem)}{f.suffix}"
                
                target = extracted_dir / new_name
                if target.exists() and target != f:
                    base = new_name.rsplit(f.suffix, 1)[0]
                    new_name = f"{base}_{doc_count}{f.suffix}"
                    target = extracted_dir / new_name
                
                f.rename(target)
                renamed_files.append(target)
                stats["files_renamed"] += 1
            except Exception as e:
                stats["errors"].append(f"Rename {f.name}: {e}")
        
        # Generate proper .md
        md_name = f"{date_str}_лекция{lec_num:02d}_{sanitize_name(topic)}.md"
        md_path = lecture_dir / md_name
        if not md_path.exists():
            content = generate_lecture_md(
                md_path, lec_num, topic, date_str, subject_name, renamed_files
            )
            md_path.write_text(content, encoding="utf-8")
        
        # Verify
        issues = verify_lecture_files(lecture_dir, expected_count)
        if issues:
            stats["warnings"].append(f"{dir_name}: {'; '.join(issues)}")
        
        stats["lectures_created"] += 1
    
    # Move standalone materials
    materials_dir = subject_dir / "materials"
    for f in subject_dir.iterdir():
        if not f.is_file():
            continue
        name = f.name.lower()
        # Move books, cases, trend reports
        if any(kw in name for kw in ["иванова", "оценка компетенций", "тренды", "территория полета",
                                      "pmbok", "prince", "ipma", "голд", "druck", "la", "достаточно ли вы умны"]):
            if not dry_run:
                materials_dir.mkdir(exist_ok=True)
                shutil.copy2(f, materials_dir / f.name)
            stats["materials_moved"] += 1
    
    return stats


def main():
    parser = argparse.ArgumentParser(description="Restructure module3 study materials.")
    parser.add_argument("--source", required=True, help="Path to module3 directory")
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
        if d.is_dir() and not d.name.startswith((".", "_")) and d.name not in SKIP_DIRS
    ]
    
    for subj in sorted(subjects, key=lambda x: x.name):
        log.info("=== %s ===", subj.name)
        stats = reorg_subject(subj, args.dry_run, subj.name)
        log.info("Archives: %d | Extracted: %d | Lectures: %d | Renamed: %d | Materials: %d",
                 stats["archives_found"], stats["archives_extracted"],
                 stats["lectures_created"], stats["files_renamed"], stats["materials_moved"])
        if stats["errors"]:
            log.error("Errors: %s", stats["errors"])
        if stats["warnings"]:
            log.warning("Warnings: %s", stats["warnings"])


if __name__ == "__main__":
    main()
