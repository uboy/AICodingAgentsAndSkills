#!/usr/bin/env python3
"""
install-deps.py — Auto-install dependencies for study-materials-prep.

Detects OS and package manager, installs:
- System: tesseract-ocr, 7zip, djvulibre
- Python: PyMuPDF, python-docx, python-pptx, Pillow, pytesseract

Usage:
    python install-deps.py
    python install-deps.py --dry-run
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys


def run_cmd(cmd, desc="", dry_run=False):
    """Run a command, return success bool."""
    if dry_run:
        print(f"  [DRY] {desc}: {' '.join(cmd)}")
        return True
    print(f"  [*] {desc}...")
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if r.returncode == 0:
            print(f"  [+] OK")
            return True
        else:
            print(f"  [-] Failed: {r.stderr.strip()[:200]}")
            return False
    except Exception as e:
        print(f"  [-] Error: {e}")
        return False


def is_installed(name):
    """Check if a command is available."""
    return shutil.which(name) is not None


def pip_install(pkg, dry_run=False):
    """Install a Python package."""
    # Check if already installed
    mod_name = pkg.replace("-", "").replace("_", "")
    pkg_check = pkg.split("[")[0]  # strip extras
    try:
        __import__(pkg_check.replace("-", "_").split("[")[0])
        return True
    except ImportError:
        pass
    return run_cmd(
        [sys.executable, "-m", "pip", "install", "-q", pkg],
        f"pip install {pkg}", dry_run
    )


def install_windows(dry_run=False):
    """Install deps on Windows using winget or choco."""
    ok = True

    # Python packages first (fastest)
    for pkg in ["fitz", "python-docx", "python-pptx", "Pillow", "pytesseract"]:
        pip_name = {
            "fitz": "PyMuPDF",
            "python-docx": "python-docx",
            "python-pptx": "python-pptx",
            "Pillow": "Pillow",
            "pytesseract": "pytesseract",
        }[pkg]
        try:
            if pkg == "fitz":
                import fitz
            elif pkg == "Pillow":
                from PIL import Image
            else:
                __import__(pkg.replace("-", "_"))
            print(f"  [OK] {pip_name} already installed")
        except ImportError:
            if not pip_install(pip_name, dry_run):
                ok = False

    # System packages
    if not is_installed("tesseract"):
        # Try winget first, then choco
        if is_installed("winget"):
            if not run_cmd(
                ["winget", "install", "--id", "UB-Mannheim.TesseractOCR", "-e", "--silent"],
                "tesseract-ocr via winget", dry_run
            ):
                ok = False
        elif is_installed("choco"):
            if not run_cmd(
                ["choco", "install", "tesseract", "-y"],
                "tesseract-ocr via choco", dry_run
            ):
                ok = False
        else:
            print("  [!] Install tesseract manually: https://github.com/UB-Mannheim/tesseract/wiki")
            ok = False
    else:
        print("  [OK] tesseract already installed")

    if not is_installed("7z") and not is_installed("7z.exe"):
        if is_installed("winget"):
            if not run_cmd(
                ["winget", "install", "--id", "7zip.7zip", "-e", "--silent"],
                "7-Zip via winget", dry_run
            ):
                ok = False
        elif is_installed("choco"):
            if not run_cmd(
                ["choco", "install", "7zip", "-y"],
                "7-Zip via choco", dry_run
            ):
                ok = False
        else:
            print("  [!] Install 7-Zip manually: https://www.7-zip.org/")
            ok = False
    else:
        print("  [OK] 7-Zip already installed")

    # djvulibre — no easy Windows package, skip
    if not is_installed("djvutxt"):
        print("  [!] djvulibre: no easy Windows install — DJVU support unavailable")

    return ok


def install_linux(dry_run=False):
    """Install deps on Linux using apt/dnf/pacman."""
    ok = True

    # Detect package manager
    pm = None
    install_cmd = []
    for name, cmd in [
        ("apt", ["apt-get", "install", "-y"]),
        ("dnf", ["dnf", "install", "-y"]),
        ("pacman", ["pacman", "-S", "--noconfirm"]),
    ]:
        if is_installed(name):
            pm = name
            install_cmd = cmd
            break

    if not pm:
        print("  [!] No supported package manager found (apt/dnf/pacman)")
        return False

    # System packages
    sys_pkgs = ["tesseract-ocr", "tesseract-ocr-rus", "tesseract-ocr-eng", "p7zip-full"]
    # djvulibre
    if pm == "apt":
        sys_pkgs.append("djvulibre-bin")
    elif pm == "dnf":
        sys_pkgs.append("djvulibre")

    if not run_cmd(
        ["sudo"] + install_cmd + sys_pkgs,
        f"system packages ({pm})", dry_run
    ):
        ok = False

    # Python packages (may need sudo or --user)
    for pkg in ["PyMuPDF", "python-docx", "python-pptx", "Pillow", "pytesseract"]:
        pip_install(pkg, dry_run)

    return ok


def install_macos(dry_run=False):
    """Install deps on macOS using brew."""
    ok = True

    if not is_installed("brew"):
        print("  [!] Homebrew not found. Install: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
        return False

    # System packages
    for pkg in ["tesseract", "tesseract-lang", "p7zip", "djvulibre"]:
        if not run_cmd(
            ["brew", "install", pkg],
            f"brew install {pkg}", dry_run
        ):
            ok = False

    # Python packages
    for pkg in ["PyMuPDF", "python-docx", "python-pptx", "Pillow", "pytesseract"]:
        pip_install(pkg, dry_run)

    return ok


def main():
    parser = argparse.ArgumentParser(description="Auto-install dependencies for study-materials-prep.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be installed")
    args = parser.parse_args()

    system = platform.system()
    print(f"Detected: {system} ({platform.machine()})")
    print(f"Python: {sys.executable} ({platform.python_version()})")
    print()

    if system == "Windows":
        ok = install_windows(args.dry_run)
    elif system == "Linux":
        ok = install_linux(args.dry_run)
    elif system == "Darwin":
        ok = install_macos(args.dry_run)
    else:
        print(f"[!] Unsupported OS: {system}")
        sys.exit(1)

    print()
    if ok:
        print("[+] All dependencies installed (or already present)")
        print("[*] Re-run study-materials-prep.py to process materials")
    else:
        print("[-] Some dependencies could not be installed")
        print("[*] Install missing items manually, then re-run")
        sys.exit(1)


if __name__ == "__main__":
    main()
