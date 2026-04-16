#!/usr/bin/env python3
"""
study-materials-prep.py — Prepare study materials for RAG indexing.

Recursively scans a source directory, extracts content from all supported
files (archives, PDFs, DOCX, PPTX, TXT, MD, FB2, DJVU, HTML, images),
and produces structured Markdown output ready for AI agents.

Usage:
    python study-materials-prep.py --source <path>
    python study-materials-prep.py --source <path> --output <path>
    python study-materials-prep.py --source <path> --install-deps

The subject name is auto-detected from the source directory name.
Output goes to ./study-output/<subject>/ by default (or --output if given).
OCR is always enabled for PDFs and images.
Use --install-deps to auto-install missing dependencies.
"""

import argparse
import hashlib
import json
import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
LOG_FORMAT = "[%(levelname)s] %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
log = logging.getLogger("study-prep")

ARCHIVE_EXTS = {".zip", ".rar", ".7z", ".tar", ".tar.gz", ".tgz"}
TEXT_EXTS = {".txt", ".md", ".markdown", ".text", ".log", ".csv"}
DOC_EXTS = {".docx", ".doc"}
PDF_EXTS = {".pdf"}
PPTX_EXTS = {".pptx", ".ppt"}
BOOK_EXTS = {".epub", ".fb2", ".mobi"}
HTML_EXTS = {".html", ".htm", ".xhtml"}
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".webp"}
SKIP_EXTS = {".url", ".lnk", ".ini", ".tmp", ".DS_Store", ".Thumbs.db",
             ".json", ".jsonl", ".orig", ".bak", ".py", ".pyc", ".exe",
             ".dll", ".so", ".dylib"}
SKIP_DIRS = {".git", ".qwen", ".claude", ".codex", ".cursor", ".gemini",
             ".opencode", ".scratchpad", "__pycache__", "node_modules",
             ".agent-memory", "coordination", "knowledge-base",
             "_codex_tmp", "chrome", "chromedriver", "geckodriver",
             "tools", "ДР УП-52 2026", "ДЗ_материалы"}


def check_deps():
    """Check optional dependencies, return warnings list."""
    w = []
    for pkg, pip, desc in [
        ("docx", "python-docx", "DOCX extraction"),
        ("pptx", "python-pptx", "PPTX extraction"),
        ("PIL", "Pillow", "Image/OCR support"),
    ]:
        try:
            __import__(pkg)
        except ImportError:
            w.append(f"MISSING: {pip} ({desc}) — pip install {pip}")
    if shutil.which("tesseract"):
        try:
            import pytesseract  # noqa
        except ImportError:
            w.append("MISSING: pytesseract (OCR) — pip install pytesseract")
    else:
        w.append("OPTIONAL: tesseract-ocr not on PATH (OCR disabled)")
    return w


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

def read_text(path: Path) -> str:
    for enc in ("utf-8", "cp1251", "latin-1"):
        try:
            return path.read_text(encoding=enc)
        except (UnicodeDecodeError, ValueError, UnicodeError):
            continue
    return path.read_text(encoding="utf-8", errors="replace")


def extract_docx(path: Path) -> str:
    try:
        from docx import Document
        doc = Document(str(path))
        parts = []
        for p in doc.paragraphs:
            if p.style.name.startswith("Heading"):
                lvl = p.style.name.replace("Heading ", "").strip()
                try:
                    n = int(lvl)
                except ValueError:
                    n = 1
                parts.append(f"\n{'#' * min(n, 6)} {p.text}\n")
            else:
                parts.append(p.text)
        for tbl in doc.tables:
            parts.append("")
            for row in tbl.rows:
                parts.append("| " + " | ".join(c.text for c in row.cells) + " |")
        return "\n".join(parts)
    except Exception as e:
        return f"[ERROR DOCX: {e}]"


def extract_pdf(path: Path, img_dir: Path) -> tuple[str, int]:
    """Return (text, ocr_count)."""
    text = ""
    ocr_count = 0
    # Try PyMuPDF
    try:
        import fitz
        doc = fitz.open(str(path))
        for i, page in enumerate(doc):
            t = page.get_text()
            if t.strip():
                text += f"\n### Страница {i + 1}\n{t}\n"
            else:
                # No text layer — extract image for OCR
                pix = page.get_pixmap(dpi=150)
                img_path = img_dir / f"{path.stem}_p{i:03d}.png"
                pix.save(str(img_path))
                text += f"\n### Страница {i + 1}\n[изображение — OCR ниже]\n"
        doc.close()
    except ImportError:
        try:
            import pdfplumber
            with pdfplumber.open(str(path)) as pdf:
                for i, page in enumerate(pdf.pages):
                    t = page.extract_text() or ""
                    text += f"\n### Страница {i + 1}\n{t}\n"
        except ImportError:
            if shutil.which("pdftotext"):
                r = subprocess.run(["pdftotext", "-layout", str(path), "-"],
                                   capture_output=True, text=True)
                text = r.stdout
            else:
                return "[PDF extraction unavailable — install PyMuPDF]", 0

    # OCR for extracted page images
    if img_dir.exists():
        for img in sorted(img_dir.glob("*.png")):
            ocr_text = ocr_image(img)
            if ocr_text.strip():
                text += f"\n[OCR результат]\n{ocr_text}\n"
                ocr_count += 1
            img.unlink()  # clean up

    if not text.strip():
        text = "[PDF пуст — нет текстового слоя и изображений]"
    return text, ocr_count


def extract_pptx(path: Path, img_dir: Path) -> tuple[str, int]:
    parts = []
    ocr_count = 0
    try:
        from pptx import Presentation
        prs = Presentation(str(path))
        for n, slide in enumerate(prs.slides, 1):
            parts.append(f"\n## Слайд {n}\n")
            for shape in slide.shapes:
                if shape.has_text_frame:
                    for para in shape.text_frame.paragraphs:
                        if para.text.strip():
                            parts.append(para.text.strip())
                if shape.has_table:
                    for row in shape.table.rows:
                        parts.append("| " + " | ".join(c.text for c in row.cells) + " |")
    except Exception as e:
        parts.append(f"[ERROR PPTX: {e}]")
    return "\n".join(parts), ocr_count


def extract_fb2(path: Path) -> str:
    try:
        import xml.etree.ElementTree as ET
        tree = ET.parse(str(path))
        root = tree.getroot()
        ns = {"fb": "http://www.gribuser.ru/xml/fictionbook/2.0"}
        parts = []
        for section in root.iter("{http://www.gribuser.ru/xml/fictionbook/2.0}section"):
            title_el = section.find("fb:title", ns)
            if title_el is not None:
                t = "".join(title_el.itertext()).strip()
                if t:
                    parts.append(f"\n## {t}\n")
            for p in section.iter("{http://www.gribuser.ru/xml/fictionbook/2.0}p"):
                t = "".join(p.itertext()).strip()
                if t:
                    parts.append(t)
        return "\n\n".join(parts) if parts else "[FB2: no text extracted]"
    except Exception as e:
        return f"[ERROR FB2: {e}]"


def extract_djvu(path: Path) -> str:
    """Extract text from DJVU using djvused or djvutxt."""
    for tool, args in [
        ("djvutxt", [str(path)]),
        ("djvused", ["-e", "print-txt", str(path)]),
    ]:
        if shutil.which(tool):
            try:
                r = subprocess.run([tool] + args, capture_output=True, text=True, timeout=120)
                if r.stdout.strip():
                    return r.stdout
            except Exception:
                continue
    return f"[DJVU extraction unavailable — install djvulibre: {path.name}]"


def ocr_image(img_path: Path) -> str:
    try:
        import pytesseract
        from PIL import Image
        img = Image.open(img_path)
        return pytesseract.image_to_string(img, lang="rus+eng")
    except Exception as e:
        return f"[OCR error: {e}]"


def extract_html(path: Path) -> str:
    raw = path.read_text(encoding="utf-8", errors="replace")
    clean = re.sub(r"<[^>]+>", " ", raw)
    clean = re.sub(r"\s+", " ", clean).strip()
    return clean


def extract_archive(path: Path, dest: Path) -> list[Path]:
    extracted = []
    try:
        if path.suffix.lower() == ".zip" or path.name.endswith(".zip"):
            with zipfile.ZipFile(path) as zf:
                zf.extractall(dest)
                extracted = [dest / n for n in zf.namelist()]
        elif path.suffix.lower() == ".rar":
            if shutil.which("unrar"):
                subprocess.run(["unrar", "x", str(path), str(dest) + os.sep],
                               check=True, capture_output=True, timeout=120)
                extracted = list(dest.rglob("*"))
            elif shutil.which("7z"):
                subprocess.run(["7z", "x", str(path), f"-o{dest}"],
                               check=True, capture_output=True, timeout=120)
                extracted = list(dest.rglob("*"))
            else:
                log.warning("No unrar/7z — skip %s", path.name)
        elif path.suffix.lower() in (".7z", ".tar", ".tar.gz") or path.name.endswith((".tar.gz", ".tgz")):
            if shutil.which("7z"):
                subprocess.run(["7z", "x", str(path), f"-o{dest}"],
                               check=True, capture_output=True, timeout=120)
                extracted = list(dest.rglob("*"))
            else:
                log.warning("No 7z — skip %s", path.name)
    except Exception as e:
        log.error("Archive error %s: %s", path.name, e)
    return [f for f in extracted if f.is_file()]


# ---------------------------------------------------------------------------
# Classify
# ---------------------------------------------------------------------------

def classify(path: Path) -> str:
    ext = path.suffix.lower()
    if path.name.endswith((".tar.gz", ".tgz")):
        ext = ".tar.gz"
    if ext in ARCHIVE_EXTS:
        return "archive"
    if ext in TEXT_EXTS:
        return "text"
    if ext in DOC_EXTS:
        return "doc"
    if ext in PDF_EXTS:
        return "pdf"
    if ext in PPTX_EXTS:
        return "presentation"
    if ext in BOOK_EXTS:
        return "book"
    if ext == ".djvu":
        return "djvu"
    if ext in HTML_EXTS:
        return "html"
    if ext in IMAGE_EXTS:
        return "image"
    return "skip"


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

def process_dir(source: Path, output: Path, subject: str) -> dict:
    stats = {
        "files_scanned": 0, "archives": 0, "text": 0, "doc": 0,
        "pdf": 0, "pptx": 0, "book": 0, "djvu": 0, "html": 0,
        "image": 0, "skipped": 0, "errors": 0, "output_files": [],
        "total_words": 0,
    }
    img_dir = output / "_ocr_tmp"
    img_dir.mkdir(parents=True, exist_ok=True)

    for file_path in sorted(source.rglob("*")):
        if not file_path.is_file():
            continue

        # Skip hidden/system dirs
        skip = False
        for part in file_path.parts:
            if part in SKIP_DIRS:
                skip = True
                break
        if skip:
            continue

        stats["files_scanned"] += 1
        ftype = classify(file_path)
        rel = file_path.relative_to(source)

        if ftype == "skip" or file_path.suffix.lower() in SKIP_EXTS:
            stats["skipped"] += 1
            continue

        log.info("[%s] %s", ftype.upper(), rel)

        content = ""
        try:
            if ftype == "text":
                content = read_text(file_path)
                stats["text"] += 1

            elif ftype == "doc":
                content = extract_docx(file_path)
                stats["doc"] += 1

            elif ftype == "pdf":
                content, ocr_n = extract_pdf(file_path, img_dir)
                stats["pdf"] += 1

            elif ftype == "presentation":
                content, _ = extract_pptx(file_path, img_dir)
                stats["pptx"] += 1

            elif ftype == "book":
                ext = file_path.suffix.lower()
                if ext == ".fb2":
                    content = extract_fb2(file_path)
                else:
                    content = f"[Unsupported book format: {ext}]"
                stats["book"] += 1

            elif ftype == "djvu":
                content = extract_djvu(file_path)
                stats["djvu"] += 1

            elif ftype == "html":
                content = extract_html(file_path)
                stats["html"] += 1

            elif ftype == "image":
                content = ocr_image(file_path)
                stats["image"] += 1

            elif ftype == "archive":
                tmp = tempfile.mkdtemp(prefix="study-")
                files = extract_archive(file_path, Path(tmp))
                stats["archives"] += 1

                # Save extracted originals to output/extracted/
                extracted_dir = output / "extracted" / rel.stem
                extracted_dir.mkdir(parents=True, exist_ok=True)
                for ef in files:
                    if ef.is_file():
                        shutil.copy2(ef, extracted_dir / ef.name)

                # Process extracted files inline
                for ef in files:
                    ef_type = classify(ef)
                    if ef_type == "skip":
                        continue
                    ec = ""
                    if ef_type == "text":
                        ec = read_text(ef)
                    elif ef_type == "doc":
                        ec = extract_docx(ef)
                    elif ef_type == "pdf":
                        ec, _ = extract_pdf(ef, img_dir)
                    elif ef_type == "presentation":
                        ec, _ = extract_pptx(ef, img_dir)
                    elif ef_type == "book":
                        ec = extract_fb2(ef) if ef.suffix.lower() == ".fb2" else f"[{ef.suffix}]"
                    elif ef_type == "djvu":
                        ec = extract_djvu(ef)
                    elif ef_type == "html":
                        ec = extract_html(ef)
                    elif ef_type == "image":
                        ec = ocr_image(ef)
                    if ec.strip():
                        content += f"\n---\n### Файл: {ef.name}\n{ec}\n"
                shutil.rmtree(tmp, ignore_errors=True)

        except Exception as e:
            log.error("Error %s: %s", rel, e)
            stats["errors"] += 1
            content = f"[ERROR: {e}]"

        if not content.strip():
            continue

        # Save original file copy
        orig_dir = output / "originals" / rel.parent
        orig_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file_path, orig_dir / file_path.name)

        # Build output Markdown
        word_count = len(content.split())
        stats["total_words"] += word_count

        md = build_md(rel, content, subject, file_path, word_count)
        out_path = build_out_path(output, rel, file_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(md, encoding="utf-8")
        stats["output_files"].append(str(out_path.relative_to(output)))

    # Clean up OCR temp
    shutil.rmtree(img_dir, ignore_errors=True)
    return stats


def build_md(rel: Path, content: str, subject: str, orig: Path, wc: int) -> str:
    lines = [
        "---",
        f"title: \"{rel.stem.replace('_', ' ').strip()}\"",
        f"subject: \"{subject}\"",
        f"source_file: \"{rel.as_posix()}\"",
        f"processed_at: \"{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\"",
        f"original_hash: \"{hashlib.sha256(content.encode()).hexdigest()[:16]}\"",
        f"word_count: {wc}",
        "---",
        "",
        f"# {rel.stem.replace('_', ' ').strip()}",
        "",
        f"> Source: `{rel.as_posix()}`",
        "",
        "---",
        "",
        content,
        "",
    ]
    return "\n".join(lines)


def build_out_path(output: Path, rel: Path, orig: Path) -> Path:
    # Preserve directory structure, change extension to .md
    stem = rel.stem
    return output / rel.parent / (stem + ".md")


def write_index(output: Path, stats: dict, subject: str):
    index = {
        "subject": subject,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "files_scanned": stats["files_scanned"],
        "output_files": len(stats["output_files"]),
        "total_words": stats["total_words"],
        "statistics": {k: v for k, v in stats.items() if k != "output_files"},
        "entries": [],
    }
    for md_file in sorted(output.rglob("*.md")):
        if md_file.name == "README.md":
            continue
        text = md_file.read_text(encoding="utf-8", errors="replace")
        # Extract preview (after front matter)
        idx = text.find("---", text.find("---", 3) + 3)
        preview = ""
        if idx > 0:
            preview = text[idx + 3:].strip()[:300]
        index["entries"].append({
            "file": md_file.relative_to(output).as_posix(),
            "title": md_file.stem,
            "word_count": len(text.split()),
            "preview": preview.replace("\n", " "),
        })
    (output / "index.json").write_text(
        json.dumps(index, indent=2, ensure_ascii=False), encoding="utf-8")


def write_readme(output: Path, stats: dict, subject: str, source: Path):
    lines = [
        f"# {subject} — Study Materials (processed)",
        "",
        f"Source: `{source}`",
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        "## Summary",
        "",
        f"- Files scanned: {stats['files_scanned']}",
        f"- Archives extracted: {stats['archives']}",
        f"- Text files: {stats['text']}",
        f"- DOCX: {stats['doc']}",
        f"- PDF: {stats['pdf']}",
        f"- PPTX: {stats['pptx']}",
        f"- Books (FB2): {stats['book']}",
        f"- DJVU: {stats['djvu']}",
        f"- HTML: {stats['html']}",
        f"- Images OCR'd: {stats['image']}",
        f"- Output Markdown files: {len(stats['output_files'])}",
        f"- Total words: {stats['total_words']}",
        "",
        "## Output structure",
        "",
        "Each file preserves the original relative directory structure.",
        "All files have YAML front matter with subject, source, hash, and word count.",
        "",
        "## Usage",
        "",
        "- Load `.md` files into Claude / Codex / Gemini as context",
        "- Upload to ChatGPT as Knowledge files",
        "- Import into NotebookLM as sources",
        "- Use `index.json` for RAG pipeline ingestion",
        "",
    ]
    if stats["errors"]:
        lines.extend(["## Errors", "", f"- {stats['errors']} file(s) had extraction errors", ""])
    (output / "README.md").write_text("\n".join(lines), encoding="utf-8")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Prepare study materials for RAG indexing. "
                    "Recursively scans source, extracts all content, outputs structured Markdown.",
        epilog="""
Examples:
  python study-materials-prep.py --source "C:\\path\\to\\HR-менеджмент"
  python study-materials-prep.py --source "C:\\path\\to\\module3\\HR-менеджмент" --output "C:\\output"
        """,
    )
    parser.add_argument("--source", required=True,
                        help="Source directory with study materials")
    parser.add_argument("--output", default="",
                        help="Output directory (default: ./study-output/<subject>/)")
    parser.add_argument("--install-deps", action="store_true",
                        help="Auto-install missing dependencies before processing")
    args = parser.parse_args()

    source = Path(args.source).expanduser().resolve()
    if not source.is_dir():
        log.error("Source directory not found: %s", source)
        sys.exit(1)

    subject = source.name
    if args.output:
        output = Path(args.output).expanduser().resolve()
    else:
        output = Path.cwd() / "study-output" / subject

    warnings = check_deps()
    for w in warnings:
        log.warning(w)

    # Auto-install dependencies if requested or if critical deps missing
    if args.install_deps or any("MISSING:" in w for w in warnings[:2]):
        log.info("Installing missing dependencies...")
        script_dir = Path(__file__).parent
        install_script = script_dir / "install-deps.py"
        if install_script.exists():
            subprocess.run([sys.executable, str(install_script)], timeout=600)
            # Re-check after install
            warnings = check_deps()
            for w in warnings:
                log.warning(w)
        else:
            log.warning("install-deps.py not found — run manually: python scripts/install-deps.py")

    output.mkdir(parents=True, exist_ok=True)

    log.info("Subject: %s", subject)
    log.info("Source: %s", source)
    log.info("Output: %s", output)

    stats = process_dir(source, output, subject)
    write_index(output, stats, subject)
    write_readme(output, stats, subject, source)

    log.info("=" * 60)
    log.info("DONE — %s", subject)
    log.info("=" * 60)
    log.info("Files scanned:     %d", stats["files_scanned"])
    log.info("Archives:          %d", stats["archives"])
    log.info("Text files:        %d", stats["text"])
    log.info("DOCX:              %d", stats["doc"])
    log.info("PDF:               %d", stats["pdf"])
    log.info("PPTX:              %d", stats["pptx"])
    log.info("Books (FB2):       %d", stats["book"])
    log.info("DJVU:              %d", stats["djvu"])
    log.info("HTML:              %d", stats["html"])
    log.info("Images OCR'd:      %d", stats["image"])
    log.info("Output files:      %d", len(stats["output_files"]))
    log.info("Total words:       %d", stats["total_words"])
    log.info("Errors:            %d", stats["errors"])
    log.info("Output directory:  %s", output)


if __name__ == "__main__":
    main()
