#!/usr/bin/env python3
"""Build the mobile nutrition catalog from model labels + a curated seed file.

This is the contract between the ML pipeline and the Flutter app:

    class index (model output position) -> nutrition record (per 100 g)

The order of ``classes`` in the generated JSON MUST be identical to the label
order produced by ``image_dataset_from_directory`` (alphabetical folder names)
and stored in ``class_names.json``. Any mismatch would silently show nutrition
for the wrong food, so this script is intentionally strict: missing, duplicated,
or out-of-order labels abort generation.

Usage:
    python generate_nutrition_data.py \
        --class-names output/class_names.json \
        --seed nutrition_seed.json \
        --output output/nutrition_data.json \
        --model-version 1.0.0
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

SCHEMA_VERSION = 1
_REQUIRED_MACROS = ("caloriesKcal", "proteinG", "carbohydrateG", "fatG")


class MetadataError(ValueError):
    """Raised when labels and nutrition seed data cannot be reconciled."""


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_label(value: str) -> str:
    """Normalize a class/food label for tolerant lookups.

    Directory names are normally already snake_case. Normalization means
    ``"Nasi Goreng"``, ``"nasi-goreng"``, and ``"nasi_goreng"`` resolve to the
    same catalog key.
    """

    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower())
    return normalized.strip("_")


def load_class_names(path: Path) -> list[str]:
    """Load labels from either a class_names.json object or a plain JSON list."""

    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        labels = payload.get("labels")
    elif isinstance(payload, list):
        labels = payload
    else:
        labels = None
    if not isinstance(labels, list) or not labels:
        raise MetadataError(f"{path} does not contain a non-empty 'labels' array.")
    if not all(isinstance(label, str) and label.strip() for label in labels):
        raise MetadataError(f"{path} contains empty or non-string labels.")
    if len(set(labels)) != len(labels):
        raise MetadataError(f"{path} contains duplicate labels.")
    return [label.strip() for label in labels]


def _number(value: Any, *, field: str, food: str, minimum: float = 0.0) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise MetadataError(f"'{field}' for '{food}' must be a number, got {value!r}.")
    if value < minimum:
        raise MetadataError(f"'{field}' for '{food}' must be >= {minimum}, got {value}.")
    return float(value)


def build_catalog(
    class_names: Sequence[str],
    seed: Mapping[str, Any],
    *,
    model_version: str | None = None,
    model_sha256: str | None = None,
) -> dict[str, Any]:
    """Validate and merge labels with nutrition records."""

    foods = seed.get("foods")
    if not isinstance(foods, dict) or not foods:
        raise MetadataError("Seed file must contain a non-empty 'foods' object.")

    normalized_seed: dict[str, dict[str, Any]] = {}
    for key, record in foods.items():
        if not isinstance(record, dict):
            raise MetadataError(f"Seed record '{key}' must be an object.")
        normalized = normalize_label(str(key))
        if normalized in normalized_seed:
            raise MetadataError(f"Seed contains duplicate food key after normalization: '{normalized}'.")
        normalized_seed[normalized] = {**record, "_seed_key": str(key)}

    default_portion = int(seed.get("defaultPortionGrams", 100))
    classes: list[dict[str, Any]] = []
    missing: list[str] = []
    warnings: list[str] = []

    for index, label in enumerate(class_names):
        normalized = normalize_label(label)
        record = normalized_seed.get(normalized)
        if record is None:
            missing.append(label)
            continue

        nutrition = record.get("nutritionPer100g")
        if not isinstance(nutrition, dict):
            raise MetadataError(f"'{label}' has no 'nutritionPer100g' object.")
        for macro in _REQUIRED_MACROS:
            if macro not in nutrition:
                raise MetadataError(f"'{label}' is missing required macro '{macro}'.")

        values = {
            macro: _number(nutrition.get(macro), field=macro, food=label)
            for macro in (*_REQUIRED_MACROS, "fiberG", "sodiumMg")
            if macro in nutrition
        }
        # fiber/sodium are useful but optional; provide stable defaults.
        values.setdefault("fiberG", 0.0)
        values.setdefault("sodiumMg", 0.0)

        portion = _number(
            record.get("defaultPortionGrams", default_portion),
            field="defaultPortionGrams",
            food=label,
            minimum=1,
        )
        display_name = str(record.get("displayName", label.replace("_", " ").title())).strip()
        if not display_name:
            raise MetadataError(f"'{label}' has an empty displayName.")

        aliases_raw = record.get("aliases", [])
        if not isinstance(aliases_raw, list) or not all(isinstance(a, str) for a in aliases_raw):
            raise MetadataError(f"'{label}'.aliases must be an array of strings.")
        aliases = sorted({normalize_label(alias) for alias in aliases_raw if alias.strip()})

        # Warn about grossly inconsistent calorie labels. Atwater factors are
        # not exact for every food (alcohol, fibre, etc.), but >25% deviation
        # usually indicates a copy/paste error in the seed file.
        atwater = (
            values["proteinG"] * 4.0
            + values["carbohydrateG"] * 4.0
            + values["fatG"] * 9.0
        )
        if values["caloriesKcal"] > 0 and atwater > 0:
            deviation = abs(atwater - values["caloriesKcal"]) / values["caloriesKcal"]
            if deviation > 0.25:
                warnings.append(
                    f"{label}: calorie value {values['caloriesKcal']:.0f} kcal differs "
                    f"{deviation:.0%} from Atwater estimate {atwater:.0f} kcal."
                )

        classes.append(
            {
                "index": index,
                "label": label,
                "normalizedLabel": normalized,
                "displayName": display_name,
                "emoji": str(record.get("emoji", "\U0001f37d\ufe0f")),
                "category": str(record.get("category", "main")),
                "aliases": aliases,
                "defaultPortionGrams": int(round(portion)),
                "nutritionPer100g": values,
            }
        )

    if missing:
        available = ", ".join(sorted(normalized_seed))
        raise MetadataError(
            "The model contains labels without nutrition data: "
            + ", ".join(missing)
            + f"\nAdd them to the seed file. Available seed keys: {available}"
        )

    # Detect seed entries that are never used. These are often typos and should
    # not silently rot as the class list evolves.
    used = {normalize_label(label) for label in class_names}
    unused = sorted(set(normalized_seed) - used)
    if unused:
        warnings.append("Seed entries not present in the model: " + ", ".join(unused))

    if len(classes) != len(class_names):
        raise MetadataError("Internal error: class count changed while building metadata.")
    labels = [entry["label"] for entry in classes]
    if labels != list(class_names):
        raise MetadataError("Internal error: class order changed while building metadata.")

    return {
        "schemaVersion": SCHEMA_VERSION,
        "modelVersion": model_version or "unversioned",
        "modelSha256": model_sha256,
        "generatedAt": _utc_now_iso(),
        "referenceAmount": 100,
        "referenceUnit": "g",
        "defaultPortionGrams": default_portion,
        "classCount": len(classes),
        "classes": classes,
        "warnings": warnings,
        "disclaimer": (
            "Nutrition values are estimates and may vary by recipe, portion, and "
            "ingredients. This application is not a medical device."
        ),
    }


def sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(chunk_size), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_catalog(catalog: Mapping[str, Any], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def generate_nutrition_data_file(
    *,
    class_names_path: Path,
    seed_path: Path,
    output_path: Path,
    model_version: str | None = None,
    model_path: Path | None = None,
    quiet: bool = False,
) -> dict[str, Any]:
    """Convenience function reused by train_export.py.

    Returns the generated catalog so callers can print a summary.
    """

    labels = load_class_names(class_names_path)
    seed = json.loads(seed_path.read_text(encoding="utf-8"))
    model_hash = sha256_file(model_path) if model_path and model_path.exists() else None
    catalog = build_catalog(
        labels,
        seed,
        model_version=model_version,
        model_sha256=model_hash,
    )
    write_catalog(catalog, output_path)
    if not quiet:
        print(f"[metadata] Wrote {len(labels)} classes to {output_path}")
        for warning in catalog["warnings"]:
            print(f"[metadata] WARNING: {warning}", file=sys.stderr)
    return catalog


def _parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--class-names", type=Path, required=True)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--model-version", default=None)
    parser.add_argument(
        "--model-path",
        type=Path,
        default=None,
        help="Optional .tflite file whose SHA-256 is recorded in the catalog.",
    )
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        generate_nutrition_data_file(
            class_names_path=args.class_names,
            seed_path=args.seed,
            output_path=args.output,
            model_version=args.model_version,
            model_path=args.model_path,
        )
    except (MetadataError, OSError, json.JSONDecodeError) as exc:
        print(f"[metadata] ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
