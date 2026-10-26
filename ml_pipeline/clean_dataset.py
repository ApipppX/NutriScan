#!/usr/bin/env python3
"""Deduplicate a pre-split image dataset without modifying the source.

The dataset must be arranged as:

    input/
      train/<class>/*.jpg
      valid/<class>/*.jpg
      test/<class>/*.jpg

Near-duplicate detection uses a 64-bit difference hash (dHash). Images whose
hashes differ by at most ``--threshold`` bits are considered the same source
image. Groups are deduplicated globally, so an image cannot appear in both a
training and an evaluation split. Files that collide across different class
folders are excluded entirely because their labels are ambiguous.

One representative per group is kept, preferring train > test > valid, and the
clean dataset is linked into ``--output-dir``. Hard links are used by default
(same volume, no extra disk usage); use ``--mode copy`` when necessary.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence

from PIL import Image, ImageOps
import numpy as np

SPLITS = ("train", "valid", "test")
SPLIT_PRIORITY = {"train": 0, "test": 1, "valid": 2}
SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".jfif"}


@dataclass(frozen=True)
class ImageRecord:
    path: Path
    split: str
    label: str
    dhash: int
    width: int
    height: int
    size_bytes: int

    @property
    def pixels(self) -> int:
        return self.width * self.height


def _iter_class_dirs(root: Path) -> list[Path]:
    if not root.is_dir():
        raise FileNotFoundError(f"Split directory does not exist: {root}")
    return sorted(path for path in root.iterdir() if path.is_dir() and not path.name.startswith("."))


def _load_record(path: Path, split: str) -> ImageRecord:
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image)
        width, height = image.size
        grayscale = image.convert("L").resize((9, 8), Image.Resampling.LANCZOS)
    pixels = np.asarray(grayscale, dtype=np.int16)
    bits = (pixels[:, 1:] > pixels[:, :-1]).flatten()
    value = 0
    for bit in bits:
        value = (value << 1) | int(bit)
    return ImageRecord(
        path=path,
        split=split,
        label=path.parent.name,
        dhash=value,
        width=width,
        height=height,
        size_bytes=path.stat().st_size,
    )


def scan_dataset(input_dir: Path) -> list[ImageRecord]:
    jobs: list[tuple[Path, str]] = []
    for split in SPLITS:
        split_dir = input_dir / split
        for class_dir in _iter_class_dirs(split_dir):
            for path in sorted(class_dir.rglob("*")):
                if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS:
                    jobs.append((path, split))
    if not jobs:
        raise ValueError(f"No supported images found under {input_dir}")

    records: list[ImageRecord] = []
    failures: list[tuple[str, str]] = []
    with ThreadPoolExecutor(max_workers=min(12, os.cpu_count() or 4)) as pool:
        futures = {pool.submit(_load_record, path, split): path for path, split in jobs}
        for future in futures:
            path = futures[future]
            try:
                records.append(future.result())
            except Exception as exc:  # noqa: BLE001 - report all unreadable files
                failures.append((str(path), repr(exc)))
    if failures:
        details = "\n".join(f"  {path}: {error}" for path, error in failures[:20])
        raise ValueError(f"{len(failures)} image(s) could not be read:\n{details}")
    return records


def _distance(left: int, right: int) -> int:
    return (left ^ right).bit_count()


def build_groups(records: Sequence[ImageRecord], threshold: int) -> list[list[ImageRecord]]:
    """Union images whose hashes are within ``threshold`` bits, per class."""

    groups: list[list[ImageRecord]] = []
    by_label: dict[str, list[ImageRecord]] = defaultdict(list)
    for record in records:
        by_label[record.label].append(record)

    for label in sorted(by_label):
        rows = by_label[label]
        parent = list(range(len(rows)))

        def find(index: int) -> int:
            while parent[index] != index:
                parent[index] = parent[parent[index]]
                index = parent[index]
            return index

        for i, left in enumerate(rows):
            for j in range(i + 1, len(rows)):
                if _distance(left.dhash, rows[j].dhash) <= threshold:
                    root_i, root_j = find(i), find(j)
                    if root_i != root_j:
                        parent[root_j] = root_i

        grouped: dict[int, list[ImageRecord]] = defaultdict(list)
        for index, row in enumerate(rows):
            grouped[find(index)].append(row)
        groups.extend(grouped.values())

    # A near-identical image carrying a different label is almost certainly a
    # duplicate or a mislabel. Exclude both groups rather than teach the model
    # contradictory labels. Compare every cross-class pair once; the class
    # partition keeps this much smaller than an all-pairs comparison.
    group_index = {
        id(record): index for index, group in enumerate(groups) for record in group
    }
    by_label_records: dict[str, list[ImageRecord]] = defaultdict(list)
    for record in records:
        by_label_records[record.label].append(record)

    labels = sorted(by_label_records)
    excluded: set[int] = set()
    for left_index, left_label in enumerate(labels):
        for right_label in labels[left_index + 1 :]:
            for left in by_label_records[left_label]:
                for right in by_label_records[right_label]:
                    if _distance(left.dhash, right.dhash) <= threshold:
                        excluded.add(group_index[id(left)])
                        excluded.add(group_index[id(right)])

    return [group for index, group in enumerate(groups) if index not in excluded], len(excluded)


def _pick_representative(group: Sequence[ImageRecord]) -> ImageRecord:
    return min(
        group,
        key=lambda record: (
            SPLIT_PRIORITY[record.split],
            -record.pixels,
            -record.size_bytes,
            record.path.name,
        ),
    )


def _link_or_copy(source: Path, destination: Path, mode: str) -> str:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        destination.unlink()
    if mode == "copy":
        shutil.copy2(source, destination)
        return "copy"
    try:
        os.link(source, destination)
        return "hardlink"
    except OSError:
        shutil.copy2(source, destination)
        return "copy"


def prepare_clean_dataset(
    *,
    input_dir: Path,
    output_dir: Path,
    threshold: int,
    mode: str,
    dry_run: bool,
) -> dict[str, object]:
    records = scan_dataset(input_dir)
    groups, excluded_group_count = build_groups(records, threshold)
    representatives = [_pick_representative(group) for group in groups]
    action = "copy" if mode == "copy" else "hardlink"

    if not dry_run:
        if output_dir.exists() and any(output_dir.iterdir()):
            raise FileExistsError(
                f"Output directory already exists and is not empty: {output_dir}. "
                "Choose a new directory."
            )
        for record in representatives:
            relative = Path(record.split) / record.label / record.path.name
            _link_or_copy(record.path, output_dir / relative, mode)

    removed = len(records) - len(representatives)
    audit = {
        "inputDir": str(input_dir),
        "outputDir": str(output_dir),
        "dHashThreshold": threshold,
        "linkMode": action,
        "dryRun": dry_run,
        "imagesBefore": len(records),
        "imagesAfter": len(representatives),
        "removedDuplicates": removed,
        "excludedCrossClassGroups": excluded_group_count,
        "beforeBySplit": {
            split: sum(1 for record in records if record.split == split)
            for split in SPLITS
        },
        "afterBySplit": {
            split: sum(1 for record in representatives if record.split == split)
            for split in SPLITS
        },
        "afterByClass": {
            label: {
                split: sum(1 for record in representatives if record.label == label and record.split == split)
                for split in SPLITS
            }
            for label in sorted({record.label for record in records})
        },
    }
    if not dry_run:
        audit_path = output_dir / "dataset_audit.json"
        audit_path.write_text(json.dumps(audit, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return audit


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--threshold",
        type=int,
        default=4,
        help="Maximum dHash Hamming distance for near-duplicates (default: 4).",
    )
    parser.add_argument("--mode", choices=("hardlink", "copy"), default="hardlink")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    if not 0 <= args.threshold <= 16:
        print("[clean] ERROR: --threshold must be between 0 and 16.", file=sys.stderr)
        return 2
    try:
        audit = prepare_clean_dataset(
            input_dir=args.input_dir.resolve(),
            output_dir=args.output_dir.resolve(),
            threshold=args.threshold,
            mode=args.mode,
            dry_run=args.dry_run,
        )
    except (FileNotFoundError, FileExistsError, ValueError) as exc:
        print(f"[clean] ERROR: {exc}", file=sys.stderr)
        return 1

    print(f"[clean] Images: {audit['imagesBefore']} -> {audit['imagesAfter']}")
    print(f"[clean] Removed duplicates: {audit['removedDuplicates']}")
    print(f"[clean] Cross-class ambiguous groups excluded: {audit['excludedCrossClassGroups']}")
    print(f"[clean] Kept by split: {audit['afterBySplit']}")
    if not args.dry_run:
        print(f"[clean] Wrote {args.output_dir / 'dataset_audit.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
