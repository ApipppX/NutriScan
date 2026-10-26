#!/usr/bin/env python3
"""NutriScan training + post-training quantization + metadata export.

Pipeline
--------
1. Build memory-efficient ``tf.data`` datasets from ``data_dir/<class>/*.jpg``.
2. Transfer-learn MobileNetV3 (Small/Large, ImageNet weights) with frozen base.
3. Optionally unfreeze the last N backbone layers and fine-tune at a low LR.
4. Evaluate, export a `.keras` artifact, and produce TFLite models using
   post-training quantization (dynamic-range and/or FP16).
5. Benchmark each TFLite model and verify its accuracy against Keras.
6. Write `class_names.json` and `nutrition_data.json`, optionally copying all
   mobile assets into the Flutter project.

Model contract consumed by the Flutter app
------------------------------------------
Input : float32 [1, 224, 224, 3], RGB, normalized to [-1, 1]
Output: float32 [1, num_classes], softmax probabilities
Labels: alphabetical order of dataset class folders (stored in class_names.json)

Run from anywhere:
    python ml_pipeline/train_export.py \
        --data-dir ml_pipeline/dataset/raw \
        --output-dir ml_pipeline/output \
        --quantization both \
        --flutter-assets-dir assets
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import shutil
import sys
import time
import traceback
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Sequence

# Reduce noisy native logs before TensorFlow is imported.
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")

import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from generate_nutrition_data import (  # noqa: E402  (path injected above)
    MetadataError,
    generate_nutrition_data_file,
    sha256_file,
)

IMAGE_SIZE = 224
CHANNELS = 3
AUTOTUNE = tf.data.AUTOTUNE
SUPPORTED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".jfif"}
DEFAULT_DATA_DIR = SCRIPT_DIR / "dataset" / "raw"
DEFAULT_OUTPUT_DIR = SCRIPT_DIR / "output"
DEFAULT_SEED_PATH = SCRIPT_DIR / "nutrition_seed.json"


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def set_global_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    keras.utils.set_random_seed(seed)


def count_dataset_files(root: Path) -> dict[str, int]:
    """Count supported image files per class before handing data to Keras."""

    if not root.is_dir():
        raise FileNotFoundError(f"Dataset directory does not exist: {root}")
    counts: dict[str, int] = {}
    for class_dir in sorted(path for path in root.iterdir() if path.is_dir() and not path.name.startswith(".")):
        count = sum(
            1
            for path in class_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS
        )
        if count:
            counts[class_dir.name] = count
    if not counts:
        raise ValueError(
            f"No supported images found under {root}. Expected <class_name>/*.jpg subfolders."
        )
    if len(counts) < 2:
        raise ValueError("At least two class folders are required for classification.")
    return counts


def class_weights_from_counts(counts: Counter[str], class_names: Sequence[str]) -> dict[int, float]:
    total = sum(counts.values())
    class_count = len(class_names)
    weights: dict[int, float] = {}
    for index, name in enumerate(class_names):
        count = max(1, counts.get(name, 0))
        weights[index] = total / (class_count * count)
    return weights


def _history_to_json(history: keras.callbacks.History) -> dict[str, list[float]]:
    return {
        key: [float(value) for value in values]
        for key, values in history.history.items()
    }


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False, default=str) + "\n",
        encoding="utf-8",
    )


# ---------------------------------------------------------------------------
# Data pipeline
# ---------------------------------------------------------------------------
def _build_augmenter() -> keras.Sequential:
    """Training-only augmentation for small, web-scraped food datasets."""

    return keras.Sequential(
        [
            layers.RandomFlip("horizontal"),
            layers.RandomRotation(factor=0.08, fill_mode="reflect"),
            layers.RandomZoom(
                height_factor=(-0.12, 0.12),
                width_factor=(-0.12, 0.12),
                fill_mode="reflect",
            ),
            layers.RandomTranslation(
                height_factor=0.06,
                width_factor=0.06,
                fill_mode="reflect",
            ),
            # Small random occlusions discourage relying on a single garnish or
            # plate edge. Keep the area small so the food remains recognisable.
            layers.RandomErasing(
                factor=0.2,
                scale=(0.02, 0.12),
                fill_value=0.0,
                value_range=(0, 255),
            ),
        ],
        name="training_augmentation",
    )


def _augment_batch(images: tf.Tensor, labels: tf.Tensor, augmenter: keras.Sequential) -> tuple[tf.Tensor, tf.Tensor]:
    """Augment a batch of float32 images in the 0..255 range.

    Keras handles rotation/flip/zoom/translation; TensorFlow image ops add
    colour jitter (brightness, contrast, saturation, hue) after scaling to
    0..1. The batch is finally mapped to the MobileNetV3 [-1, 1] input range.
    """

    images = augmenter(images, training=True)
    images = images / 255.0
    images = tf.image.random_brightness(images, max_delta=0.08)
    images = tf.image.random_contrast(images, lower=0.88, upper=1.12)
    images = tf.image.random_saturation(images, lower=0.88, upper=1.12)
    images = tf.image.random_hue(images, max_delta=0.015)
    images = tf.clip_by_value(images, 0.0, 1.0) * 2.0 - 1.0
    return images, labels


def _list_class_files(root: Path) -> dict[str, list[Path]]:
    """Return sorted image paths grouped by class folder name."""

    if not root.is_dir():
        raise FileNotFoundError(f"Dataset directory does not exist: {root}")
    grouped: dict[str, list[Path]] = {}
    for class_dir in sorted(
        path for path in root.iterdir() if path.is_dir() and not path.name.startswith(".")
    ):
        files = sorted(
            path
            for path in class_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS
        )
        if files:
            grouped[class_dir.name] = files
    if not grouped:
        raise ValueError(
            f"No supported images found under {root}. Expected <class_name>/*.jpg subfolders."
        )
    if len(grouped) < 2:
        raise ValueError("At least two class folders are required for classification.")
    return grouped


def _decode_and_crop(path: tf.Tensor, label: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
    """Decode one image, centre-crop to a square, and resize to the model input.

    Output stays in the 0..255 float32 range; normalization happens in the
    augmentation/normalization maps so the augmentation layers can use their
    standard image-domain settings.
    """

    data = tf.io.read_file(path)
    image = tf.io.decode_image(
        data,
        channels=CHANNELS,
        dtype=tf.uint8,
        expand_animations=False,
    )
    image.set_shape([None, None, CHANNELS])
    image = tf.cast(image, tf.float32)

    shape = tf.shape(image)
    height, width = shape[0], shape[1]
    side = tf.minimum(height, width)
    offset_height = (height - side) // 2
    offset_width = (width - side) // 2
    image = tf.image.crop_to_bounding_box(
        image,
        offset_height,
        offset_width,
        side,
        side,
    )
    image = tf.image.resize(
        image,
        (IMAGE_SIZE, IMAGE_SIZE),
        method=tf.image.ResizeMethod.BILINEAR,
        antialias=True,
    )
    image.set_shape([IMAGE_SIZE, IMAGE_SIZE, CHANNELS])
    return image, label


def _normalize_batch(images: tf.Tensor, labels: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
    """Convert 0..255 pixels to the MobileNetV3 [-1, 1] input contract."""

    images = tf.cast(images, tf.float32) / 127.5 - 1.0
    return images, labels


def _make_dataset(
    paths: Sequence[Path],
    labels: Sequence[int],
    *,
    batch_size: int,
    shuffle: bool,
    seed: int,
) -> tf.data.Dataset:
    dataset = tf.data.Dataset.from_tensor_slices(
        (
            tf.constant([str(path) for path in paths]),
            tf.constant(list(labels), dtype=tf.int32),
        )
    )
    if shuffle:
        dataset = dataset.shuffle(
            buffer_size=len(paths),
            seed=seed,
            reshuffle_each_iteration=True,
        )
    dataset = dataset.map(_decode_and_crop, num_parallel_calls=AUTOTUNE)
    return dataset.batch(batch_size, drop_remainder=False)


def build_datasets(
    data_dir: Path,
    *,
    val_split: float,
    batch_size: int,
    seed: int,
    cache: bool,
    test_dir: Path | None,
    val_dir: Path | None = None,
) -> tuple[tf.data.Dataset, tf.data.Dataset, tf.data.Dataset | None, list[str], dict[str, int]]:
    """Create train/validation/(test) datasets.

    By default each class is split into train/validation with a seeded,
    stratified split. When ``val_dir`` is supplied, the existing train and
    validation directories are used as-is; both must contain exactly the same
    class folders.

    The datasets are lazy: images are decoded on the fly. Optional caching keeps
    decoded training pixels in RAM; augmentation runs after the cache so each
    epoch still sees fresh random transforms.
    """

    grouped = _list_class_files(data_dir)
    class_names = sorted(grouped)
    total_images = sum(len(files) for files in grouped.values())
    print(f"[data] Found {len(class_names)} classes, {total_images} images in {data_dir}")

    train_paths: list[Path] = []
    val_paths: list[Path] = []
    train_labels: list[int] = []
    val_labels: list[int] = []
    train_file_counts: Counter[str] = Counter()
    val_file_counts: Counter[str] = Counter()

    if val_dir is not None:
        val_grouped = _list_class_files(val_dir)
        expected = set(class_names)
        actual = set(val_grouped)
        if actual != expected:
            raise ValueError(
                "Validation directory class mismatch. "
                f"Missing: {sorted(expected - actual)}; unexpected: {sorted(actual - expected)}."
            )
        for class_index, name in enumerate(class_names):
            class_train = list(grouped[name])
            class_val = list(val_grouped[name])
            if not class_train:
                raise ValueError(f"Class '{name}' has no training images.")
            if not class_val:
                raise ValueError(f"Class '{name}' has no validation images.")
            train_paths.extend(class_train)
            val_paths.extend(class_val)
            train_labels.extend([class_index] * len(class_train))
            val_labels.extend([class_index] * len(class_val))
            train_file_counts[name] = len(class_train)
            val_file_counts[name] = len(class_val)
        print(f"[data] Using pre-split validation directory: {val_dir}")
    else:
        rng = random.Random(seed)
        for class_index, name in enumerate(class_names):
            files = list(grouped[name])
            if len(files) < 3:
                raise ValueError(
                    f"Class '{name}' has only {len(files)} images; at least 3 are required "
                    "to create a train/validation split."
                )
            rng.shuffle(files)
            val_count = max(1, min(len(files) - 2, int(round(len(files) * val_split))))
            class_val = files[:val_count]
            class_train = files[val_count:]
            if not class_train:
                raise ValueError(f"Class '{name}' has no training images after the split.")

            train_paths.extend(class_train)
            val_paths.extend(class_val)
            train_labels.extend([class_index] * len(class_train))
            val_labels.extend([class_index] * len(class_val))
            train_file_counts[name] = len(class_train)
            val_file_counts[name] = len(class_val)

    if not train_paths or not val_paths:
        raise ValueError("Train/validation split produced an empty dataset.")

    test_ds: tf.data.Dataset | None = None
    if test_dir is not None:
        test_grouped = _list_class_files(test_dir)
        expected = set(class_names)
        actual = set(test_grouped)
        if actual != expected:
            raise ValueError(
                "Test directory class mismatch. "
                f"Missing: {sorted(expected - actual)}; unexpected: {sorted(actual - expected)}."
            )
        test_paths: list[Path] = []
        test_labels: list[int] = []
        class_to_index = {name: index for index, name in enumerate(class_names)}
        for name in class_names:
            test_paths.extend(test_grouped[name])
            test_labels.extend([class_to_index[name]] * len(test_grouped[name]))
        test_ds = _make_dataset(
            test_paths,
            test_labels,
            batch_size=batch_size,
            shuffle=False,
            seed=seed,
        ).map(_normalize_batch, num_parallel_calls=AUTOTUNE)
        test_ds = test_ds.prefetch(AUTOTUNE)
        print(f"[data] Test set: {len(test_paths)} images")

    augmenter = _build_augmenter()

    train_ds = _make_dataset(
        train_paths,
        train_labels,
        batch_size=batch_size,
        shuffle=True,
        seed=seed,
    )
    if cache:
        # Cache decoded pixels before augmentation so random transforms still
        # vary every epoch. Use only when the dataset fits comfortably in RAM.
        train_ds = train_ds.cache()
        print("[data] Training cache enabled (decoded pixels kept in RAM)")
    train_ds = train_ds.map(
        lambda images, labels: _augment_batch(images, labels, augmenter),
        num_parallel_calls=AUTOTUNE,
        deterministic=False,
    )
    train_ds = train_ds.prefetch(AUTOTUNE)

    val_ds = _make_dataset(
        val_paths,
        val_labels,
        batch_size=batch_size,
        shuffle=False,
        seed=seed,
    ).map(_normalize_batch, num_parallel_calls=AUTOTUNE)
    val_ds = val_ds.prefetch(AUTOTUNE)

    missing = [
        name
        for name in class_names
        if train_file_counts.get(name, 0) == 0 or val_file_counts.get(name, 0) == 0
    ]
    if missing:
        raise ValueError(f"Classes missing from a split: {missing}")

    print(f"[data] Class order (index -> label): {dict(enumerate(class_names))}")
    if val_dir is not None:
        print(
            f"[data] Split: {len(train_paths)} train / {len(val_paths)} validation "
            f"(pre-split directories)"
        )
    else:
        print(
            f"[data] Split: {len(train_paths)} train / {len(val_paths)} validation "
            f"({val_split:.0%} per class, seed={seed})"
        )
    return train_ds, val_ds, test_ds, class_names, dict(train_file_counts)


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
def build_model(
    *,
    num_classes: int,
    variant: str,
    weights: str | None,
    dropout: float,
    dense_units: int,
) -> tuple[keras.Model, keras.Model]:
    """Frozen-backbone transfer-learning model.

    The exported model consumes pixels already normalized to [-1, 1] (the same
    contract as the Flutter preprocessor). ``include_preprocessing=False``
    prevents MobileNetV3 from adding a second, hidden rescaling layer so the
    on-device preprocessing stays unambiguous.
    """

    weights_arg: str | None = "imagenet" if weights == "imagenet" else None
    common = {
        "input_shape": (IMAGE_SIZE, IMAGE_SIZE, CHANNELS),
        "include_top": False,
        "weights": weights_arg,
        "include_preprocessing": False,
        "name": f"{variant}_backbone",
    }
    if variant == "mobilenetv3_small":
        base = keras.applications.MobileNetV3Small(**common)
    elif variant == "mobilenetv3_large":
        base = keras.applications.MobileNetV3Large(**common)
    else:
        raise ValueError(f"Unsupported model variant: {variant}")
    base.trainable = False

    inputs = keras.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, CHANNELS), name="image")
    x = base(inputs, training=False)
    x = layers.GlobalAveragePooling2D(name="global_average_pooling")(x)
    x = layers.Dense(
        dense_units,
        activation="relu",
        kernel_initializer="he_normal",
        kernel_regularizer=keras.regularizers.l2(1e-4),
        name="classifier_dense",
    )(x)
    x = layers.Dropout(dropout, name="classifier_dropout")(x)
    outputs = layers.Dense(num_classes, activation="softmax", dtype="float32", name="predictions")(x)

    model = keras.Model(inputs, outputs, name="nutriscan_classifier")
    return model, base


@keras.utils.register_keras_serializable(package="nutriscan")
class SparseCategoricalCrossentropyWithSmoothing(keras.losses.Loss):
    """Sparse categorical cross-entropy with optional label smoothing.

    Keras 3.15 removed ``label_smoothing`` from the sparse loss (it remains on
    the categorical variant), so this keeps the pipeline's smoothing option
    without forcing one-hot labels throughout the dataset/metrics.
    """

    def __init__(
        self,
        label_smoothing: float = 0.0,
        name: str = "sparse_categorical_crossentropy_smoothed",
    ) -> None:
        super().__init__(name=name)
        if not 0.0 <= label_smoothing < 1.0:
            raise ValueError("label_smoothing must be in [0, 1).")
        self.label_smoothing = float(label_smoothing)

    def call(self, y_true: tf.Tensor, y_pred: tf.Tensor) -> tf.Tensor:
        y_true = tf.cast(tf.reshape(y_true, [-1]), tf.int32)
        num_classes = tf.shape(y_pred)[-1]
        y_pred = tf.clip_by_value(
            y_pred,
            keras.backend.epsilon(),
            1.0 - keras.backend.epsilon(),
        )
        targets = tf.one_hot(y_true, num_classes)
        if self.label_smoothing > 0:
            smoothing = tf.cast(self.label_smoothing, y_pred.dtype)
            uniform = smoothing / tf.cast(num_classes, y_pred.dtype)
            targets = targets * (1.0 - smoothing) + uniform
        return -tf.reduce_sum(targets * tf.math.log(y_pred), axis=-1)

    def get_config(self) -> dict[str, Any]:
        config = super().get_config()
        config.update({"label_smoothing": self.label_smoothing})
        return config


@keras.utils.register_keras_serializable(package="nutriscan")
class MacroF1Score(keras.metrics.Metric):
    """Sparse multiclass macro-F1, used for checkpointing model selection.

    Raw accuracy can hide a collapsing minority class. Macro-F1 weights every
    class equally and is therefore a better early-stopping signal for a food
    catalog where each class matters to the user.
    """

    def __init__(self, num_classes: int, name: str = "macro_f1", **kwargs: Any) -> None:
        super().__init__(name=name, **kwargs)
        self.num_classes = int(num_classes)
        self.total_cm = self.add_weight(
            name="total_cm",
            shape=(self.num_classes, self.num_classes),
            initializer="zeros",
            dtype=self.dtype,
        )

    def update_state(
        self,
        y_true: tf.Tensor,
        y_pred: tf.Tensor,
        sample_weight: tf.Tensor | None = None,
    ) -> None:
        del sample_weight  # Class-balanced dataset; no sample weighting needed.
        y_true = tf.cast(tf.reshape(y_true, [-1]), tf.int32)
        y_pred = tf.cast(tf.argmax(y_pred, axis=-1), tf.int32)
        matrix = tf.math.confusion_matrix(
            y_true,
            y_pred,
            num_classes=self.num_classes,
            dtype=self.dtype,
        )
        self.total_cm.assign_add(matrix)

    def result(self) -> tf.Tensor:
        matrix = self.total_cm
        true_positive = tf.linalg.diag_part(matrix)
        false_positive = tf.reduce_sum(matrix, axis=0) - true_positive
        false_negative = tf.reduce_sum(matrix, axis=1) - true_positive
        denominator = 2.0 * true_positive + false_positive + false_negative
        per_class = 2.0 * true_positive / (denominator + keras.backend.epsilon())
        return tf.reduce_mean(per_class)

    def reset_state(self) -> None:
        self.total_cm.assign(tf.zeros((self.num_classes, self.num_classes), dtype=self.dtype))

    def get_config(self) -> dict[str, Any]:
        config = super().get_config()
        config.update({"num_classes": self.num_classes})
        return config


def compile_model(model: keras.Model, *, learning_rate: float, label_smoothing: float) -> None:
    num_classes = int(model.output_shape[-1])
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=learning_rate, clipnorm=1.0),
        loss=SparseCategoricalCrossentropyWithSmoothing(label_smoothing=label_smoothing),
        metrics=[
            keras.metrics.SparseCategoricalAccuracy(name="accuracy"),
            MacroF1Score(num_classes=num_classes),
        ],
    )


def make_callbacks(
    *,
    checkpoint_path: Path,
    csv_path: Path,
    patience: int,
    monitor: str = "val_macro_f1",
) -> list[keras.callbacks.Callback]:
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    maximize = "accuracy" in monitor or "f1" in monitor
    return [
        keras.callbacks.ModelCheckpoint(
            filepath=str(checkpoint_path),
            monitor=monitor,
            mode="max" if maximize else "auto",
            save_best_only=True,
            save_weights_only=True,
            verbose=1,
        ),
        keras.callbacks.EarlyStopping(
            monitor=monitor,
            mode="max" if maximize else "auto",
            patience=patience,
            restore_best_weights=True,
            verbose=1,
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=max(1, patience // 2),
            min_lr=1e-7,
            verbose=1,
        ),
        keras.callbacks.TerminateOnNaN(),
        keras.callbacks.CSVLogger(str(csv_path), append=False),
    ]


def _best_history_value(history: keras.callbacks.History, key: str = "val_macro_f1") -> float:
    values = history.history.get(key)
    if not values:
        values = history.history.get("val_accuracy", [0.0])
    return float(max(values)) if values else 0.0


def train_model(
    model: keras.Model,
    base: keras.Model,
    train_ds: tf.data.Dataset,
    val_ds: tf.data.Dataset,
    args: argparse.Namespace,
    *,
    class_weights: dict[int, float] | None,
) -> tuple[keras.callbacks.History, keras.callbacks.History | None, Path, str]:
    """Two-stage transfer learning with macro-F1 model selection."""

    output_dir: Path = args.output_dir
    checkpoint_dir = output_dir / "checkpoints"
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    initial_checkpoint = checkpoint_dir / "initial_best.weights.h5"

    compile_model(model, learning_rate=args.learning_rate, label_smoothing=args.label_smoothing)
    model.summary(print_fn=lambda line: print(f"[model] {line}"))

    print(f"\n[train] Stage 1: frozen backbone for up to {args.initial_epochs} epochs")
    history_initial = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=args.initial_epochs,
        callbacks=make_callbacks(
            checkpoint_path=initial_checkpoint,
            csv_path=output_dir / "metrics_initial.csv",
            patience=args.patience,
        ),
        class_weight=class_weights,
        verbose=2,
    )
    best_initial = _best_history_value(history_initial)

    history_finetune: keras.callbacks.History | None = None
    selected_stage = "initial"
    if args.fine_tune_epochs > 0:
        print(
            f"\n[train] Stage 2: fine-tuning last {args.fine_tune_layers} backbone layers "
            f"for up to {args.fine_tune_epochs} epochs at lr={args.fine_tune_learning_rate:g}"
        )
        model.load_weights(initial_checkpoint)
        base.trainable = True
        cutoff = max(0, len(base.layers) - args.fine_tune_layers)
        for layer in base.layers[:cutoff]:
            layer.trainable = False
        # BatchNorm statistics must not be updated with a tiny fine-tune batch;
        # keeping them frozen is the safest default for mobile transfer learning.
        for layer in base.layers:
            if isinstance(layer, layers.BatchNormalization):
                layer.trainable = False
        compile_model(model, learning_rate=args.fine_tune_learning_rate, label_smoothing=args.label_smoothing)

        initial_epoch_count = len(history_initial.epoch)
        fine_checkpoint = checkpoint_dir / "finetuned_best.weights.h5"
        history_finetune = model.fit(
            train_ds,
            validation_data=val_ds,
            initial_epoch=initial_epoch_count,
            epochs=initial_epoch_count + args.fine_tune_epochs,
            callbacks=make_callbacks(
                checkpoint_path=fine_checkpoint,
                csv_path=output_dir / "metrics_finetune.csv",
                patience=max(2, args.patience),
            ),
            class_weight=class_weights,
            verbose=2,
        )
        best_finetune = _best_history_value(history_finetune)
        if best_finetune < best_initial:
            print(
                f"[train] Fine-tuning best {best_finetune:.4f} < initial {best_initial:.4f} "
                "on validation macro-F1; restoring the frozen-backbone weights."
            )
            model.load_weights(initial_checkpoint)
            selected_stage = "initial"
        else:
            selected_stage = "finetuned"
        best_score = max(best_initial, best_finetune)
    else:
        # EarlyStopping already restored the best weights.
        best_score = best_initial

    final_model_path = output_dir / "best_model.keras"
    model.save(final_model_path)
    print(f"[train] Selected {selected_stage} weights (val_macro_f1={best_score:.4f}) -> {final_model_path}")
    return history_initial, history_finetune, final_model_path, selected_stage


# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------
def _save_training_curves(
    history_initial: keras.callbacks.History,
    history_finetune: keras.callbacks.History | None,
    output_path: Path,
) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    train_acc = list(history_initial.history.get("accuracy", []))
    val_acc = list(history_initial.history.get("val_accuracy", []))
    train_loss = list(history_initial.history.get("loss", []))
    val_loss = list(history_initial.history.get("val_loss", []))
    initial_epochs = len(train_acc)

    if history_finetune is not None:
        train_acc += list(history_finetune.history.get("accuracy", []))
        val_acc += list(history_finetune.history.get("val_accuracy", []))
        train_loss += list(history_finetune.history.get("loss", []))
        val_loss += list(history_finetune.history.get("val_loss", []))

    epochs = range(1, len(train_acc) + 1)
    fig, (ax_acc, ax_loss) = plt.subplots(1, 2, figsize=(12, 4.5), dpi=150)
    ax_acc.plot(epochs, train_acc, label="train", linewidth=2)
    ax_acc.plot(epochs, val_acc, label="validation", linewidth=2)
    ax_acc.set_title("Accuracy")
    ax_acc.set_xlabel("Epoch")
    ax_acc.set_ylabel("Accuracy")
    ax_acc.grid(alpha=0.25)
    ax_acc.legend()

    ax_loss.plot(epochs, train_loss, label="train", linewidth=2)
    ax_loss.plot(epochs, val_loss, label="validation", linewidth=2)
    ax_loss.set_title("Loss")
    ax_loss.set_xlabel("Epoch")
    ax_loss.set_ylabel("Loss")
    ax_loss.grid(alpha=0.25)
    ax_loss.legend()

    if history_finetune is not None and initial_epochs > 0:
        for axis in (ax_acc, ax_loss):
            axis.axvline(initial_epochs + 0.5, color="gray", linestyle="--", linewidth=1)
            axis.text(
                initial_epochs + 1,
                axis.get_ylim()[1] * 0.93,
                "fine-tune",
                color="gray",
                fontsize=8,
            )

    fig.suptitle("NutriScan training", fontweight="bold")
    fig.tight_layout()
    fig.savefig(output_path)
    plt.close(fig)


def _save_confusion_matrix(
    matrix: np.ndarray,
    class_names: Sequence[str],
    output_path: Path,
) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    size = max(6.0, min(16.0, len(class_names) * 0.7 + 3.0))
    fig, ax = plt.subplots(figsize=(size, size), dpi=140)
    image = ax.imshow(matrix, interpolation="nearest", cmap="Greens")
    fig.colorbar(image, ax=ax, fraction=0.046, pad=0.04)
    ax.set(
        xticks=np.arange(len(class_names)),
        yticks=np.arange(len(class_names)),
        xticklabels=class_names,
        yticklabels=class_names,
        ylabel="True label",
        xlabel="Predicted label",
        title="Validation confusion matrix",
    )
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    threshold = matrix.max() / 2.0 if matrix.size else 0.0
    for row in range(matrix.shape[0]):
        for col in range(matrix.shape[1]):
            ax.text(
                col,
                row,
                str(int(matrix[row, col])),
                ha="center",
                va="center",
                fontsize=7,
                color="white" if matrix[row, col] > threshold else "black",
            )
    fig.tight_layout()
    fig.savefig(output_path)
    plt.close(fig)


def _expected_calibration_error(
    probabilities: np.ndarray,
    y_true: np.ndarray,
    n_bins: int = 10,
) -> float:
    """Top-label expected calibration error (lower is better)."""

    confidences = probabilities.max(axis=1)
    predictions = probabilities.argmax(axis=1)
    correct = (predictions == y_true).astype(np.float64)
    error = 0.0
    for lower in np.linspace(0.0, 1.0, n_bins + 1)[:-1]:
        upper = lower + 1.0 / n_bins
        mask = (confidences > lower) & (confidences <= upper)
        if np.any(mask):
            error += float(mask.mean()) * abs(float(correct[mask].mean()) - float(confidences[mask].mean()))
    return error


def _apply_temperature_np(probabilities: np.ndarray, temperature: float) -> np.ndarray:
    """Temperature-scale softmax probabilities without changing their ranking."""

    if not np.isfinite(temperature) or temperature <= 0:
        raise ValueError("temperature must be a positive finite number")
    scaled = np.power(np.clip(probabilities, 1e-12, 1.0), 1.0 / temperature)
    return scaled / scaled.sum(axis=1, keepdims=True)


def _fit_temperature(probabilities: np.ndarray, y_true: np.ndarray) -> float:
    """Fit one temperature on validation data by minimising NLL."""

    temperatures = np.arange(0.5, 2.501, 0.01)
    row_index = np.arange(len(y_true))
    best_temperature = 1.0
    best_nll = float("inf")
    for temperature in temperatures:
        calibrated = _apply_temperature_np(probabilities, float(temperature))
        nll = float(-np.mean(np.log(np.clip(calibrated[row_index, y_true], 1e-12, 1.0))))
        if nll < best_nll:
            best_nll = nll
            best_temperature = float(temperature)
    return best_temperature


def _bootstrap_interval(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    *,
    metric: str,
    iterations: int = 1000,
    seed: int = 42,
) -> list[float]:
    """Percentile bootstrap CI for accuracy or macro-F1."""

    from sklearn.metrics import accuracy_score, f1_score

    rng = np.random.default_rng(seed)
    values: list[float] = []
    size = len(y_true)
    for _ in range(iterations):
        index = rng.integers(0, size, size=size)
        if metric == "accuracy":
            value = accuracy_score(y_true[index], y_pred[index])
        elif metric == "macro_f1":
            value = f1_score(y_true[index], y_pred[index], average="macro", zero_division=0)
        else:
            raise ValueError(f"Unsupported bootstrap metric: {metric}")
        values.append(float(value))
    return [float(np.percentile(values, 2.5)), float(np.percentile(values, 97.5))]


def _classification_metrics(
    y_true: np.ndarray,
    probabilities: np.ndarray,
    class_names: Sequence[str],
) -> tuple[dict[str, Any], str, np.ndarray]:
    from sklearn.metrics import (
        accuracy_score,
        balanced_accuracy_score,
        classification_report,
        confusion_matrix,
        f1_score,
        log_loss,
        top_k_accuracy_score,
    )

    y_true = np.asarray(y_true, dtype=int)
    probabilities = np.asarray(probabilities, dtype=np.float64)
    if probabilities.ndim != 2 or len(probabilities) != len(y_true):
        raise ValueError('Probability matrix shape does not match labels.')
    if not np.all(np.isfinite(probabilities)):
        raise ValueError('Probability matrix contains NaN or infinite values.')
    row_sums = probabilities.sum(axis=1, keepdims=True)
    if np.any(row_sums <= 0):
        raise ValueError('Probability rows must have a positive sum.')
    if np.any(np.abs(row_sums - 1.0) > 0.05):
        raise ValueError('Model output rows are not valid probability distributions.')
    probabilities = probabilities / row_sums
    y_pred = probabilities.argmax(axis=1)
    labels = list(range(len(class_names)))
    top_k = min(3, len(class_names))
    report_text = classification_report(
        y_true,
        y_pred,
        labels=labels,
        target_names=list(class_names),
        zero_division=0,
        digits=4,
    )
    report_dict = classification_report(
        y_true,
        y_pred,
        labels=labels,
        target_names=list(class_names),
        zero_division=0,
        output_dict=True,
    )
    matrix = confusion_matrix(y_true, y_pred, labels=labels)
    metrics = {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "accuracy95CI": _bootstrap_interval(y_true, y_pred, metric="accuracy"),
        "balancedAccuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "macroF1": float(f1_score(y_true, y_pred, labels=labels, average="macro", zero_division=0)),
        "macroF195CI": _bootstrap_interval(y_true, y_pred, metric="macro_f1"),
        "top3Accuracy": float(
            top_k_accuracy_score(y_true, probabilities, k=top_k, labels=labels)
        ),
        "logLoss": float(log_loss(y_true, probabilities, labels=labels)),
        "expectedCalibrationError": float(_expected_calibration_error(probabilities, y_true)),
    }
    result = {
        **metrics,
        "classificationReport": report_dict,
        "confusionMatrix": matrix.tolist(),
        "classNames": list(class_names),
    }
    return result, report_text, matrix


def evaluate_model(
    model: keras.Model,
    dataset: tf.data.Dataset,
    class_names: Sequence[str],
    *,
    split_name: str,
    output_dir: Path,
) -> dict[str, Any]:
    print(f"\n[eval] Evaluating on {split_name} split")
    loss_metrics = model.evaluate(dataset, return_dict=True, verbose=0)
    probabilities = np.asarray(model.predict(dataset, verbose=0), dtype=np.float64)
    y_true = np.concatenate([np.asarray(labels) for _, labels in dataset], axis=0).astype(int)
    if len(y_true) != len(probabilities):
        raise RuntimeError(
            f"Prediction/label count mismatch on {split_name}: "
            f"{len(probabilities)} predictions vs {len(y_true)} labels."
        )

    result, report_text, matrix = _classification_metrics(y_true, probabilities, class_names)
    result.update(
        {
            "split": split_name,
            "samples": int(len(y_true)),
            "loss": float(loss_metrics.get("loss", float("nan"))),
        }
    )
    (output_dir / f"{split_name}_classification_report.txt").write_text(report_text, encoding="utf-8")
    _save_confusion_matrix(matrix, class_names, output_dir / f"{split_name}_confusion_matrix.png")

    print(
        f"[eval] {split_name}: accuracy={result['accuracy']:.4f} "
        f"(95% CI {result['accuracy95CI'][0]:.3f}-{result['accuracy95CI'][1]:.3f}), "
        f"macro-F1={result['macroF1']:.4f}, top-3={result['top3Accuracy']:.4f}, "
        f"ECE={result['expectedCalibrationError']:.4f}"
    )
    print(report_text)
    return result


# ---------------------------------------------------------------------------
# TFLite conversion + on-device contract audit
# ---------------------------------------------------------------------------
def convert_to_tflite(model: keras.Model, mode: str, output_path: Path) -> Path:
    """Convert a Keras model with post-training weight quantization.

    Dynamic-range and FP16 quantization both keep float32 inputs/outputs, so
    the mobile app always feeds normalized float32 pixels and reads softmax
    probabilities. This avoids the extra int8 calibration/zero-point contract
    that full-integer quantization would require.
    """

    if mode not in {"dynamic", "fp16"}:
        raise ValueError(f"Unsupported quantization mode: {mode}")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
    if mode == "fp16":
        converter.target_spec.supported_types = [tf.float16]

    try:
        payload = converter.convert()
    except Exception as exc:  # pragma: no cover - depends on TF/native build
        raise RuntimeError(
            f"TFLite conversion failed for mode={mode}. "
            "Try reducing the model, updating TensorFlow, or checking unsupported ops."
        ) from exc
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(payload)
    size_mb = len(payload) / (1024 * 1024)
    print(f"[tflite] {mode:<8} -> {output_path} ({size_mb:.2f} MiB)")
    return output_path


def _model_samples(
    dataset: tf.data.Dataset,
    limit: int | None,
) -> tuple[np.ndarray, np.ndarray]:
    images: list[np.ndarray] = []
    labels: list[np.ndarray] = []
    collected = 0
    for batch_images, batch_labels in dataset:
        images.append(np.asarray(batch_images, dtype=np.float32))
        labels.append(np.asarray(batch_labels, dtype=np.int64))
        collected += int(batch_images.shape[0])
        if limit is not None and collected >= limit:
            break
    if not images:
        raise ValueError("Evaluation dataset is empty.")
    all_images = np.concatenate(images, axis=0)
    all_labels = np.concatenate(labels, axis=0)
    if limit is not None:
        return all_images[:limit], all_labels[:limit]
    return all_images, all_labels


def _tflite_probability_matrix(
    tflite_path: Path,
    images: np.ndarray,
) -> np.ndarray:
    """Run a TFLite model over preprocessed images and return full probabilities."""

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path), num_threads=2)
    interpreter.allocate_tensors()
    try:
        input_details = interpreter.get_input_details()[0]
        output_details = interpreter.get_output_details()[0]
        if input_details["dtype"] != np.float32 or output_details["dtype"] != np.float32:
            raise RuntimeError("TFLite calibration requires float32 input/output tensors.")
        probabilities: list[np.ndarray] = []
        for image in images:
            interpreter.set_tensor(
                input_details["index"],
                np.expand_dims(image, axis=0).astype(np.float32),
            )
            interpreter.invoke()
            probabilities.append(
                np.asarray(interpreter.get_tensor(output_details["index"]))[0].astype(np.float64)
            )
        stacked = np.stack(probabilities, axis=0)
        row_sums = stacked.sum(axis=1, keepdims=True)
        if np.any(row_sums <= 0) or not np.all(np.isfinite(stacked)):
            raise RuntimeError('TFLite model returned invalid probabilities.')
        return stacked / row_sums
    finally:
        close = getattr(interpreter, "close", None)
        if callable(close):
            close()
        else:
            del interpreter


def evaluate_tflite_model(
    tflite_path: Path,
    dataset: tf.data.Dataset,
    class_names: Sequence[str],
    *,
    split_name: str,
    output_dir: Path,
    temperature: float = 1.0,
) -> dict[str, Any]:
    """Evaluate the exact mobile artifact on a full split, including calibration."""

    from sklearn.metrics import log_loss

    images, labels = _model_samples(dataset, None)
    probabilities = _tflite_probability_matrix(tflite_path, images)
    result, report_text, matrix = _classification_metrics(labels, probabilities, class_names)
    calibrated = _apply_temperature_np(probabilities, temperature)
    calibrated_metrics = {
        "accuracy": float(np.mean(calibrated.argmax(axis=1) == labels)),
        "macroF1": result["macroF1"],
        "top3Accuracy": result["top3Accuracy"],
        "logLoss": float(
            log_loss(labels, calibrated, labels=list(range(len(class_names))))
        ),
        "expectedCalibrationError": float(_expected_calibration_error(calibrated, labels)),
    }
    result.update(
        {
            "split": split_name,
            "samples": int(len(labels)),
            "metricsRaw": {
                "logLoss": result["logLoss"],
                "expectedCalibrationError": result["expectedCalibrationError"],
            },
            "temperatureScaled": {
                "temperature": float(temperature),
                **calibrated_metrics,
            },
        }
    )
    (output_dir / f"{split_name}_tflite_classification_report.txt").write_text(
        report_text,
        encoding="utf-8",
    )
    _save_confusion_matrix(
        matrix,
        class_names,
        output_dir / f"{split_name}_tflite_confusion_matrix.png",
    )
    print(
        f"[eval] TFLite {split_name}: accuracy={result['accuracy']:.4f}, "
        f"macro-F1={result['macroF1']:.4f}, ECE={result['expectedCalibrationError']:.4f} "
        f"-> {calibrated_metrics['expectedCalibrationError']:.4f} after T={temperature:.2f}"
    )
    return result


def audit_tflite(
    tflite_path: Path,
    keras_model: keras.Model,
    dataset: tf.data.Dataset,
    class_names: Sequence[str],
    *,
    sample_limit: int | None,
    mode: str,
) -> dict[str, Any]:
    """Verify input/output contract, quantized accuracy, agreement, latency."""

    images, labels = _model_samples(dataset, sample_limit)
    keras_probabilities = np.asarray(keras_model.predict(images, verbose=0), dtype=np.float32)
    keras_predictions = np.argmax(keras_probabilities, axis=1)

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path), num_threads=2)
    interpreter.allocate_tensors()
    try:
        input_details = interpreter.get_input_details()[0]
        output_details = interpreter.get_output_details()[0]
        input_shape = tuple(int(v) for v in input_details["shape"])
        if len(input_shape) != 4 or input_shape[-1] != CHANNELS:
            raise RuntimeError(f"Unexpected TFLite input shape: {input_shape}")
        if input_details["dtype"] != np.float32:
            raise RuntimeError(
                f"Expected float32 input (the Flutter contract), got {input_details['dtype']}."
            )
        if output_details["dtype"] != np.float32:
            raise RuntimeError(
                f"Expected float32 output, got {output_details['dtype']}."
            )
        if int(np.prod(input_details["shape"][1:])) != IMAGE_SIZE * IMAGE_SIZE * CHANNELS:
            raise RuntimeError(f"Expected a {IMAGE_SIZE}x{IMAGE_SIZE} RGB model, got {input_shape}.")

        predictions: list[int] = []
        confidences: list[float] = []
        quantized_probabilities: list[np.ndarray] = []
        per_image_latency_ms: list[float] = []
        for index, image in enumerate(images):
            input_tensor = np.expand_dims(image, axis=0).astype(np.float32)
            interpreter.set_tensor(input_details["index"], input_tensor)
            start = time.perf_counter()
            interpreter.invoke()
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            output = np.asarray(interpreter.get_tensor(output_details["index"]))[0]
            predictions.append(int(np.argmax(output)))
            confidences.append(float(np.max(output)))
            quantized_probabilities.append(output.astype(np.float64))
            if index >= 10:  # skip warm-up-ish samples for latency stats
                per_image_latency_ms.append(elapsed_ms)

        from sklearn.metrics import balanced_accuracy_score, f1_score

        quantized_predictions = np.asarray(predictions)
        quantized_probability_matrix = np.stack(quantized_probabilities, axis=0)
        accuracy = float(np.mean(quantized_predictions == labels))
        agreement = float(np.mean(quantized_predictions == keras_predictions))
        keras_accuracy = float(np.mean(keras_predictions == labels))
        latency = np.asarray(per_image_latency_ms) if per_image_latency_ms else np.asarray([0.0])

        result = {
            "mode": mode,
            "file": tflite_path.name,
            "sizeBytes": tflite_path.stat().st_size,
            "sizeMiB": round(tflite_path.stat().st_size / (1024 * 1024), 3),
            "sha256": sha256_file(tflite_path),
            "samples": int(len(images)),
            "accuracy": accuracy,
            "macroF1": float(
                f1_score(
                    labels,
                    quantized_predictions,
                    labels=list(range(len(class_names))),
                    average="macro",
                    zero_division=0,
                )
            ),
            "balancedAccuracy": float(balanced_accuracy_score(labels, quantized_predictions)),
            "expectedCalibrationError": float(
                _expected_calibration_error(quantized_probability_matrix, labels)
            ),
            "kerasAccuracy": keras_accuracy,
            "agreementWithKeras": agreement,
            "meanConfidence": float(np.mean(confidences)) if confidences else 0.0,
            "input": {
                "shape": list(input_shape),
                "dtype": str(input_details["dtype"]),
                "range": "[-1,1] RGB float32 (pre-normalized on device)",
            },
            "output": {
                "shape": [int(v) for v in output_details["shape"]],
                "dtype": str(output_details["dtype"]),
                "activation": "softmax",
                "classes": len(class_names),
            },
            "latencyDesktopMs": {
                "median": float(np.median(latency)),
                "p95": float(np.percentile(latency, 95)),
                "note": "CPU-only desktop timing; benchmark on target phones before release.",
            },
        }
        print(
            f"[audit] {mode}: quantized acc={accuracy:.4f}, macro-F1={result['macroF1']:.4f}, "
            f"Keras acc={keras_accuracy:.4f}, top-1 agreement={agreement:.4f}, "
            f"median={result['latencyDesktopMs']['median']:.2f} ms"
        )
        return result
    finally:
        close = getattr(interpreter, "close", None)
        if callable(close):
            close()
        else:
            # TensorFlow 2.21's deprecated tflite Interpreter no longer exposes
            # close(); dropping the reference releases the native interpreter.
            del interpreter


# ---------------------------------------------------------------------------
# Metadata
# ---------------------------------------------------------------------------
def write_class_names(
    path: Path,
    *,
    class_names: Sequence[str],
    model_version: str,
    primary_model: Path,
    quantization: str,
    confidence_temperature: float = 1.0,
    calibration: dict[str, Any] | None = None,
) -> None:
    payload = {
        "schemaVersion": 1,
        "modelVersion": model_version,
        "createdAt": utc_now_iso(),
        "input": {
            "width": IMAGE_SIZE,
            "height": IMAGE_SIZE,
            "channels": CHANNELS,
            "colorOrder": "RGB",
            "normalization": "[-1,1]",
        },
        "labels": list(class_names),
        "classCount": len(class_names),
        "primaryModel": primary_model.name,
        "quantization": quantization,
        "modelSha256": sha256_file(primary_model),
        "confidenceTemperature": round(float(confidence_temperature), 6),
    }
    if calibration is not None:
        payload["calibration"] = calibration
    write_json(path, payload)


def copy_mobile_assets(
    *,
    flutter_assets_dir: Path,
    primary_model: Path,
    class_names_path: Path,
    nutrition_path: Path,
) -> None:
    models_dir = flutter_assets_dir / "models"
    data_dir = flutter_assets_dir / "data"
    models_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(primary_model, models_dir / "food_classifier.tflite")
    shutil.copy2(class_names_path, data_dir / "class_names.json")
    shutil.copy2(nutrition_path, data_dir / "nutrition_data.json")
    print(f"[flutter] Copied TFLite model and JSON metadata to {flutter_assets_dir.resolve()}")


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
def parse_args(argv: Iterable[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA_DIR)
    parser.add_argument(
        "--val-dir",
        type=Path,
        default=None,
        help="Optional pre-split validation directory with the same classes as --data-dir.",
    )
    parser.add_argument("--test-dir", type=Path, default=None)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--model", choices=("mobilenetv3_small", "mobilenetv3_large"), default="mobilenetv3_small")
    parser.add_argument("--weights", choices=("imagenet", "none"), default="imagenet")
    parser.add_argument("--val-split", type=float, default=0.2)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--initial-epochs", type=int, default=15)
    parser.add_argument("--fine-tune-epochs", type=int, default=5)
    parser.add_argument("--fine-tune-layers", type=int, default=30)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--fine-tune-learning-rate", type=float, default=1e-5)
    parser.add_argument("--dropout", type=float, default=0.3)
    parser.add_argument("--dense-units", type=int, default=256)
    parser.add_argument("--label-smoothing", type=float, default=0.05)
    parser.add_argument("--patience", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--cache", action="store_true", help="Cache decoded training pixels in RAM.")
    parser.add_argument("--class-weights", action="store_true", help="Balance classes by inverse frequency.")
    parser.add_argument(
        "--quantization",
        choices=("dynamic", "fp16", "both"),
        default="dynamic",
        help="Post-training quantization mode. 'both' exports dynamic + FP16.",
    )
    parser.add_argument(
        "--primary-quantization",
        choices=("auto", "dynamic", "fp16"),
        default="auto",
        help="Variant copied to food_classifier.tflite. 'auto' picks the best validation macro-F1.",
    )
    parser.add_argument("--model-version", default="1.0.0")
    parser.add_argument("--nutrition-seed", type=Path, default=DEFAULT_SEED_PATH)
    parser.add_argument(
        "--flutter-assets-dir",
        type=Path,
        default=None,
        help="Optional Flutter assets/ directory to receive model + JSON files.",
    )
    parser.add_argument(
        "--tflite-eval-samples",
        type=int,
        default=0,
        help="Validation images used to audit TFLite variants; 0 = all validation images.",
    )
    return parser.parse_args(argv)


def main(argv: Iterable[str] | None = None) -> int:
    args = parse_args(argv)
    args.data_dir = args.data_dir.resolve()
    args.output_dir = args.output_dir.resolve()
    args.nutrition_seed = args.nutrition_seed.resolve()
    if args.val_dir is not None:
        args.val_dir = args.val_dir.resolve()
    if args.test_dir is not None:
        args.test_dir = args.test_dir.resolve()
    if args.val_dir is None and not 0.05 <= args.val_split <= 0.5:
        print("[train] ERROR: --val-split must be between 0.05 and 0.5.", file=sys.stderr)
        return 2

    started = time.time()
    set_global_seed(args.seed)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    gpus = tf.config.list_physical_devices("GPU")
    if gpus:
        try:
            for gpu in gpus:
                tf.config.experimental.set_memory_growth(gpu, True)
        except RuntimeError:
            pass
    print(f"[env] TensorFlow {tf.__version__}; GPUs: {[gpu.name for gpu in gpus] or 'none'}")

    try:
        train_ds, val_ds, test_ds, class_names, train_counts = build_datasets(
            args.data_dir,
            val_split=args.val_split,
            batch_size=args.batch_size,
            seed=args.seed,
            cache=args.cache,
            test_dir=args.test_dir,
            val_dir=args.val_dir,
        )

        model, base = build_model(
            num_classes=len(class_names),
            variant=args.model,
            weights=args.weights,
            dropout=args.dropout,
            dense_units=args.dense_units,
        )

        weights = class_weights_from_counts(Counter(train_counts), class_names) if args.class_weights else None
        history_initial, history_finetune, final_model_path, selected_stage = train_model(
            model,
            base,
            train_ds,
            val_ds,
            args,
            class_weights=weights,
        )

        _save_training_curves(history_initial, history_finetune, args.output_dir / "training_curves.png")
        write_json(
            args.output_dir / "training_history.json",
            {
                "initial": _history_to_json(history_initial),
                "fineTune": _history_to_json(history_finetune) if history_finetune else None,
                "selectedStage": selected_stage,
                "model": args.model,
                "weights": args.weights,
                "seed": args.seed,
            },
        )

        # Validation is the only split used to choose a model or quantization.
        # The held-out test split is touched once, after selection is final.
        validation_evaluation = evaluate_model(
            model,
            val_ds,
            class_names,
            split_name="validation",
            output_dir=args.output_dir,
        )

        # Export quantized variants. The app always consumes food_classifier.tflite.
        modes = ["dynamic", "fp16"] if args.quantization == "both" else [args.quantization]
        tflite_reports: dict[str, Any] = {}
        exported_paths: dict[str, Path] = {}
        audit_limit = None if args.tflite_eval_samples <= 0 else max(16, args.tflite_eval_samples)
        for mode in modes:
            path = args.output_dir / f"food_classifier_{mode}.tflite"
            convert_to_tflite(model, mode, path)
            audit = audit_tflite(
                path,
                model,
                val_ds,
                class_names,
                sample_limit=audit_limit,
                mode=mode,
            )
            audit["evaluationSplit"] = "validation"
            tflite_reports[mode] = audit
            exported_paths[mode] = path

        if args.primary_quantization == "auto":
            best_macro_f1 = max(
                report["macroF1"] for report in tflite_reports.values()
            )
            # Quantization differences smaller than 0.5 pp are within validation
            # noise. In a tie, prefer the variant that reproduces Keras exactly
            # (higher agreement), then accuracy, then the smaller file.
            finalists = [
                mode
                for mode, report in tflite_reports.items()
                if best_macro_f1 - report["macroF1"] <= 0.005
            ]
            primary_mode = max(
                finalists,
                key=lambda mode: (
                    tflite_reports[mode]["agreementWithKeras"],
                    tflite_reports[mode]["accuracy"],
                    -tflite_reports[mode]["sizeBytes"],
                ),
            )
            selection_reason = (
                f"validation macro-F1 within 0.5 pp of best; chose highest "
                f"Keras agreement ({tflite_reports[primary_mode]['agreementWithKeras']:.4f})"
            )
        else:
            if args.primary_quantization not in exported_paths:
                raise ValueError(
                    f"--primary-quantization={args.primary_quantization} was requested, "
                    f"but --quantization only exported: {sorted(exported_paths)}."
                )
            primary_mode = args.primary_quantization
            selection_reason = "explicit --primary-quantization"
        primary_model = exported_paths[primary_mode]
        print(
            f"[select] Primary app model: {primary_mode} ({primary_model.name}); "
            f"{selection_reason}"
        )
        app_model_path = args.output_dir / "food_classifier.tflite"
        shutil.copy2(primary_model, app_model_path)

        # Fit confidence calibration on validation probabilities from the exact
        # TFLite artifact that ships in the app (not on test data).
        val_images, val_labels = _model_samples(val_ds, None)
        primary_val_probabilities = _tflite_probability_matrix(app_model_path, val_images)
        confidence_temperature = _fit_temperature(primary_val_probabilities, val_labels)
        validation_ece_before = _expected_calibration_error(
            primary_val_probabilities, val_labels
        )
        validation_calibrated = _apply_temperature_np(
            primary_val_probabilities, confidence_temperature
        )
        validation_ece_after = _expected_calibration_error(validation_calibrated, val_labels)
        print(
            f"[calibration] T={confidence_temperature:.3f}; validation ECE "
            f"{validation_ece_before:.4f} -> {validation_ece_after:.4f}"
        )

        # Final, single evaluation on the held-out test split. If no test split
        # was supplied, the report explicitly marks validation as non-independent.
        if test_ds is not None:
            evaluation = evaluate_model(
                model,
                test_ds,
                class_names,
                split_name="test",
                output_dir=args.output_dir,
            )
            tflite_test_evaluation = evaluate_tflite_model(
                app_model_path,
                test_ds,
                class_names,
                split_name="test",
                output_dir=args.output_dir,
                temperature=confidence_temperature,
            )
            evaluation_split = "test"
            evaluation_is_independent = True
        else:
            evaluation = validation_evaluation
            tflite_test_evaluation = evaluate_tflite_model(
                app_model_path,
                val_ds,
                class_names,
                split_name="validation",
                output_dir=args.output_dir,
                temperature=confidence_temperature,
            )
            evaluation_split = "validation"
            evaluation_is_independent = False

        calibration_report = {
            "method": "temperature_scaling",
            "fitSplit": "validation",
            "temperature": float(confidence_temperature),
            "validation": {
                "samples": int(len(val_labels)),
                "expectedCalibrationErrorBefore": float(validation_ece_before),
                "expectedCalibrationErrorAfter": float(validation_ece_after),
            },
            "test": {
                "independent": evaluation_is_independent,
                "expectedCalibrationErrorBefore": float(
                    tflite_test_evaluation["metricsRaw"]["expectedCalibrationError"]
                ),
                "expectedCalibrationErrorAfter": float(
                    tflite_test_evaluation["temperatureScaled"][
                        "expectedCalibrationError"
                    ]
                ),
            },
        }

        class_names_path = args.output_dir / "class_names.json"
        write_class_names(
            class_names_path,
            class_names=class_names,
            model_version=args.model_version,
            primary_model=app_model_path,
            quantization=primary_mode,
            confidence_temperature=confidence_temperature,
            calibration=calibration_report,
        )

        nutrition_path = args.output_dir / "nutrition_data.json"
        nutrition_catalog: dict[str, Any] | None = None
        if args.nutrition_seed.exists():
            nutrition_catalog = generate_nutrition_data_file(
                class_names_path=class_names_path,
                seed_path=args.nutrition_seed,
                output_path=nutrition_path,
                model_version=args.model_version,
                model_path=app_model_path,
            )
        else:
            print(
                f"[metadata] WARNING: nutrition seed not found at {args.nutrition_seed}; "
                "skipping nutrition_data.json.",
                file=sys.stderr,
            )

        report = {
            "createdAt": utc_now_iso(),
            "modelVersion": args.model_version,
            "architecture": args.model,
            "pretrainedWeights": args.weights,
            "selectedStage": selected_stage,
            "classNames": class_names,
            "classCount": len(class_names),
            "trainingConfiguration": {
                "inputSize": IMAGE_SIZE,
                "batchSize": args.batch_size,
                "initialEpochs": args.initial_epochs,
                "fineTuneEpochs": args.fine_tune_epochs,
                "fineTuneLayers": args.fine_tune_layers,
                "dropout": args.dropout,
                "labelSmoothing": args.label_smoothing,
                "valSplit": args.val_split if args.val_dir is None else None,
                "valDir": str(args.val_dir) if args.val_dir is not None else None,
                "testDir": str(args.test_dir.resolve()) if args.test_dir is not None else None,
                "classWeights": args.class_weights,
                "seed": args.seed,
                "trainSamples": int(sum(train_counts.values())),
                "tfliteAuditSamples": audit_limit if audit_limit is not None else "all-validation",
            },
            "validationEvaluation": validation_evaluation,
            "evaluationSplit": evaluation_split,
            "evaluationIsIndependent": evaluation_is_independent,
            "evaluation": evaluation,
            "tflite": tflite_reports,
            "tfliteTestEvaluation": tflite_test_evaluation,
            "calibration": calibration_report,
            "primaryModel": app_model_path.name,
            "primaryQuantization": primary_mode,
            "primaryQuantizationPolicy": (
                f"{args.primary_quantization}; auto uses validation macro-F1 with a "
                "0.5 pp tie window, then Keras agreement, accuracy, and size"
            ),
            "primaryQuantizationSelection": selection_reason,
            "finalKerasModel": final_model_path.name,
            "nutritionCatalog": {
                "path": nutrition_path.name if nutrition_catalog else None,
                "classes": nutrition_catalog["classCount"] if nutrition_catalog else 0,
                "warnings": nutrition_catalog["warnings"] if nutrition_catalog else [],
            },
            "durationSeconds": round(time.time() - started, 2),
            "notes": [
                "Model, fine-tuning stage, and quantization were selected on the validation split only.",
                "The held-out test split was evaluated once after model selection was final.",
                "95% confidence intervals are percentile bootstrap intervals from the reported split.",
                "TFLite latency is measured on desktop CPU and must be re-benchmarked on target devices.",
                "Nutrition values are estimates and are not medical advice.",
            ],
        }
        write_json(args.output_dir / "model_report.json", report)

        if args.flutter_assets_dir is not None:
            copy_mobile_assets(
                flutter_assets_dir=args.flutter_assets_dir.resolve(),
                primary_model=app_model_path,
                class_names_path=class_names_path,
                nutrition_path=nutrition_path,
            )

        print("\n" + "=" * 72)
        print("[done] NutriScan export complete")
        print(f"  Keras model       : {final_model_path}")
        print(f"  App TFLite model  : {app_model_path} ({primary_mode})")
        for mode, path in exported_paths.items():
            print(f"  {mode:<8} variant : {path}")
        print(f"  Labels            : {class_names_path}")
        if nutrition_catalog is not None:
            print(f"  Nutrition catalog : {nutrition_path}")
        print(f"  Full report       : {args.output_dir / 'model_report.json'}")
        print("=" * 72)
        return 0

    except (FileNotFoundError, ValueError, MetadataError, RuntimeError) as exc:
        print(f"\n[train] ERROR: {exc}", file=sys.stderr)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
