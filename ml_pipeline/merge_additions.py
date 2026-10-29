#!/usr/bin/env python3
"""Merge external folder-per-class images into a pre-split dataset safely.

The input dataset is never modified. Its ``train``, ``valid``, and ``test``
files are copied (or hard-linked) to a new output directory with their relative
paths unchanged. External images are matched to existing classes by normalized
folder name and are added to ``train`` only.

Every candidate is checked with a 64-bit dHash against all existing images and
all accepted additions, regardless of class. Images within ``--threshold`` bits
of an existing/accepted image are skipped, so a new training image cannot be a
near-duplicate of the held-out test/validation split. The test split is never
extended or rewritten.

Example:
    python ml_pipeline/merge_additions.py
        --data-dir "D:/Dataset Makanan 1GB/dataset_clean"
        --source-dir "D:/Dataset Makanan 1GB/external/mendeley/Indonesian Food Image/Original"
        --output-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley"
        --prefix mendeley
        --source-name "Mendeley Indonesian Food Image"
        --source-url "https://data.mendeley.com/datasets/vtjd68bmwt"
        --license "CC BY 4.0"
        --max-per-class 200
        --threshold 4
        --mode copy
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Sequence

from clean_dataset import (
    SUPPORTED_IMAGE_EXTENSIONS,
    SPLITS,
    ImageRecord,
    _distance,
    _load_record,
)


@dataclass(frozen=True)
class SourceCandidate:
    path: Path
    target_label: str
    source_label: str
    record: ImageRecord


def normalize_label(value: str) -> str:
    """Normalize a folder name the same way nutrition labels are normalized."""

    return re.sub(r"[^a-z0-9]+", "_", value.casefold()).strip("_")


def iter_class_dirs(root: Path) -> list[Path]:
    if not root.is_dir():
        raise FileNotFoundError(f"Class directory does not exist: {root}")
    return sorted(path for path in root.iterdir() if path.is_dir() and not path.name.startswith("."))


def image_paths(root: Path) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS:
            yield path


def scan_existing(data_dir: Path) -> tuple[list[ImageRecord], set[str]]:
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

    return records, expected


def scan_source(
    source_dir: Path,
    existing_labels: set[str],
    *,
    include_normalized: set[str],
) -> tuple[list[SourceCandidate], dict[str, list[str]], list[dict[str, str]]]:
    source_dirs = iter_class_dirs(source_dir)
    by_normalized: dict[str, list[Path]] = defaultdict(list)
    for class_dir in source_dirs:
        by_normalized[normalize_label(class_dir.name)].append(class_dir)

    matched: dict[str, Path] = {}
    ignored: dict[str, list[str]] = {}
    for normalized, paths in sorted(by_normalized.items()):
        if len(paths) > 1:
            raise ValueError(
                "Multiple source folders normalize to the same class: "
                + ", ".join(str(path) for path in paths)
            )
        target = next((label for label in existing_labels if normalize_label(label) == normalized), None)
        if target is None or (include_normalized and normalized not in include_normalized):
            ignored[normalized] = [str(path) for path in paths]
            continue
        matched[target] = paths[0]

    missing_requested = sorted(include_normalized - {normalize_label(label) for label in matched})
    if missing_requested:
        raise ValueError(
            "Requested classes were not found in the source or the existing dataset: "
            + ", ".join(missing_requested)
        )

    jobs: list[tuple[Path, str, str]] = []
    for target, class_dir in sorted(matched.items()):
        for path in image_paths(class_dir):
            jobs.append((path, target, class_dir.name))

    candidates: list[SourceCandidate] = []
    failures: list[dict[str, str]] = []
    with ThreadPoolExecutor(max_workers=min(12, os.cpu_count() or 4)) as pool:
        futures = {
            pool.submit(_load_record, path, "source"): (path, target, source_label)
            for path, target, source_label in jobs
        }
        for future in as_completed(futures):
            path, target, source_label = futures[future]
            try:
                record = future.result()
            except Exception as exc:  # noqa: BLE001 - report and skip unreadable source files
                failures.append({"path": str(path), "error": repr(exc)})
                continue
            candidates.append(
                SourceCandidate(
                    path=path,
                    target_label=target,
                    source_label=source_label,
                    record=record,
                )
            )

    if not candidates:
        details = "\n".join(f"  {item['path']}: {item['error']}" for item in failures[:10])
        raise ValueError(f"No readable source images found in {source_dir}\n{details}")
    return candidates, ignored, failures


def quality_key(candidate: SourceCandidate) -> tuple[int, int, str]:
    return (
        -candidate.record.pixels,
        -candidate.record.size_bytes,
        candidate.path.name,
    )


def select_additions(
    existing: Sequence[ImageRecord],
    candidates: Sequence[SourceCandidate],
    *,
    threshold: int,
    max_per_class: int,
) -> tuple[list[SourceCandidate], dict[str, object]]:
    existing_records = list(existing)
    accepted: list[SourceCandidate] = []
    accepted_counts: Counter[str] = Counter()
    skipped: Counter[str] = Counter()
    skipped_details: dict[str, list[dict[str, object]]] = defaultdict(list)
    available_unique: Counter[str] = Counter()
    capped: Counter[str] = Counter()
    unique_seen: list[SourceCandidate] = []

    by_label: dict[str, list[SourceCandidate]] = defaultdict(list)
    for candidate in candidates:
        by_label[candidate.target_label].append(candidate)

    def first_match(
        dhash: int,
        records: Sequence[ImageRecord],
    ) -> ImageRecord | None:
        for record in records:
            if _distance(dhash, record.dhash) <= threshold:
                return record
        return None

    def first_unique_match(dhash: int) -> SourceCandidate | None:
        for candidate in unique_seen:
            if _distance(dhash, candidate.record.dhash) <= threshold:
                return candidate
        return None

    for label in sorted(by_label):
        ordered = sorted(by_label[label], key=quality_key)
        for candidate in ordered:
            existing_match = first_match(candidate.record.dhash, existing_records)
            if existing_match is not None:
                reason = (
                    "existing_same_class"
                    if existing_match.label == label
                    else "existing_other_class"
                )
                skipped[reason] += 1
                skipped_details[reason].append(
                    {
                        "source": str(candidate.path),
                        "target": label,
                        "matched": str(existing_match.path),
                        "matchedLabel": existing_match.label,
                    }
                )
                continue

            unique_match = first_unique_match(candidate.record.dhash)
            if unique_match is not None:
                reason = (
                    "source_same_class"
                    if unique_match.target_label == label
                    else "source_other_class"
                )
                skipped[reason] += 1
                skipped_details[reason].append(
                    {
                        "source": str(candidate.path),
                        "target": label,
                        "matched": str(unique_match.path),
                        "matchedLabel": unique_match.target_label,
                    }
                )
                continue

            unique_seen.append(candidate)
            available_unique[label] += 1
            if max_per_class and accepted_counts[label] >= max_per_class:
                capped[label] += 1
                continue
            accepted.append(candidate)
            accepted_counts[label] += 1

    report = {
        "availableUniqueByClass": dict(sorted(available_unique.items())),
        "selectedByClass": dict(sorted(accepted_counts.items())),
        "cappedByClass": dict(sorted((label, count) for label, count in capped.items() if count)),
        "skippedCounts": dict(sorted(skipped.items())),
        "skipped": dict(sorted(skipped_details.items())),
    }
    return accepted, report


def copy_or_link(source: Path, destination: Path, mode: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if mode == "copy":
        shutil.copy2(source, destination)
        return
    try:
        os.link(source, destination)
    except OSError:
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


def relative_image_set(root: Path, split: str) -> set[Path]:
    result: set[Path] = set()
    split_dir = root / split
    for class_dir in iter_class_dirs(split_dir):
        for path in image_paths(class_dir):
            result.add(path.relative_to(split_dir))
    return result


def verify_existing_copy(data_dir: Path, output_dir: Path) -> dict[str, object]:
    verification: dict[str, object] = {}
    for split in SPLITS:
        source_set = relative_image_set(data_dir, split)
        output_set = relative_image_set(output_dir, split)
        if source_set != output_set:
            missing = sorted(str(path) for path in source_set - output_set)
            extra = sorted(str(path) for path in output_set - source_set)
            raise RuntimeError(
                f"Copy verification failed for {split}: missing={missing[:10]}, extra={extra[:10]}"
            )
        verification[split] = {"images": len(output_set), "unchanged": True}
    return verification


def source_manifest(candidate: SourceCandidate, filename: str) -> dict[str, object]:
    return {
        "source": str(candidate.path),
        "sourceLabel": candidate.source_label,
        "targetLabel": candidate.target_label,
        "output": filename,
        "width": candidate.record.width,
        "height": candidate.record.height,
        "bytes": candidate.record.size_bytes,
    }


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--data-dir", type=Path, required=True, help="Existing train/valid/test dataset.")
    parser.add_argument("--source-dir", type=Path, required=True, help="Folder-per-class external images.")
    parser.add_argument("--output-dir", type=Path, required=True, help="New output dataset directory.")
    parser.add_argument("--prefix", default="external", help="Filename prefix for added images.")
    parser.add_argument(
        "--include-class",
        action="append",
        default=[],
        help="Only merge these existing labels. Can be repeated. Default: every matched class.",
    )
    parser.add_argument(
        "--max-per-class",
        type=int,
        default=200,
        help="Maximum added images per class; 0 means unlimited (default: 200).",
    )
    parser.add_argument("--threshold", type=int, default=4, help="dHash distance threshold (default: 4).")
    parser.add_argument(
        "--mode",
        choices=("copy", "hardlink"),
        default="copy",
        help="How to copy existing files to the output. Default: copy (fully isolated).",
    )
    parser.add_argument("--source-name", default="", help="Dataset name for the merge report.")
    parser.add_argument("--source-url", default="", help="Dataset URL for the merge report.")
    parser.add_argument("--license", dest="license_name", default="", help="Dataset license for the merge report.")
    parser.add_argument("--dry-run", action="store_true", help="Report what would be added without writing.")
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    data_dir = args.data_dir.resolve()
    source_dir = args.source_dir.resolve()
    output_dir = args.output_dir.resolve()
    include_labels = {label for label in args.include_class if label}
    include_normalized = {normalize_label(label) for label in include_labels}

    if not 0 <= args.threshold <= 16:
        print("[merge] ERROR: --threshold must be between 0 and 16.", file=sys.stderr)
        return 2
    if args.max_per_class < 0:
        print("[merge] ERROR: --max-per-class must be >= 0.", file=sys.stderr)
        return 2
    if output_dir == data_dir or output_dir == source_dir:
        print("[merge] ERROR: --output-dir must differ from input/source.", file=sys.stderr)
        return 2
    if output_dir.exists() and any(output_dir.iterdir()):
        print(f"[merge] ERROR: output directory is not empty: {output_dir}", file=sys.stderr)
        return 2

    try:
        existing, existing_labels = scan_existing(data_dir)
        candidates, ignored, failures = scan_source(
            source_dir,
            existing_labels,
            include_normalized=include_normalized,
        )
    except (FileNotFoundError, ValueError) as exc:
        print(f"[merge] ERROR: {exc}", file=sys.stderr)
        return 1

    existing_by_split = Counter(record.split for record in existing)
    existing_by_class = Counter(record.label for record in existing)
    source_by_class = Counter(candidate.source_label for candidate in candidates)

    accepted, selection_report = select_additions(
        existing,
        candidates,
        threshold=args.threshold,
        max_per_class=args.max_per_class,
    )
    added_by_class = Counter(candidate.target_label for candidate in accepted)
    added_by_split = Counter("train" for _ in accepted)

    print(f"[merge] Existing: {len(existing)} images ({dict(sorted(existing_by_split.items()))})")
    print(f"[merge] Source: {len(candidates)} readable images, {len(source_by_class)} matched classes")
    if ignored:
        print(f"[merge] Ignored source classes: {', '.join(sorted(ignored))}")
    if failures:
        print(f"[merge] Skipped unreadable source images: {len(failures)}")
    print(f"[merge] Candidate unique: {selection_report['availableUniqueByClass']}")
    print(f"[merge] Selected additions: {dict(sorted(added_by_class.items()))}")
    if selection_report["cappedByClass"]:
        print(f"[merge] Left for later due to cap: {selection_report['cappedByClass']}")
    print(f"[merge] Skipped: {selection_report['skippedCounts']}")

    if args.dry_run:
        print("[merge] Dry run: no files written.")
        return 0

    output_dir.mkdir(parents=True, exist_ok=True)
    try:
        copied = copy_existing(data_dir, output_dir, args.mode)
        verification = verify_existing_copy(data_dir, output_dir)
        print(f"[merge] Copied existing images: {copied}; valid/test verified unchanged.")

        manifest: list[dict[str, object]] = []
        used_names: set[tuple[str, str]] = set()
        for candidate in accepted:
            digest = hashlib.sha1(candidate.path.read_bytes()).hexdigest()[:12]
            stem = f"{args.prefix}_{normalize_label(candidate.source_label)}_{digest}"
            destination = output_dir / "train" / candidate.target_label / f"{stem}{candidate.path.suffix.lower()}"
            suffix_index = 2
            while (candidate.target_label, destination.name) in used_names or destination.exists():
                destination = output_dir / "train" / candidate.target_label / f"{stem}_{suffix_index}{candidate.path.suffix.lower()}"
                suffix_index += 1
            used_names.add((candidate.target_label, destination.name))
            copy_or_link(candidate.path, destination, "copy")
            manifest.append(source_manifest(candidate, str(destination.relative_to(output_dir))))

        output_by_split = {
            split: len(relative_image_set(output_dir, split)) for split in SPLITS
        }
        if output_by_split["valid"] != existing_by_split["valid"]:
            raise RuntimeError("Validation split changed unexpectedly.")
        if output_by_split["test"] != existing_by_split["test"]:
            raise RuntimeError("Test split changed unexpectedly.")

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
            "settings": {
                "threshold": args.threshold,
                "maxPerClass": args.max_per_class,
                "mode": args.mode,
                "addedTo": ["train"],
            },
            "existing": {
                "total": len(existing),
                "bySplit": dict(sorted(existing_by_split.items())),
                "byClass": dict(sorted(existing_by_class.items())),
            },
            "sourceClasses": {
                "matched": dict(sorted(source_by_class.items())),
                "ignored": ignored,
                "unreadable": failures,
            },
            "additions": {
                "total": len(accepted),
                "bySplit": dict(sorted(added_by_split.items())),
                "byClass": dict(sorted(added_by_class.items())),
                **selection_report,
            },
            "output": {
                "bySplit": output_by_split,
                "verification": verification,
            },
        }
        write_json(output_dir / "merge_report.json", report)
        write_json(output_dir / "merge_added_files.json", manifest)
        print(f"[merge] Output dataset: {output_dir}")
        print(f"[merge] Report: {output_dir / 'merge_report.json'}")
        print(f"[merge] Added manifest: {output_dir / 'merge_added_files.json'}")
        print(f"[merge] Final split counts: {output_by_split}")
        return 0
    except Exception as exc:  # noqa: BLE001 - keep a clear failure message
        print(f"[merge] ERROR after output creation: {exc}", file=sys.stderr)
        print(f"[merge] Partial output left at {output_dir}; delete it before retrying.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
