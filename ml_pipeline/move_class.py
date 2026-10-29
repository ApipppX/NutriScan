#!/usr/bin/env python3
"""Move all images from one class folder to another within a dataset.

This script moves image files from a source class directory to a destination
class directory. The destination directory is created if it does not exist.

Usage:
    python move_class.py --source-dir dataset/raw --source-class mie_goreng \
                          --dest-class olahan_mie

If --source-dir is omitted, the script looks for the source class in the
current working directory.
"""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path
from typing import Iterable

SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".jfif"}


def image_paths(root: Path) -> Iterable[Path]:
    """Yield all supported image files under ``root``."""
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS:
            yield path


def move_class(
    *,
    source_dir: Path,
    source_class: str,
    dest_dir: Path,
    dest_class: str,
    dry_run: bool = False,
) -> dict[str, object]:
    """Move images from source_class to dest_class.

    Args:
        source_dir: Root directory containing the source class folder.
        source_class: Name of the source class folder.
        dest_dir: Root directory where the destination class folder will be created.
        dest_class: Name of the destination class folder.
        dry_run: If True, only report what would be moved without moving.

    Returns:
        A dictionary with move statistics.
    """
    source_class_path = source_dir / source_class
    dest_class_path = dest_dir / dest_class

    if not source_class_path.is_dir():
        raise FileNotFoundError(f"Source class directory not found: {source_class_path}")

    if not dry_run:
        dest_class_path.mkdir(parents=True, exist_ok=True)

    moved: list[Path] = []
    skipped: list[tuple[Path, str]] = []

    for src_path in image_paths(source_class_path):
        dest_path = dest_class_path / src_path.name
        if dest_path.exists():
            skipped.append((src_path, f"Destination already exists: {dest_path.name}"))
            continue
        if not dry_run:
            try:
                shutil.move(str(src_path), str(dest_path))
                moved.append(dest_path)
            except OSError as exc:
                skipped.append((src_path, f"Move failed: {exc}"))
        else:
            moved.append(dest_path)

    # Remove empty source class directory if no images remain
    if not dry_run:
        try:
            if source_class_path.is_dir() and not any(source_class_path.iterdir()):
                source_class_path.rmdir()
        except OSError:
            pass  # Directory not empty or permission error; ignore

    return {
        "source_class": source_class,
        "dest_class": dest_class,
        "moved_count": len(moved),
        "skipped_count": len(skipped),
        "moved_files": [str(p) for p in moved],
        "skipped_files": [{"source": str(p), "reason": r} for p, r in skipped],
    }


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=Path.cwd(),
        help="Root directory containing the source class folder (default: current directory).",
    )
    parser.add_argument("--source-class", required=True, help="Name of the source class folder (e.g., mie_goreng).")
    parser.add_argument(
        "--dest-dir",
        type=Path,
        default=None,
        help="Root directory for the destination class folder (default: same as --source-dir).",
    )
    parser.add_argument("--dest-class", required=True, help="Name of the destination class folder (e.g., olahan_mie).")
    parser.add_argument("--dry-run", action="store_true", help="Report what would be moved without making changes.")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)

    source_dir = args.source_dir.resolve()
    dest_dir = args.dest_dir.resolve() if args.dest_dir else source_dir

    if args.source_class == args.dest_class and source_dir == dest_dir:
        print("[move] ERROR: Source and destination class must differ.", file=sys.stderr)
        return 2

    try:
        result = move_class(
            source_dir=source_dir,
            source_class=args.source_class,
            dest_dir=dest_dir,
            dest_class=args.dest_class,
            dry_run=args.dry_run,
        )
    except FileNotFoundError as exc:
        print(f"[move] ERROR: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"[move] ERROR: {exc}", file=sys.stderr)
        return 1

    if args.dry_run:
        print(f"[move] DRY RUN: Would move {result['moved_count']} image(s) from '{args.source_class}' to '{args.dest_class}'")
    else:
        print(f"[move] Successfully moved {result['moved_count']} image(s) from '{args.source_class}' to '{args.dest_class}'")

    if result["skipped_count"]:
        print(f"[move] Skipped {result['skipped_count']} file(s):")
        for item in result["skipped_files"]:
            print(f"  - {item['source']}: {item['reason']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())