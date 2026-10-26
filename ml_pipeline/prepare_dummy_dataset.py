#!/usr/bin/env python3
"""Generate a tiny synthetic food dataset for pipeline smoke-testing.

This is NOT a substitute for a real food dataset. It exists so that
``train_export.py``, quantization, metadata generation, and the Flutter
pipeline can be exercised end-to-end before production images are available.

Usage:
    python prepare_dummy_dataset.py --output dataset/raw --images-per-class 60

Expected layout (created automatically):
    dataset/raw/
      bakso/0001.jpg
      gado_gado/0001.jpg
      ...
"""

from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Iterable

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

_IMAGE_SIZE = 320
_PLATE_MARGIN = 36


def _jitter(color: tuple[int, int, int], rng: random.Random, amount: int = 18) -> tuple[int, int, int]:
    return tuple(max(0, min(255, channel + rng.randint(-amount, amount))) for channel in color)


def _draw_table(draw: ImageDraw.ImageDraw, size: int, rng: random.Random) -> None:
    base = _jitter((181, 137, 91), rng, 12)
    draw.rectangle((0, 0, size, size), fill=base)
    for _ in range(28):
        y = rng.randint(-10, size + 10)
        amplitude = rng.uniform(2.0, 8.0)
        frequency = rng.uniform(0.01, 0.04)
        phase = rng.uniform(0, math.tau)
        color = _jitter(base, rng, 16)
        points = [
            (
                x,
                y + math.sin(x * frequency + phase) * amplitude + rng.uniform(-1.5, 1.5),
            )
            for x in range(0, size + 8, 8)
        ]
        draw.line(points, fill=color, width=rng.randint(1, 3))


def _draw_plate(draw: ImageDraw.ImageDraw, size: int, rng: random.Random) -> tuple[int, int, int]:
    margin = _PLATE_MARGIN + rng.randint(-6, 8)
    plate_box = (margin, margin, size - margin, size - margin)
    shadow_offset = rng.randint(4, 9)
    draw.ellipse(
        (
            plate_box[0] + shadow_offset,
            plate_box[1] + shadow_offset,
            plate_box[2] + shadow_offset,
            plate_box[3] + shadow_offset,
        ),
        fill=(104, 73, 48),
    )
    draw.ellipse(plate_box, fill=(244, 241, 232), outline=(219, 213, 200), width=3)
    inset = margin + 22
    draw.ellipse((inset, inset, size - inset, size - inset), outline=(228, 222, 210), width=3)
    return (inset + 2, inset + 2, size - inset - 2, size - inset - 2)


def _draw_grains(
    draw: ImageDraw.ImageDraw,
    plate: tuple[int, int, int, int],
    rng: random.Random,
    count: int,
    palette: tuple[tuple[int, int, int], ...],
    *,
    width: int = 3,
    length: int = 7,
) -> None:
    for _ in range(count):
        x = rng.randint(plate[0] + 18, plate[2] - 18)
        y = rng.randint(plate[1] + 18, plate[3] - 18)
        angle = rng.uniform(0, math.pi)
        dx = math.cos(angle) * length
        dy = math.sin(angle) * length
        draw.line((x, y, x + dx, y + dy), fill=rng.choice(palette), width=width)


def _draw_round_bits(
    draw: ImageDraw.ImageDraw,
    plate: tuple[int, int, int, int],
    rng: random.Random,
    count: int,
    palette: tuple[tuple[int, int, int], ...],
    radius: tuple[int, int] = (3, 8),
) -> None:
    for _ in range(count):
        x = rng.randint(plate[0] + 20, plate[2] - 20)
        y = rng.randint(plate[1] + 20, plate[3] - 20)
        r = rng.randint(*radius)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=rng.choice(palette))


def _nasi_goreng(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((226, 187, 97), rng, 20))
    _draw_grains(
        draw,
        plate,
        rng,
        420,
        ((250, 245, 218), (235, 218, 168), (214, 186, 124), (255, 252, 235)),
        length=8,
    )
    _draw_round_bits(draw, plate, rng, 55, ((195, 92, 54), (226, 130, 71), (117, 142, 77)), (3, 6))
    # Sunny-side-up egg.
    ex = rng.randint(plate[0] + 70, plate[2] - 70)
    ey = rng.randint(plate[1] + 70, plate[3] - 70)
    draw.ellipse((ex - 34, ey - 27, ex + 34, ey + 27), fill=(251, 248, 232))
    draw.ellipse((ex - 15, ey - 13, ex + 15, ey + 13), fill=(247, 190, 48))
    draw.ellipse((ex - 9, ey - 8, ex + 7, ey + 7), fill=(255, 212, 73))
    for _ in range(90):
        x = rng.randint(plate[0] + 10, plate[2] - 10)
        y = rng.randint(plate[1] + 10, plate[3] - 10)
        draw.point((x, y), fill=_jitter((224, 184, 100), rng, 20))


def _mie_goreng(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((222, 178, 91), rng, 15))
    cx = (plate[0] + plate[2]) // 2
    cy = (plate[1] + plate[3]) // 2
    for _ in range(95):
        offset_x = rng.randint(-85, 85)
        offset_y = rng.randint(-65, 65)
        width = rng.randint(30, 70)
        height = rng.randint(18, 45)
        start = rng.uniform(-0.3, math.pi + 0.3)
        color = rng.choice(((237, 196, 92), (217, 167, 67), (247, 215, 121), (195, 139, 48)))
        draw.arc(
            (cx + offset_x - width, cy + offset_y - height, cx + offset_x + width, cy + offset_y + height),
            start * 180 / math.pi,
            (start + rng.uniform(1.2, 2.4)) * 180 / math.pi,
            fill=color,
            width=rng.randint(2, 4),
        )
    _draw_round_bits(draw, plate, rng, 35, ((75, 126, 66), (232, 99, 52), (247, 238, 207)), (3, 6))
    # Shredded chicken.
    for _ in range(18):
        x = rng.randint(plate[0] + 30, plate[2] - 30)
        y = rng.randint(plate[1] + 30, plate[3] - 30)
        draw.line((x, y, x + rng.randint(-16, 16), y + rng.randint(-10, 10)), fill=(191, 139, 83), width=2)


def _rendang(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((76, 47, 28), rng, 12))
    _draw_round_bits(draw, plate, rng, 35, ((111, 69, 40), (142, 88, 48), (86, 51, 30)), (12, 26))
    for _ in range(16):
        x = rng.randint(plate[0] + 45, plate[2] - 45)
        y = rng.randint(plate[1] + 45, plate[3] - 45)
        w = rng.randint(32, 62)
        h = rng.randint(26, 48)
        draw.rounded_rectangle(
            (x, y, x + w, y + h),
            radius=rng.randint(6, 13),
            fill=rng.choice(((106, 58, 29), (130, 73, 35), (151, 90, 43), (87, 48, 27))),
            outline=(70, 40, 24),
            width=2,
        )
        draw.ellipse((x + 8, y + 7, x + 20, y + 15), fill=(177, 111, 57))
    _draw_round_bits(draw, plate, rng, 14, ((187, 53, 37), (121, 155, 65)), (4, 8))


def _sate_ayam(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((237, 217, 183), rng, 12))
    # Peanut sauce pool.
    draw.ellipse(
        (plate[0] + 55, plate[1] + 150, plate[2] - 55, plate[3] - 25),
        fill=_jitter((207, 142, 51), rng, 20),
    )
    for skewer in range(3):
        start_x = plate[0] + 55 + skewer * 22
        start_y = plate[1] + 90 + skewer * 14
        end_x = plate[2] - 45 + skewer * 4
        end_y = plate[1] + 185 - skewer * 10
        draw.line((start_x, start_y, end_x, end_y), fill=(192, 160, 109), width=4)
        for cube in range(5):
            t = (cube + 1) / 6.5
            x = start_x + (end_x - start_x) * t
            y = start_y + (end_y - start_y) * t
            draw.rounded_rectangle((x - 12, y - 11, x + 12, y + 11), radius=4, fill=_jitter((139, 82, 44), rng, 18))
            draw.ellipse((x - 7, y - 5, x + 2, y + 1), fill=(186, 120, 70))
    _draw_round_bits(draw, plate, rng, 20, ((195, 55, 44), (119, 154, 80), (248, 233, 196)), (4, 7))


def _gado_gado(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((233, 224, 194), rng, 10))
    for _ in range(35):
        x = rng.randint(plate[0] + 25, plate[2] - 25)
        y = rng.randint(plate[1] + 25, plate[3] - 25)
        w = rng.randint(22, 40)
        h = rng.randint(16, 30)
        draw.ellipse((x, y, x + w, y + h), fill=rng.choice(((74, 134, 58), (100, 158, 73), (54, 106, 48))))
    for _ in range(16):
        x = rng.randint(plate[0] + 30, plate[2] - 60)
        y = rng.randint(plate[1] + 30, plate[3] - 60)
        size = rng.randint(18, 30)
        draw.rectangle((x, y, x + size, y + size), fill=_jitter((231, 203, 136), rng, 15))
    # Egg slices.
    for _ in range(4):
        x = rng.randint(plate[0] + 50, plate[2] - 50)
        y = rng.randint(plate[1] + 50, plate[3] - 50)
        draw.ellipse((x - 18, y - 18, x + 18, y + 18), fill=(253, 249, 232))
        draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=(246, 190, 46))
    # Peanut dressing.
    for _ in range(45):
        x = rng.randint(plate[0] + 20, plate[2] - 20)
        y = rng.randint(plate[1] + 20, plate[3] - 20)
        draw.arc((x - 15, y - 8, x + 15, y + 8), 0, 180, fill=(205, 143, 57), width=3)
    _draw_round_bits(draw, plate, rng, 22, ((232, 108, 55), (248, 232, 200)), (3, 6))


def _bakso(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((194, 158, 96), rng, 20))
    draw.ellipse(
        (plate[0] + 30, plate[1] + 45, plate[2] - 30, plate[3] - 35),
        fill=_jitter((164, 119, 61), rng, 12),
    )
    for _ in range(7):
        x = rng.randint(plate[0] + 72, plate[2] - 72)
        y = rng.randint(plate[1] + 72, plate[3] - 72)
        r = rng.randint(22, 34)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=_jitter((157, 114, 77), rng, 15), outline=(119, 80, 52), width=2)
        draw.ellipse((x - r + 7, y - r + 7, x - 3, y - 3), fill=(190, 151, 112))
    for _ in range(45):
        y = rng.randint(plate[1] + 45, plate[3] - 35)
        x = rng.randint(plate[0] + 30, plate[2] - 75)
        draw.arc((x, y, x + rng.randint(28, 60), y + 14), 200, 330, fill=(244, 221, 174), width=2)
    _draw_round_bits(draw, plate, rng, 30, ((81, 130, 61), (245, 236, 193)), (3, 5))


def _pisang_goreng(draw: ImageDraw.ImageDraw, plate: tuple[int, int, int, int], rng: random.Random) -> None:
    draw.ellipse(plate, fill=_jitter((238, 224, 191), rng, 10))
    min_x = plate[0] + 24
    max_x = plate[2] - 24
    min_y = plate[1] + 32
    max_y = plate[3] - 32
    for _ in range(9):
        max_width = max(40, max_x - min_x)
        max_height = max(24, max_y - min_y)
        w = min(rng.randint(78, 112), max_width)
        h = min(rng.randint(28, 40), max_height)
        x = rng.randint(min_x, max(min_x, max_x - w))
        y = rng.randint(min_y, max(min_y, max_y - h))
        box = (x, y, x + w, y + h)
        draw.rounded_rectangle(box, radius=18, fill=_jitter((212, 157, 63), rng, 20), outline=(166, 110, 39), width=3)
        draw.arc(
            (x + 10, y + 5, x + w - 10, y + h + 12),
            195,
            345,
            fill=rng.choice(((238, 193, 99), (248, 210, 126), (176, 118, 44))),
            width=5,
        )
        for _ in range(10):
            sx = rng.randint(x + 15, x + w - 15)
            sy = rng.randint(y + 8, y + h - 8)
            draw.ellipse((sx, sy, sx + 4, sy + 3), fill=(247, 204, 111))
    for _ in range(35):
        x = rng.randint(plate[0] + 20, plate[2] - 20)
        y = rng.randint(plate[1] + 20, plate[3] - 20)
        draw.point((x, y), fill=(208, 164, 89))


def _es_teh(draw: ImageDraw.ImageDraw, size: int, rng: random.Random) -> None:
    # A glass instead of a plate, because this is a beverage class.
    glass_width = rng.randint(142, 166)
    glass_height = rng.randint(220, 252)
    cx = size // 2 + rng.randint(-12, 12)
    top = (size - glass_height) // 2 + 18
    left = cx - glass_width // 2
    right = cx + glass_width // 2
    bottom = top + glass_height
    draw.rounded_rectangle((left - 7, top - 8, right + 7, bottom + 8), radius=28, fill=(224, 219, 205))
    draw.rounded_rectangle((left, top, right, bottom), radius=24, fill=(189, 124, 47))
    draw.rounded_rectangle(
        (left + 10, top + 30, right - 10, bottom - 12),
        radius=20,
        fill=_jitter((198, 139, 59), rng, 14),
    )
    draw.ellipse((left + 10, top + 4, right - 10, top + 38), fill=(159, 95, 33))
    for _ in range(9):
        x = rng.randint(left + 20, right - 50)
        y = rng.randint(top + 40, bottom - 70)
        side = rng.randint(20, 30)
        draw.rounded_rectangle((x, y, x + side, y + side), radius=5, fill=(244, 236, 210), outline=(210, 199, 171))
    draw.rounded_rectangle((left + 12, top + 40, left + 28, bottom - 40), radius=6, fill=(219, 172, 101))
    # Straw.
    draw.line((cx + 30, top - 26, cx - 20, top + 45), fill=(194, 65, 60), width=8)
    draw.line((cx + 33, top - 26, cx - 17, top + 45), fill=(231, 101, 92), width=3)
    draw.ellipse((cx + 50, bottom + 4, cx + 95, bottom + 36), fill=(105, 75, 47))


def _add_photographic_noise(image: Image.Image, rng: random.Random) -> Image.Image:
    image = ImageEnhance.Brightness(image).enhance(rng.uniform(0.92, 1.08))
    image = ImageEnhance.Color(image).enhance(rng.uniform(0.92, 1.1))
    image = image.filter(ImageFilter.GaussianBlur(radius=rng.uniform(0.0, 0.55)))
    return image


_FOOD_DRAWERS: dict[str, Callable[..., None]] = {
    "nasi_goreng": _nasi_goreng,
    "mie_goreng": _mie_goreng,
    "rendang": _rendang,
    "sate_ayam": _sate_ayam,
    "gado_gado": _gado_gado,
    "bakso": _bakso,
    "pisang_goreng": _pisang_goreng,
}


def _render(index: int, class_name: str, rng: random.Random) -> Image.Image:
    size = _IMAGE_SIZE
    image = Image.new("RGB", (size, size), (181, 137, 91))
    draw = ImageDraw.Draw(image)
    _draw_table(draw, size, rng)
    if class_name == "es_teh":
        _es_teh(draw, size, rng)
    else:
        plate = _draw_plate(draw, size, rng)
        drawer = _FOOD_DRAWERS[class_name]
        drawer(draw, plate, rng)
        # Subtle crumbs / garnish escaped from the plate.
        for _ in range(8):
            angle = rng.uniform(0, math.tau)
            radius = rng.uniform(size * 0.3, size * 0.47)
            x = size // 2 + math.cos(angle) * radius
            y = size // 2 + math.sin(angle) * radius
            dot = rng.randint(1, 3)
            draw.ellipse((x - dot, y - dot, x + dot, y + dot), fill=_jitter((142, 99, 56), rng, 25))
    image = _add_photographic_noise(image, rng)
    if index % 4 == 0:
        # Cost-free geometric diversity; not needed for real datasets.
        image = image.rotate(rng.uniform(-3.5, 3.5), resample=Image.Resampling.BICUBIC, fillcolor=(160, 118, 81))
    return image


def generate_dummy_dataset(
    *,
    output_dir: Path,
    seed_file: Path,
    images_per_class: int = 60,
    seed: int = 42,
    clean: bool = True,
) -> dict[str, int]:
    seed_payload = json.loads(seed_file.read_text(encoding="utf-8"))
    class_names = sorted(seed_payload["foods"].keys())
    if not class_names:
        raise ValueError("Seed file contains no food classes.")

    if clean and output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    counts: dict[str, int] = {}
    for class_index, class_name in enumerate(class_names):
        class_dir = output_dir / class_name
        class_dir.mkdir(parents=True, exist_ok=True)
        # Seed per class so adding one class does not reshuffle all others.
        rng = random.Random(seed + class_index * 100_003)
        for image_index in range(images_per_class):
            image = _render(image_index, class_name, rng)
            image.save(class_dir / f"{image_index:04d}.jpg", quality=88, optimize=True)
        counts[class_name] = images_per_class
        print(f"[dummy] {class_name:<16} {images_per_class:>4} images")

    info = {
        "kind": "synthetic-smoke-test",
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "seed": seed,
        "imagesPerClass": images_per_class,
        "classes": class_names,
        "warning": "Synthetic images are only for validating the pipeline, never for production accuracy claims.",
    }
    (output_dir / "dataset_info.json").write_text(json.dumps(info, indent=2) + "\n", encoding="utf-8")
    print(f"[dummy] Dataset ready at {output_dir.resolve()} ({sum(counts.values())} images)")
    return counts


def _parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent / "dataset" / "raw")
    parser.add_argument("--seed-file", type=Path, default=Path(__file__).resolve().parent / "nutrition_seed.json")
    parser.add_argument("--images-per-class", type=int, default=60)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--keep", action="store_true", help="Do not delete an existing output directory.")
    args = parser.parse_args(argv)
    if args.images_per_class < 8:
        parser.error("--images-per-class must be >= 8 to support a validation split.")
    return args


def main(argv: Iterable[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        generate_dummy_dataset(
            output_dir=args.output,
            seed_file=args.seed_file,
            images_per_class=args.images_per_class,
            seed=args.seed,
            clean=not args.keep,
        )
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f"[dummy] ERROR: {exc}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
