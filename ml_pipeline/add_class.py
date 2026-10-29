#!/usr/bin/env python3
"""Add a new class to a pre-split dataset from a folder of images.

The input dataset is never modified. Its ``train``, ``valid``, and ``test``
files are copied (or hard-linked) to a new output directory with their relative
paths unchanged. The new class is split deterministically into train/valid/test
using ``--val-split`` and ``--test-split``.

Every source image is checked with a 64-bit dHash against all existing images
and all accepted additions. Images within ``--threshold`` bits of an existing
image or another addition are skipped, so the new class cannot introduce
near-duplicate leakage into the held-out splits.

Example:
    python ml_pipeline/add_class.py
        --data-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley"
        --source-dir "D:/Dataset Makanan 1GB/external/mendeley/curated_bakso/Bakso"
        --class-name "Bakso"
        --output-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley_bakso"
        --val-split 0.1
        --test-split 0.1
        --threshold 4
        --mode hardlink
        --source-name "Mendeley Indonesian Food Image"
        --source-url "https://data.mendeley.com/datasets/vtjd68bmwt"
        --license "CC BY 4.0"
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import sys
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Sequence

from clean_dataset import (
    SPLITS,
    SUPPORTED_IMAGE_EXTENSIONS,
    ImageRecord,
    _distance,
    _load_record,
)


@dataclass(frozen=True)
class SourceCandidate:
    path: Path
    record: ImageRecord


def normalize_label(value: str) -> str:
    """Normalize a label the same way nutrition labels are normalized."""

    return re.sub(r"[^a-z0-9]+", "_", value.casefold()).strip("_")


def iter_class_dirs(root: Path) -> list[Path]:
    if not root.is_dir():
        raise FileNotFoundError(f"Class directory does not exist: {root}")
    return sorted(path for path in root.iterdir() if path.is_dir() and not path.name.startswith("."))


def image_paths(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS:
            yield path


def scan_existing(data_dir: Path) -> tuple[list[ImageRecord], dict[str, set[str]]]:
    records: list[ImageRecord] = []
    labels_by_split: dict[str, set[str]] = {}

    for split in SPLITS:
        split_dir = data_dir / split
        class_dirs = iter_class_dirs(split_dir)
        labels_by_split[split] = {path.name for path in class_dirs}
        for class_dir in class_dirs:
            for path in image_paths(class_dir):
                records.append(_load_record(path, split))

    if not records:
        raise ValueError(f"No supported images found in {data_dir}")

    expected = labels_by_split["train"]
    for split in ("valid", "test"):
        if labels_by_split[split] != expected:
            raise ValueError(
                f"Class folders differ between train and {split}: "
                f"train={sorted(expected)}, {split}={sorted(labels_by_split[split])}"
            )

    return records, labels_by_split


def read_excludes(path: Path | None) -> set[str]:
    if path is None:
        return set()
    if not path.is_file():
        raise FileNotFoundError(f"Exclude file does not exist: {path}")
    names: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        value = line.strip()
        if not value or value.startswith("#"):
            continue
        names.add(Path(value).stem.casefold())
    return names


def scan_source(
    source_dir: Path,
    *,
    excludes: set[str],
) -> tuple[list[SourceCandidate], list[str], list[dict[str, str]]]:
    paths = list(image_paths(source_dir))
    if not paths:
        raise ValueError(f"No supported images found in {source_dir}")

    jobs: list[Path] = []
    excluded: list[str] = []
    for path in paths:
        if path.stem.casefold() in excludes:
            excluded.append(str(path))
            continue
        jobs.append(path)

    candidates: list[SourceCandidate] = []
    failures: list[dict[str, str]] = []
    with ThreadPoolExecutor(max_workers=min(12, os.cpu_count() or 4)) as pool:
        futures = {pool.submit(_load_record, path, "source"): path for path in jobs}
        for future in as_completed(futures):
            path = futures[future]
            try:
                record = future.result()
            except Exception as exc:  # noqa: BLE001 - report and skip unreadable source files
                failures.append({"path": str(path), "error": repr(exc)})
                continue
            candidates.append(SourceCandidate(path=path, record=record))

    return candidates, excluded, failures


def select_unique(
    existing: Sequence[ImageRecord],
    candidates: Sequence[SourceCandidate],
    *,
    class_name: str,
    threshold: int,
    seed: int,
    max_per_class: int,
) -> tuple[list[SourceCandidate], dict[str, object]]:
    ordered = list(candidates)
    random.Random(seed).shuffle(ordered)

    existing_records = list(existing)
    accepted: list[SourceCandidate] = []
    skipped: list[dict[str, object]] = []

    def first_match(dhash: int, records: Sequence[ImageRecord]) -> ImageRecord | None:
        for record in records:
            if _distance(dhash, record.dhash) <= threshold:
                return record
        return None

    def first_candidate_match(dhash: int) -> SourceCandidate | None:
        for candidate in accepted:
            if _distance(dhash, candidate.record.dhash) <= threshold:
                return candidate
        return None

    for candidate in ordered:
        existing_match = first_match(candidate.record.dhash, existing_records)
        if existing_match is not None:
            reason = "existing_same_class" if existing_match.label == class_name else "existing_other_class"
            skipped.append(
                {
                    "source": str(candidate.path),
                    "reason": reason,
                    "matched": str(existing_match.path),
                    "matchedLabel": existing_match.label,
                    "distance": _distance(candidate.record.dhash, existing_match.dhash),
                }
            )
            continue

        candidate_match = first_candidate_match(candidate.record.dhash)
        if candidate_match is not None:
            skipped.append(
                {
                    "source": str(candidate.path),
                    "reason": "source_duplicate",
                    "matched": str(candidate_match.path),
                    "distance": _distance(candidate.record.dhash, candidate_match.record.dhash),
                }
            )
            continue

        if max_per_class and len(accepted) >= max_per_class:
            skipped.append(
                {
                    "source": str(candidate.path),
                    "reason": "max_per_class",
                }
            )
            continue

        accepted.append(candidate)

    report = {
        "accepted": len(accepted),
        "skipped": skipped,
        "skippedCounts": dict(sorted(Counter(item["reason"] for item in skipped).items())),
    }
    return accepted, report


def split_candidates(
    candidates: Sequence[SourceCandidate],
    *,
    val_split: float,
    test_split: float,
    seed: int,
) -> dict[str, list[SourceCandidate]]:
    ordered = list(candidates)
    random.Random(seed + 1).shuffle(ordered)

    total = len(ordered)
    test_count = max(1, round(total * test_split))
    val_count = max(1, round(total * val_split))
    if total < 3:
        raise ValueError("At least 3 images are required for train/valid/test splits.")
    if test_count + val_count >= total:
        raise ValueError(
            f"Not enough images for splits: total={total}, valid={val_count}, test={test_count}"
        )

    return {
        "test": ordered[:test_count],
        "valid": ordered[test_count : test_count + val_count],
        "train": ordered[test_count + val_count :],
    }


def copy_or_link(source: Path, destination: Path, mode: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if mode == "copy":
        import shutil

        shutil.copy2(source, destination)
        return
    try:
        os.link(source, destination)
    except OSError:
        import shutil

        shutil.copy2(source, destination)


def copy_existing(data_dir: Path, output_dir: Path, mode: str) -> int:
    jobs: list[tuple[Path, Path]] = []
    for split in SPLITS:
        for class_dir in iter_class_dirs(data_dir / split):
            for source in image_paths(class_dir):
                destination = output_dir / split / class_dir.name / source.name
                jobs.append((source, destination))

    with ThreadPoolExecutor(max_workers=min(12, os.cpu_count() or 4)) as pool:
        futures = [pool.submit(copy_or_link, source, destination, mode) for source, destination in jobs]
        for future in futures:
            future.result()
    return len(jobs)


def verify_existing_copy(
    data_dir: Path,
    output_dir: Path,
    *,
    existing_labels: dict[str, set[str]],
) -> dict[str, object]:
    verification: dict[str, object] = {}
    for split in SPLITS:
        source_set: set[Path] = set()
        output_set: set[Path] = set()
        for class_dir in iter_class_dirs(data_dir / split):
            for path in image_paths(class_dir):
                source_set.add(path.relative_to(data_dir / split))
        for label in existing_labels[split]:
            for path in image_paths(output_dir / split / label):
                output_set.add(path.relative_to(output_dir / split))
        if source_set != output_set:
            missing = sorted(str(path) for path in source_set - output_set)
            extra = sorted(str(path) for path in output_set - source_set)
            raise RuntimeError(
                f"Copy verification failed for {split}: missing={missing[:10]}, extra={extra[:10]}"
            )
        verification[split] = {"images": len(output_set), "unchanged": True}
    return verification


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--data-dir", type=Path, required=True, help="Existing train/valid/test dataset.")
    parser.add_argument("--source-dir", type=Path, required=True, help="Folder containing the new class images.")
    parser.add_argument("--class-name", required=True, help="Label for the new class (e.g. Bakso).")
    parser.add_argument("--output-dir", type=Path, required=True, help="New dataset directory.")
    parser.add_argument("--val-split", type=float, default=0.1, help="Fraction of new images for validation (default: 0.1).")
    parser.add_argument("--test-split", type=float, default=0.1, help="Fraction of new images for test (default: 0.1).")
    parser.add_argument("--seed", type=int, default=42, help="Split/shuffle seed (default: 42).")
    parser.add_argument("--threshold", type=int, default=4, help="dHash distance threshold (default: 4).")
    parser.add_argument("--max-per-class", type=int, default=0, help="Maximum new images to accept; 0 means unlimited.")
    parser.add_argument("--mode", choices=("copy", "hardlink"), default="hardlink", help="How to copy existing files.")
    parser.add_argument("--prefix", default="external", help="Filename prefix for added images.")
    parser.add_argument("--exclude-file", type=Path, default=None, help="Optional file with one image stem per line to skip.")
    parser.add_argument("--source-name", default="", help="Dataset name for the report.")
    parser.add_argument("--source-url", default="", help="Dataset URL for the report.")
    parser.add_argument("--license", dest="license_name", default="", help="Dataset license for the report.")
    parser.add_argument("--dry-run", action="store_true", help="Report what would be added without writing.")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    data_dir = args.data_dir.resolve()
    source_dir = args.source_dir.resolve()
    output_dir = args.output_dir.resolve()
    class_name = args.class_name.strip()

    if not class_name:
        print("[add-class] ERROR: --class-name must not be empty.", file=sys.stderr)
        return 2
    if not 0 < args.val_split < 1 or not 0 < args.test_split < 1:
        print("[add-class] ERROR: --val-split and --test-split must be between 0 and 1.", file=sys.stderr)
        return 2
    if args.val_split + args.test_split >= 1:
        print("[add-class] ERROR: --val-split + --test-split must be < 1.", file=sys.stderr)
        return 2
    if not 0 <= args.threshold <= 16:
        print("[add-class] ERROR: --threshold must be between 0 and 16.", file=sys.stderr)
        return 2
    if args.max_per_class < 0:
        print("[add-class] ERROR: --max-per-class must be >= 0.", file=sys.stderr)
        return 2
    if output_dir == data_dir or output_dir == source_dir:
        print("[add-class] ERROR: --output-dir must differ from input/source.", file=sys.stderr)
        return 2
    if output_dir.exists() and any(output_dir.iterdir()):
        print(f"[add-class] ERROR: output directory is not empty: {output_dir}", file=sys.stderr)
        return 2

    try:
        existing, existing_labels = scan_existing(data_dir)
        if class_name in existing_labels["train"]:
            raise ValueError(f"Class '{class_name}' already exists in {data_dir}")
        excludes = read_excludes(args.exclude_file)
        candidates, excluded, failures = scan_source(source_dir, excludes=excludes)
    except (FileNotFoundError, ValueError) as exc:
        print(f"[add-class] ERROR: {exc}", file=sys.stderr)
        return 1

    accepted, selection_report = select_unique(
        existing,
        candidates,
        class_name=class_name,
        threshold=args.threshold,
        seed=args.seed,
        max_per_class=args.max_per_class,
    )
    if not accepted:
        print("[add-class] ERROR: no usable source images remain.", file=sys.stderr)
        return 1
    try:
        split_map = split_candidates(
            accepted,
            val_split=args.val_split,
            test_split=args.test_split,
            seed=args.seed,
        )
    except ValueError as exc:
        print(f"[add-class] ERROR: {exc}", file=sys.stderr)
        return 1

    existing_by_split = Counter(record.split for record in existing)
    existing_by_class = Counter(record.label for record in existing)
    print(f"[add-class] Existing: {len(existing)} images ({dict(sorted(existing_by_split.items()))})")
    print(f"[add-class] Source: {len(candidates)} readable images, {len(excluded)} excluded by name")
    if failures:
        print(f"[add-class] Skipped unreadable source images: {len(failures)}")
    print(f"[add-class] Accepted: {len(accepted)}")
    print(f"[add-class] Skipped: {selection_report['skippedCounts']}")
    print(
        "[add-class] New class split: "
        f"{len(split_map['train'])} train / {len(split_map['valid'])} valid / "
        f"{len(split_map['test'])} test"
    )

    if args.dry_run:
        print("[add-class] Dry run: no files written.")
        return 0

    output_dir.mkdir(parents=True, exist_ok=True)
    try:
        copied = copy_existing(data_dir, output_dir, args.mode)
        verification = verify_existing_copy(
            data_dir,
            output_dir,
            existing_labels=existing_labels,
        )
        print(f"[add-class] Copied existing images: {copied}; existing splits verified unchanged.")

        slug = normalize_label(class_name)
        manifest: list[dict[str, object]] = []
        split_counts: Counter[str] = Counter()
        for split in SPLITS:
            for candidate in split_map[split]:
                digest = hashlib.sha1(candidate.path.read_bytes()).hexdigest()[:12]
                destination = (
                    output_dir
                    / split
                    / class_name
                    / f"{args.prefix}_{slug}_{digest}{candidate.path.suffix.lower()}"
                )
                suffix_index = 2
                while destination.exists():
                    destination = (
                        output_dir
                        / split
                        / class_name
                        / f"{args.prefix}_{slug}_{digest}_{suffix_index}{candidate.path.suffix.lower()}"
                    )
                    suffix_index += 1
                copy_or_link(candidate.path, destination, "copy")
                split_counts[split] += 1
                manifest.append(
                    {
                        "source": str(candidate.path),
                        "split": split,
                        "output": str(destination.relative_to(output_dir)),
                        "width": candidate.record.width,
                        "height": candidate.record.height,
                        "bytes": candidate.record.size_bytes,
                    }
                )

        output_by_split = {
            split: len(list(image_paths(output_dir / split))) for split in SPLITS
        }
        if output_by_split["valid"] != existing_by_split["valid"] + split_counts["valid"]:
            raise RuntimeError("Validation split count changed unexpectedly.")
        if output_by_split["test"] != existing_by_split["test"] + split_counts["test"]:
            raise RuntimeError("Test split count changed unexpectedly.")

        report = {
            "schemaVersion": 1,
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "source": {
                "name": args.source_name,
                "url": args.source_url,
                "license": args.license_name,
                "directory": str(source_dir),
                "prefix": args.prefix,
            },
            "inputDataset": str(data_dir),
            "outputDataset": str(output_dir),
            "newClass": class_name,
            "settings": {
                "valSplit": args.val_split,
                "testSplit": args.test_split,
                "seed": args.seed,
                "threshold": args.threshold,
                "maxPerClass": args.max_per_class,
                "mode": args.mode,
            },
            "existing": {
                "total": len(existing),
                "bySplit": dict(sorted(existing_by_split.items())),
                "byClass": dict(sorted(existing_by_class.items())),
                "verification": verification,
            },
            "sourceImages": {
                "readable": len(candidates),
                "excludedByName": excluded,
                "unreadable": failures,
                "accepted": len(accepted),
                **selection_report,
            },
            "newClassSplit": {split: len(split_map[split]) for split in SPLITS},
            "output": {
                "bySplit": output_by_split,
                "newClassBySplit": {split: split_counts[split] for split in SPLITS},
            },
        }
        write_json(output_dir / "add_class_report.json", report)
        write_json(output_dir / "add_class_manifest.json", manifest)
        print(f"[add-class] Output dataset: {output_dir}")
        print(f"[add-class] Report: {output_dir / 'add_class_report.json'}")
        print(f"[add-class] Manifest: {output_dir / 'add_class_manifest.json'}")
        print(f"[add-class] Final split counts: {output_by_split}")
        return 0
    except Exception as exc:  # noqa: BLE001 - keep a clear failure message
        print(f"[add-class] ERROR after output creation: {exc}", file=sys.stderr)
        print(f"[add-class] Partial output left at {output_dir}; delete it before retrying.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
