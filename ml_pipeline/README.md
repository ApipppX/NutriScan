# NutriScan ML pipeline

This directory contains the complete, reproducible training and export pipeline
that produces the artifacts consumed by the Flutter app:

```text
food photos -> train/validate -> MobileNetV3 transfer learning
             -> fine-tune -> evaluate -> TFLite quantization
             -> class_names.json + nutrition_data.json -> Flutter assets
```

The pipeline is intentionally strict about class order. A mismatch between the
model output index and a nutrition record would silently show the wrong food's
calories, so metadata generation fails instead of guessing.

---

## Current bundled model

| Item | Value |
| --- | --- |
| Classes | 14 (`Ayam Goreng`, `Bakso` … `Soto`) |
| Architecture | MobileNetV3-Large, ImageNet weights, 18 frozen + 10 fine-tune epochs (last 60 layers), dropout 0.35 |
| Dataset after deduplication and additions | 6,419 images: 5,488 train / 457 valid / 474 test (5,978 after deduplication + Mendeley additions, plus 441 Bakso) |
| Keras validation accuracy / macro F1 | **92.12% / 91.93%** |
| Keras held-out test accuracy | **93.04%** (95% CI 90.72–95.36%) |
| Keras macro F1 | **92.58%** (95% CI 89.82–94.83%) |
| Top-3 test accuracy | **98.95%** |
| FP16 TFLite full-test accuracy | **93.04%** (independently re-evaluated on all 474 test images) |
| Dynamic-range TFLite full-test accuracy | **92.83%** |
| Test calibration error (ECE) | 5.94% → **2.24%** with T = 0.70 |
| App model | FP16, **6.25 MiB** (validation-selected; 100% Keras agreement) |
| Metadata | 14 labels, zero nutrition warnings |

Model, fine-tuning stage, and quantization are selected on the validation split only.
The held-out test split is evaluated once after selection is final. FP16 had the
best validation macro-F1 and reproduced Keras exactly, so it was selected as the
app model. The dynamic-range variant remains available for size-constrained builds.

The original source images are not part of the repository. The 13-class base
dataset is the Kaggle *Indonesian Food Dataset* (MIT); the supplemental and Bakso
images come from Mendeley *Indonesian Food Image* (CC BY 4.0). These results
describe this dataset only; validate on your own target distribution before release.

---

## Files

| File | Purpose |
| --- | --- |
| `train_export.py` | End-to-end orchestrator: datasets, training, evaluation, conversion, audit, metadata, Flutter asset copy |
| `generate_nutrition_data.py` | Standalone strict label → nutrition catalog generator |
| `prepare_dummy_dataset.py` | Synthetic dataset generator for pipeline smoke tests only |
| `clean_dataset.py` | Global near-duplicate cleanup for pre-split datasets (dHash; hard links by default) |
| `merge_additions.py` | Safe external-data merge: copies an existing split, adds deduplicated images to train only |
| `add_class.py` | Add a new class to a pre-split dataset with dHash dedup and a deterministic train/valid/test split |
| `nutrition_seed.json` | Editable nutrition source values, per 100 g (or 100 ml) |
| `requirements.txt` | Pinned TensorFlow + evaluation dependencies |

---

## Environment

Tested with **Python 3.12.10**, **TensorFlow 2.21.0**, **Keras 3.15.1**.

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

pip install --upgrade pip
pip install -r ml_pipeline/requirements.txt
```

The first ImageNet run downloads MobileNetV3 weights (~4 MiB). Later runs use
the Keras cache.

> On native Windows, TensorFlow ≥ 2.11 runs on CPU only. That is sufficient for
> this pipeline; use WSL2 if you need CUDA.

---

## Dataset layout

The current dataset lives outside the repository:

```text
D:/Dataset Makanan 1GB/dataset_clean_mendeley_bakso/
  train/
    Ayam Goreng/0001.jpg
    Bakso/0001.jpg
    Burger/0001.jpg
    Nasi Goreng/0001.jpg
    ...
  valid/
  test/
```

A single folder-per-class source can also be used:

```text
D:/Dataset Makanan 1GB/dataset_gambar/
  Ayam Goreng/
    0001.jpg
    0002.jpg
  Burger/
    ...
```

Rules:

- One directory per class; the directory name is the model label.
- Supported extensions: `.jpg`, `.jpeg`, `.png`, `.bmp`, `.gif`, `.jfif`.
- At least **3 images per class** are required for a stratified train/validation
  split (more is strongly recommended; aim for hundreds per class for real use).
- Class folders are sorted alphabetically. That order becomes the model output
  order and the `class_names.json` order.
- An optional separate test directory can be supplied with `--test-dir`; it must
  contain exactly the same class folders.
- If the dataset already has `train`, `valid`, and `test` folders, pass
  `--data-dir .../train --val-dir .../valid --test-dir .../test` to use the
  existing split instead of splitting the training folder again.

### Existing train/valid/test split

```text
dataset/
  train/<class>/*.jpg
  valid/<class>/*.jpg
  test/<class>/*.jpg
```

Use:

```bash
python ml_pipeline/train_export.py \
  --data-dir dataset/train \
  --val-dir dataset/valid \
  --test-dir dataset/test \
  --output-dir ml_pipeline/output \
  --flutter-assets-dir assets
```

### Remove duplicate leakage

Scraped datasets often contain the same photo in multiple splits. That silently
inflates validation/test accuracy. `clean_dataset.py` groups near-identical
images globally with a 64-bit dHash and keeps one representative per group,
preferring train > test > valid. Cross-class near-duplicates are excluded as
ambiguous labels.

```bash
python ml_pipeline/clean_dataset.py \
  --input-dir "D:/Dataset/dataset_gambar" \
  --output-dir "D:/Dataset/dataset_clean" \
  --threshold 4
```

The source is never modified. On the same volume the output uses hard links by
default (no extra storage); add `--mode copy` if needed. Always use the cleaned
`train`/`valid`/`test` folders for training. The emitted `dataset_audit.json`
records counts per class and split.

### Add external images without touching the held-out split

`merge_additions.py` copies an existing train/valid/test dataset to a new
directory and adds matched external classes to **train only**. It checks every
candidate against all existing images and accepted additions with the same dHash
threshold, so a new training image cannot be a near-duplicate of the existing
validation or test set. The original dataset is never modified.

```bash
python ml_pipeline/merge_additions.py \
  --data-dir "D:/Dataset Makanan 1GB/dataset_clean" \
  --source-dir "D:/Dataset Makanan 1GB/external/mendeley/Indonesian Food Image/Original" \
  --output-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley" \
  --prefix mendeley \
  --max-per-class 200 \
  --threshold 4 \
  --mode copy \
  --source-name "Mendeley Indonesian Food Image" \
  --source-url "https://data.mendeley.com/datasets/vtjd68bmwt" \
  --license "CC BY 4.0"
```

Class folders are matched by normalized name (`Gado-Gado` == `gado_gado`).
Unmatched source classes are ignored. `--include-class` limits the merge to
specific labels, and `--max-per-class 0` disables the cap. The output contains
`merge_report.json` and `merge_added_files.json` for auditability. Use
`--dry-run` first to inspect counts.

The merge script removes near-duplicates, but it does **not** understand image
semantics. Public web datasets often contain product packaging, menu cards,
storefronts, people, and collages. Build a curated source folder and review
contact sheets before merging; otherwise those images become label noise even
though every file is a valid image.

### Add a new class

`add_class.py` is the counterpart to `merge_additions.py` for a class that is
not in the current model. It copies an existing train/valid/test dataset to a
new directory, deduplicates the new class against every existing image and
among the new images, and splits the accepted images into train/valid/test.
Existing splits are verified unchanged.

```bash
python ml_pipeline/add_class.py \
  --data-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley" \
  --source-dir "D:/Dataset Makanan 1GB/external/mendeley/curated_bakso/Bakso" \
  --class-name "Bakso" \
  --output-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley_bakso" \
  --val-split 0.1 \
  --test-split 0.1 \
  --threshold 4 \
  --mode hardlink \
  --source-name "Mendeley Indonesian Food Image" \
  --source-url "https://data.mendeley.com/datasets/vtjd68bmwt" \
  --license "CC BY 4.0"
```

Use `--dry-run` first. The output contains `add_class_report.json` and
`add_class_manifest.json`. The source folder is never modified; curate it and
review contact sheets before running the script. Update `nutrition_seed.json`
with a matching normalized key before retraining, otherwise metadata generation
fails loudly.

### Why not Keras' `validation_split`?

`image_dataset_from_directory(validation_split=...)` slices the globally sorted
file list. With folder-per-class data, that can put entire classes into one
split. This pipeline splits **each class independently** using a seeded RNG, so
every class is represented in train and validation.

The split is reproducible for a given `--seed` and `--val-split`. With 60 images
per class and `val_split=0.2`, each class contributes 48 train + 12 validation.

---

## Quick start with a synthetic smoke-test dataset

The previously generated dummy images have been removed. `prepare_dummy_dataset.py`
can still generate a throwaway set for fast pipeline/UI smoke tests. It is
**not** the training data behind the bundled model and must not be used for real
food recognition.

```bash
python ml_pipeline/prepare_dummy_dataset.py \
  --output ml_pipeline/dataset_dummy/raw \
  --images-per-class 60
```

Then train and export to a separate output folder:

```bash
python ml_pipeline/train_export.py \
  --data-dir ml_pipeline/dataset_dummy/raw \
  --output-dir ml_pipeline/output_dummy \
  --initial-epochs 8 \
  --fine-tune-epochs 3 \
  --fine-tune-layers 24 \
  --quantization both \
  --tflite-eval-samples 64 \
  --flutter-assets-dir assets
```

On a CPU-only laptop this run is short because the synthetic images are easy.

## Reproducing the bundled real-data model

The 2.2.0 dataset is built by cleaning the original 13-class Kaggle set, merging
the curated Mendeley additions, and adding the curated Bakso class (commands above).
Then train:

```bash
python ml_pipeline/train_export.py \
  --data-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley_bakso/train" \
  --val-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley_bakso/valid" \
  --test-dir "D:/Dataset Makanan 1GB/dataset_clean_mendeley_bakso/test" \
  --output-dir ml_pipeline/output_bakso \
  --model mobilenetv3_large \
  --initial-epochs 18 \
  --fine-tune-epochs 10 \
  --fine-tune-layers 60 \
  --dropout 0.35 \
  --batch-size 32 \
  --patience 5 \
  --quantization both \
  --primary-quantization auto \
  --tflite-eval-samples 0 \
  --model-version 2.2.0 \
  --flutter-assets-dir assets
```

`--primary-quantization auto` compares variants on the validation split. If the
best validation macro-F1 candidates are within 0.5 pp, it prefers the variant
with the highest top-1 agreement with Keras, then accuracy, then the smaller
file. For this run FP16 had the best validation macro-F1 and matched Keras
exactly; the dynamic-range file remains available for size-constrained builds.
The test split is not used for this choice.

---

## Training design

### Model

- Backbone: `MobileNetV3Large` for the bundled model (or `MobileNetV3Small` for
  low-end/small-download builds), ImageNet weights, `include_top=False`,
  `include_preprocessing=False`.
- Head: `GlobalAveragePooling2D → Dense(256, ReLU, L2) → Dropout → Dense(N, softmax)`.
- Input: pixels normalized to `[-1, 1]` **before** the model. The app performs
  the same normalization, so no rescaling layer is hidden inside the TFLite
  graph.

### Stage 1 — frozen backbone

- Backbone frozen; only the classifier head trains.
- Adam, default LR `1e-3`, gradient clipping `1.0`.
- Sparse categorical cross-entropy with label smoothing `0.05`.
  Keras 3.15 removed `label_smoothing` from the sparse loss, so the pipeline
  provides `SparseCategoricalCrossentropyWithSmoothing` (registered as a Keras
  serializable).
- `ModelCheckpoint` and `EarlyStopping` monitor **validation macro-F1**, not raw
  accuracy, so each food class has equal weight in model selection. The pipeline
  also logs `ReduceLROnPlateau`, `TerminateOnNaN`, and CSV metrics.

### Stage 2 — fine-tuning (optional)

- Restores the best Stage 1 weights.
- Unfreezes the last `--fine-tune-layers` backbone layers.
- Keeps all BatchNormalization layers frozen (safer with small batches).
- Low LR (default `1e-5`), monitored separately.
- If fine-tuning does not beat Stage 1 validation macro-F1, Stage 1 weights are
  restored before export.

### Augmentation (training only)

Applied on decoded images in the 0..255 domain:

- horizontal flip
- rotation (`factor=0.08`)
- zoom (`±12%`)
- translation (`±6%`)
- random erasing (`20%` probability, `2–12%` area)
- brightness, contrast, saturation, hue jitter
- final mapping to `[-1, 1]`

Validation and test data are only center-cropped, resized, and normalized.

### Validation and test protocol

- The validation split drives checkpointing, fine-tuning stage selection, TFLite
  variant selection, and confidence-temperature fitting.
- The test split is evaluated once after all choices are frozen. `model_report.json`
  records the test split as independent.
- Accuracy and macro-F1 include percentile bootstrap 95% confidence intervals
  (1,000 resamples), plus top-3 accuracy, balanced accuracy, log loss, and
  expected calibration error (ECE).
- Confidence temperature is fitted on validation probabilities from the exact
  TFLite file that ships in the app, then applied on-device before top-k ranking.
  It changes confidence values, not the predicted class.
- TFLite audits use all 457 validation images by default, so a lucky 100-image
  sample cannot decide the app model.

---

## Quantization

Both exports keep **float32 input and output**, so the mobile preprocessing
contract never changes.

| Mode | Flag | Size (current model) | Use |
| --- | --- | --- | --- |
| Dynamic-range | `--quantization dynamic` | ~3.4 MiB | Smallest option; weights quantized, activations computed dynamically |
| FP16 | `--quantization fp16` | ~6.25 MiB | Higher-fidelity option; current bundled app model |
| Both | `--quantization both` | both files | Audit both on validation, then let `--primary-quantization auto` pick the app model |

Full-integer quantization is deliberately not used because it would require a
representative calibration dataset and an int8/zero-point contract on the
Flutter side. The exported variants are audited on the validation split for:

- input shape `[1, 224, 224, 3]`, dtype float32
- output shape `[1, N]`, dtype float32
- quantized accuracy, macro-F1, and balanced accuracy vs. Keras
- top-1 agreement with Keras
- expected calibration error
- desktop CPU latency (median / p95)

The primary choice never uses test data. Results are written to `model_report.json`.

---

## Metadata contract

### `class_names.json`

```json
{
  "schemaVersion": 1,
  "modelVersion": "1.0.0",
  "input": {
    "width": 224,
    "height": 224,
    "channels": 3,
    "colorOrder": "RGB",
    "normalization": "[-1,1]"
  },
  "labels": ["Ayam Goreng", "Burger", "French Fries"],
  "classCount": 3,
  "primaryModel": "food_classifier.tflite",
  "quantization": "fp16",
  "modelSha256": "...",
  "confidenceTemperature": 0.70,
  "calibration": {
    "method": "temperature_scaling",
    "fitSplit": "validation",
    "validation": {
      "expectedCalibrationErrorBefore": 0.0673,
      "expectedCalibrationErrorAfter": 0.0430
    },
    "test": {
      "independent": true,
      "expectedCalibrationErrorBefore": 0.0616,
      "expectedCalibrationErrorAfter": 0.0224
    }
  }
}
```

Labels are in model output order. The app validates uniqueness and count against
the TFLite output tensor at startup. It reads `confidenceTemperature` (default
`1.0` for old metadata), applies `p^(1/T) / sum(p^(1/T))` to the full probability
vector in the inference isolate, and only then ranks the top-k classes. This
keeps the predicted class unchanged while making the displayed confidence closer
to observed accuracy.

### `nutrition_data.json`

One record per class, ordered by model index:

```json
{
  "schemaVersion": 1,
  "modelVersion": "1.0.0",
  "modelSha256": "...",
  "referenceAmount": 100,
  "referenceUnit": "g",
  "provenance": {
    "sourceType": "estimation",
    "sourceCode": "TKPI-2017;USDA-FDC-173292;USDA-FDC-170698;STANDARD-RECIPE",
    "sourcePage": "multiple",
    "sourceUrl": "https://repository.kemkes.go.id/book/668",
    "verifiedAt": "2026-10-28",
    "note": "Universal estimate; add per-item provenance before publication."
  },
  "classes": [
    {
      "index": 0,
      "label": "Ayam Goreng",
      "normalizedLabel": "ayam_goreng",
      "displayName": "Ayam Goreng",
      "emoji": "🍗",
      "category": "main",
      "aliases": ["ayam goreng", "fried chicken"],
      "defaultPortionGrams": 150,
      "nutritionPer100g": {
        "caloriesKcal": 283.0,
        "proteinG": 35.4,
        "carbohydrateG": 0.9,
        "fatG": 14.2,
        "fiberG": 0.0,
        "sodiumMg": 681.0
      }
    }
  ],
  "warnings": [],
  "disclaimer": "..."
}
```

`nutrition_seed.json` keys are normalized (lowercase, non-alphanumerics → `_`),
so `"Nasi Goreng"` and `nasi_goreng` match. Missing classes abort generation.
Unused seed entries produce warnings. If `provenance` is present, the generator
requires `sourceType`, `sourceCode`, `sourcePage`, `sourceUrl`, and `verifiedAt`,
then copies the block into the catalog. The block is universal; it does not
replace per-item source codes or documented recipes.

### Updating nutrition data manually

```bash
python ml_pipeline/generate_nutrition_data.py \
  --class-names ml_pipeline/output_bakso/class_names.json \
  --seed ml_pipeline/nutrition_seed.json \
  --output ml_pipeline/output_bakso/nutrition_data.json \
  --model-version 2.2.0 \
  --model-path ml_pipeline/output_bakso/food_classifier.tflite
```

Then copy the JSON to `assets/data/` (or rerun `train_export.py`, which copies it
when `--flutter-assets-dir assets` is provided).

---

## CLI reference

Run `python ml_pipeline/train_export.py --help` for the full list.

| Flag | Default | Notes |
| --- | --- | --- |
| `--data-dir` | `ml_pipeline/dataset/raw` | Folder-per-class training dataset |
| `--val-dir` | none | Optional pre-split validation directory; overrides `--val-split` |
| `--test-dir` | none | Optional held-out test set with identical classes |
| `--output-dir` | `ml_pipeline/output` | Reports, checkpoints, TFLite, JSON |
| `--model` | `mobilenetv3_small` | Or `mobilenetv3_large`; the bundled model uses Large |
| `--weights` | `imagenet` | `none` for offline/no-download smoke runs |
| `--val-split` | `0.2` | Per-class fraction, `0.05..0.5` |
| `--batch-size` | `32` | |
| `--initial-epochs` | `15` | Frozen-backbone stage (bundled run: 18) |
| `--fine-tune-epochs` | `5` | Set `0` to skip fine-tuning (bundled run: 10) |
| `--fine-tune-layers` | `30` | Number of last backbone layers to unfreeze (bundled run: 60) |
| `--learning-rate` | `1e-3` | Stage 1 |
| `--fine-tune-learning-rate` | `1e-5` | Stage 2 |
| `--dropout` | `0.3` | Bundled run: `0.35` |
| `--dense-units` | `256` | |
| `--label-smoothing` | `0.05` | |
| `--patience` | `5` | EarlyStopping patience on validation macro-F1 |
| `--seed` | `42` | Split/shuffle/init seed |
| `--cache` | off | Cache decoded training pixels in RAM |
| `--class-weights` | off | Inverse-frequency class weights |
| `--quantization` | `dynamic` | `dynamic`, `fp16`, or `both` |
| `--primary-quantization` | `auto` | `auto`, `dynamic`, or `fp16`; auto uses validation macro-F1 with a 0.5 pp tie window, then Keras agreement |
| `--model-version` | `1.0.0` | Stored in metadata; bundled model is `2.2.0` |
| `--nutrition-seed` | `ml_pipeline/nutrition_seed.json` | Editable source |
| `--flutter-assets-dir` | none | Copy model + JSON into a Flutter `assets/` folder |
| `--tflite-eval-samples` | `0` | Validation images used for TFLite audit; `0` = all validation images |

---

## Output artifacts

```text
output/
  best_model.keras                     # best overall Keras model
  food_classifier.tflite               # primary app model (validation-selected; FP16 here)
  food_classifier_dynamic.tflite
  food_classifier_fp16.tflite
  class_names.json                     # labels, model hash, calibration temperature
  nutrition_data.json
  model_report.json                    # validation/test metrics, CIs, calibration, latency
  training_history.json
  training_curves.png
  validation_classification_report.txt
  validation_confusion_matrix.png
  test_classification_report.txt       # validation_* when using --val-split only
  test_confusion_matrix.png
  test_tflite_classification_report.txt
  test_tflite_confusion_matrix.png
  metrics_initial.csv
  metrics_finetune.csv
  checkpoints/
```

If `--flutter-assets-dir assets` is used, the app receives:

```text
assets/models/food_classifier.tflite
assets/data/class_names.json
assets/data/nutrition_data.json
```

Rebuild the Flutter app after copying new artifacts.

---

## Adding new food classes

1. Curate a folder of real images and review indexed contact sheets. Drop
   non-food, menu/packaging, cooking-process, and ambiguous shots.
2. Run `add_class.py` against the current split dataset (see the example above).
   It deduplicates every candidate against the existing images, splits the new
   class into train/valid/test, and leaves the existing splits unchanged.
3. Add a matching record to `nutrition_seed.json` with the same normalized key.
4. Retrain.
5. Verify no nutrition warnings in the console / `model_report.json`.
6. Rebuild the app.

Do not rename class folders without regenerating both JSON files; the app maps
model indices to nutrition records at startup.

---

## Interpreting metrics

- The bundled model scores **93.04%** on the cleaned 474-image test split
  (macro F1 **92.58%**, top-3 **98.95%**, 95% CI 90.72–95.36%). Validation
  accuracy/macro-F1 is **92.12% / 91.93%**. This is not a universal
  food-recognition benchmark.
- The test split has only 474 images, so a 1-image difference is about 0.21 pp.
  Prefer the confidence interval and per-class report over tiny ranking changes.
- The original 13-class Kaggle dataset had **1,487 duplicate/leakage images** removed (6,500 →
  5,013) before training. The curated Mendeley additions add 965 images
  (5,978 total), and the 14-class Bakso set adds 441 more (6,419 total).
- Full-test TFLite audit: FP16 **93.04%**, dynamic-range **92.83%**. The pipeline
  selected FP16 as the app model. Temperature scaling (T = 0.70) reduced test
  expected calibration error from 5.94% to 2.24%. See `model_report.json` for the
  conversion audit and per-mode latency.
- Check the confusion matrix and per-class precision/recall, not only overall
  accuracy. In this run the weakest classes were Ayam Goreng (F1 0.83), Nasi
  Padang (F1 0.83), and Rendang (F1 0.87). Bakso reached F1 0.95 on 44 test
  images.
- TFLite accuracy is measured against Keras on the same samples; the top-1
  agreement column catches conversion regressions.
- Desktop latency is not phone latency. Benchmark on low-, mid-, and high-end
  Android devices, including thermal throttling.

---

## Troubleshooting

**`Validation split left classes without samples`** — obsolete in this pipeline;
splits are stratified per class. If you see a related error, check that every
class has at least 3 images.

**`No module named tensorflow`** — activate the virtual environment and install
`ml_pipeline/requirements.txt`.

**Unicode/emoji console errors on Windows** — set UTF-8 output:
`$env:PYTHONIOENCODING='utf-8'` (PowerShell) before running the script.

**Metadata generation fails with a missing label** — add that class to
`nutrition_seed.json`; keys are normalized, so `"Nasi Goreng"` matches
`nasi_goreng`.

**TFLite conversion fails** — keep TensorFlow pinned to 2.21.0. Unsupported ops
can also appear when changing the backbone; check the converter error and keep
`TFLITE_BUILTINS` supported ops.

**Flutter app cannot load the model** — confirm the three asset paths exist,
`flutter pub get` was run, and `noCompress += "tflite"` is present in
`android/app/build.gradle.kts`. `tflite_flutter` requires `minSdk 26`.

**Model outputs the wrong class order** — regenerate `class_names.json` and
`nutrition_data.json` together. Never edit the array order by hand.

---

## Production checklist

- [x] Train on real, folder-per-class food photos.
- [x] Hold out a test set that was never used for training or model selection.
- [x] Remove duplicate leakage and audit the TFLite conversion.
- [ ] Confirm the dataset license permits the intended distribution/use.
- [ ] Add per-item nutrition provenance (source code/page or recipe/yield) before publication; the current catalog uses a universal estimation block.
- [ ] Benchmark TFLite on real low/mid/high-end phones.
- [ ] Add release signing, versioning, and model hash verification to CI.
- [ ] Keep `class_names.json`, `nutrition_data.json`, and the TFLite model in sync.
- [ ] Review the medical/legal disclaimer with your team.
