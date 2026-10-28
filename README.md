# NutriScan

NutriScan is a fully offline food image classifier and nutrition estimator:

- **Flutter app** (Android/iOS) that picks or captures a photo, classifies it with an on-device TFLite model, and shows calories + macronutrients per adjustable portion.
- **Python/TensorFlow pipeline** that transfer-trains MobileNetV3, evaluates it, exports dynamic-range and FP16 TFLite variants, and generates the label/nutrition metadata the app consumes.

No image ever leaves the device. The Android manifest intentionally declares no `INTERNET` permission.

> **Model data:** the bundled model was trained on a **13-class food dataset** supplied for this project. The source images are not included in this repository. Verify dataset licensing, nutrition values, and real-world accuracy before shipping.

---

## What is included

| Area | Details |
| --- | --- |
| Model | MobileNetV3-Large, ImageNet weights, frozen-backbone transfer learning + fine-tune |
| Input | `float32 [1, 224, 224, 3]`, RGB, normalized to `[-1, 1]` |
| Output | `float32 [1, 13]` softmax probabilities, confidence-calibrated on-device |
| App model | FP16 TFLite, **6.25 MiB**, selected on validation macro-F1 + Keras-agreement tie-break |
| Optional model | Dynamic-range TFLite, **3.41 MiB** |
| Labels | Alphabetical class-folder order, mirrored by `class_names.json` |
| Nutrition | Per-100 g values in `nutrition_data.json`, indexed to model outputs |
| Inference | Long-lived background isolate; no per-scan interpreter reload |
| UI | Material 3, Indonesian copy, light/dark theme, idle/loading/success/error states |
| Result experience | Animated macro donut, confidence percentage bar, retake action, portion stepper with quick presets, complete per-serving facts |
| Localization | English/snake_case model labels mapped to Indonesian names (`fried_noodles` → `Olahan Mie`) |
| Daily diary | Offline breakfast/lunch/dinner/snack log with localized names and per-portion nutrition |
| Tests | 39 unit/widget tests + one Android device integration test |

Classes: `Ayam Goreng`, `Burger`, `French Fries`, `Gado-Gado`, `Ikan Goreng`, `Mie Goreng`, `Nasi Goreng`, `Nasi Padang`, `Pizza`, `Rawon`, `Rendang`, `Sate`, `Soto`.

### Current model performance

Measured on the held-out, deduplicated test split (430 images):

| Metric | Value |
| --- | --- |
| Keras test accuracy | **93.72%** (95% CI 91.40–96.05%) |
| Keras macro F1 | **93.22%** |
| Top-3 test accuracy | **98.60%** |
| FP16 TFLite full-test accuracy | **93.72%** |
| Dynamic-range TFLite full-test accuracy | **92.56%** |
| Test calibration error (ECE) | 6.16% → **2.24%** after temperature scaling |
| FP16 / dynamic size | 6.25 / 3.41 MiB |

The FP16 app model reproduces Keras exactly on validation (100% top-1 agreement). Model, fine-tuning stage, and quantization were selected on the validation split only; the held-out test split was evaluated after selection was final. The larger MobileNetV3-Large model raises Keras test accuracy by about 4 points over the earlier Small model, at the cost of a larger download (6.25 MiB vs 2.16 MiB).

These numbers describe this dataset, not universal food recognition accuracy. See [`ml_pipeline/README.md`](ml_pipeline/README.md) for per-class results and the deduplication protocol.

---

## Project layout

```text
.
├── assets/
│   ├── data/
│   │   ├── class_names.json          # model version + ordered labels
│   │   └── nutrition_data.json       # index -> per-100g nutrition record
│   └── models/
│       └── food_classifier.tflite    # FP16 primary (validation-selected tie-break)
├── lib/
│   ├── app.dart                      # MaterialApp, Indonesian localization
│   ├── main.dart                     # ProviderScope entrypoint
│   ├── bootstrap/
│   │   └── app_bootstrap_gate.dart   # splash / retry while model loads
│   ├── core/                         # theme, constants, errors, logging, formatters, localization
│   └── features/
│       ├── daily_diary/
│       │   ├── domain/               # MealType, DiaryEntry, DiaryRepository contract
│       │   ├── data/                 # in-memory diary repository
│       │   └── presentation/         # DiaryController + meal category sheet
│       └── food_scan/
│           ├── domain/               # entities, repository contracts, ScanFoodUseCase
│           ├── data/
│           │   ├── datasources/      # asset-backed nutrition catalog
│           │   ├── ml/               # image preprocessing + inference isolate
│           │   ├── models/           # JSON DTOs
│           │   ├── repositories/     # in-memory nutrition repository
│           │   └── services/         # image picker + TFLite classifier
│           └── presentation/
│               ├── controllers/      # ScanController (portion + scan state)
│               ├── providers/        # dependency wiring + bootstrap provider
│               ├── screens/          # ScannerScreen + diary action bar
│               ├── state/            # sealed ScanState
│               └── widgets/          # result card, macro donut, confidence, portion, sheets
├── ml_pipeline/
│   ├── train_export.py               # end-to-end train/evaluate/convert/export
│   ├── generate_nutrition_data.py    # strict label -> nutrition catalog generator
│   ├── clean_dataset.py              # global near-duplicate cleanup for pre-split data
│   ├── prepare_dummy_dataset.py      # optional synthetic smoke-test generator
│   ├── nutrition_seed.json           # editable nutrition source values
│   ├── requirements.txt
│   └── README.md                     # pipeline deep dive
├── test/                             # unit + widget tests
├── integration_test/                 # real-device TFLite smoke test
├── ios/                              # camera/photo usage descriptions
└── android/                          # minSdk 26, tflite noCompress, ABI filters
```

Dependency rule: `presentation -> domain <- data`. Widgets never touch TFLite or JSON directly.

---

## Run the app

Requirements: Flutter 3.47+ / Dart 3.13+, Android API 26+ or iOS 13+.

```bash
flutter pub get
flutter run
```

The app loads the model and nutrition catalog during a bootstrap splash. Once ready:

1. Tap **Kamera** or **Galeri**.
2. The scanning line animates while inference runs in a background isolate.
3. Review the localized food name, AI confidence bar, macro donut, and all per-serving values (calories, protein, carbs, fat, fiber, sodium).
4. Adjust the portion with the stepper or the ½/1/1½/2-portion presets; every value recalculates instantly.
5. Tap **Simpan ke Diary**, choose **Sarapan / Makan Siang / Makan Malam / Camilan**, and confirm.
6. If confidence is low, tap **Foto Ulang** for a better shot or pick an alternative prediction.

No network is required after installation.

### New in `feature/nutrition-result-diary`

- **Localized labels:** `FoodLabelLocalizer` normalizes model labels (`Fried Noodles`, `fried-noodles`, `fried_noodles`) and maps them to Indonesian names such as **Olahan Mie**.
- **Confidence bar:** the result card shows a percentage bar with a high/medium/low level; below 60% it reveals an inline **Foto Ulang** action.
- **Live portion modifier:** the stepper is backed by `ScanController`, so the result card and the sticky diary bar always show the same recalculated nutrition.
- **Daily diary:** the sticky bottom bar opens a meal-category sheet and stores a `DiaryEntry` through `DiaryController` and `DiaryRepository`. The current implementation is in-memory and ready to be swapped for sqflite.

### Build

```bash
flutter build apk --release --split-per-abi
# or
flutter build appbundle --release
```

Before release, replace the debug signing config in `android/app/build.gradle.kts` with your own keystore.

---

## Retrain / replace the model

The pipeline is designed for a folder-per-class dataset:

```text
D:/Dataset Makanan 1GB/dataset_gambar/
  Ayam Goreng/0001.jpg
  Burger/0001.jpg
  Nasi Goreng/0001.jpg
  ...
```

At least 3 images per class are required. A stratified split is made **per class** so every class appears in both train and validation (Keras' built-in `validation_split` can put entire classes into one split).

If the dataset already has `train`, `valid`, and `test` folders, use them directly:

```text
D:/Dataset Makanan 1GB/dataset_clean/
  train/<class>/*.jpg
  valid/<class>/*.jpg
  test/<class>/*.jpg
```

The current training dataset stays **outside the repository** at
`D:\Dataset Makanan 1GB\dataset_clean`. The pipeline reads it in place and does
not copy the images into the project; only the trained model and metadata are
written to `ml_pipeline/output` and `assets`.

Scraped data often contains the same photo in multiple splits, which inflates evaluation. The included cleaner groups near-duplicates globally with a perceptual dHash, keeps one representative per group, and excludes cross-class collisions. It uses hard links by default, so it does not modify or duplicate the source files.

```bash
python ml_pipeline/clean_dataset.py \
  --input-dir "D:/Dataset Makanan 1GB/dataset_gambar" \
  --output-dir "D:/Dataset Makanan 1GB/dataset_clean" \
  --threshold 4
```

The generated `dataset_audit.json` records counts per class and split.

### 1. Install the ML environment

Python 3.12 is tested (TensorFlow 2.21 / Keras 3.15).

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -r ml_pipeline/requirements.txt
```

### 2. (Optional) regenerate the synthetic smoke-test dataset

The generated dummy data has been removed. `prepare_dummy_dataset.py` remains
only for fast pipeline smoke tests; it is **not** the bundled model's training
data. Regenerate it only when you need a throwaway dataset:

```bash
python ml_pipeline/prepare_dummy_dataset.py \
  --output ml_pipeline/dataset_dummy/raw \
  --images-per-class 60
```

### 3. Train and export

Run from the repository root. The command below uses the existing split; omit `--val-dir` and `--test-dir` to let the pipeline create a stratified split from a single folder.

```bash
python ml_pipeline/train_export.py \
  --data-dir "D:/Dataset Makanan 1GB/dataset_clean/train" \
  --val-dir "D:/Dataset Makanan 1GB/dataset_clean/valid" \
  --test-dir "D:/Dataset Makanan 1GB/dataset_clean/test" \
  --output-dir ml_pipeline/output \
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
  --model-version 2.0.0 \
  --flutter-assets-dir assets
```

`--primary-quantization auto` selects on validation only: the best validation macro-F1 wins, and if candidates are within 0.5 percentage points, the variant with the highest Keras agreement is preferred. For this run FP16 and dynamic-range were within that tie window, so FP16 (100% Keras agreement) was copied to `food_classifier.tflite`. The test split is then evaluated once as a final check.

`--tflite-eval-samples 0` audits every validation image instead of a random subset. Set a positive number only for quicker smoke runs.

This produces:

```text
ml_pipeline/output/
  best_model.keras
  food_classifier.tflite          # app primary (auto-selected, FP16 here)
  food_classifier_dynamic.tflite
  food_classifier_fp16.tflite
  class_names.json
  nutrition_data.json
  model_report.json               # validation/test metrics, calibration, latency, hashes
  training_curves.png
  validation_classification_report.txt
  test_classification_report.txt
  test_tflite_classification_report.txt
  test_confusion_matrix.png
  test_tflite_confusion_matrix.png
  metrics_initial.csv / metrics_finetune.csv
  checkpoints/
```

When `--flutter-assets-dir assets` is passed, the app model and both JSON files are copied into `assets/` automatically. Rebuild the Flutter app afterwards.

### 4. Update nutrition values

`ml_pipeline/nutrition_seed.json` is the editable source of truth. Each model class folder must have a matching seed key (case/spacing normalized). If a class is missing, metadata generation fails loudly instead of showing nutrition for the wrong food.

Values are estimates per 100 g (or 100 ml for beverages). Replace them with verified data before production. The app shows a medical disclaimer.

See [`ml_pipeline/README.md`](ml_pipeline/README.md) for the full pipeline reference and CLI flags.

---

## Model contract

The app and the exported model must agree exactly:

| Item | Contract |
| --- | --- |
| Tensor | `[1, 224, 224, 3]` float32 |
| Color | RGB |
| Normalization | `(pixel - 127.5) / 127.5` → `[-1, 1]` |
| Preprocessing | EXIF orientation, square center crop, bilinear resize |
| Output | `[1, N]` float32 softmax, class order = `class_names.json` |
| Confidence | Temperature scaling (`T=0.70`) fitted on validation; applied in the inference isolate before ranking |
| Quantization | FP16 or dynamic-range; primary variant selected on validation macro-F1 with a Keras-agreement tie-break. Both keep float32 I/O |

Both TFLite variants are validated by `train_export.py` against the Keras model for input/output shape, dtype, top-1 accuracy, macro-F1, calibration error, and agreement. The Flutter preprocessor mirrors the training crop and normalization; unit tests pin the pixel math and temperature scaling.

`android/app/build.gradle.kts` contains:

```kotlin
minSdk = 26
androidResources { noCompress += "tflite" }
ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64") }
```

`minSdk 26` is required by `tflite_flutter`; `x86_64` keeps the app usable on emulators.

---

## Tests

```bash
flutter analyze
flutter test

# Real model + isolate + assets on a connected Android device/emulator
flutter test integration_test/inference_smoke_test.dart -d emulator-5554

# Python syntax / metadata smoke test
python -m py_compile \
  ml_pipeline/train_export.py \
  ml_pipeline/clean_dataset.py \
  ml_pipeline/generate_nutrition_data.py
python ml_pipeline/generate_nutrition_data.py \
  --class-names assets/data/class_names.json \
  --seed ml_pipeline/nutrition_seed.json \
  --output /tmp/nutrition_check.json
```

There are 39 unit/widget tests. They cover inference preprocessing and calibration, nutrition catalog parsing, portion scaling, label localization, meal-category suggestion, diary saving, the confidence/portion result card, and the meal picker. The integration test builds a synthetic JPEG, loads the bundled TFLite model, runs one classification in the inference isolate (including calibrated confidence), and joins the result with the nutrition repository.

---

## Swapping in a database later

`NutritionRepository` is the only domain-facing catalog interface. The current `NutritionRepositoryImpl` builds O(1) maps from JSON at startup. To migrate to `sqflite`:

1. Implement `NutritionRepository` (or a new `NutritionCatalogDataSource`) backed by SQLite.
2. Provide it from `nutritionRepositoryProvider`.
3. Keep the same `findByIndex` / `findByLabel` semantics and index/label normalization.

No widget, controller, or use case changes are required.

`DiaryRepository` follows the same pattern. Replace `InMemoryDiaryRepository` with a sqflite-backed implementation, update `diaryRepositoryProvider`, and keep `DiaryController.saveMeal` as the single write path. The result card, meal sheet, and diary action bar do not change.

---

## Privacy & limitations

- Photos are processed entirely on-device; there is no upload path or network permission.
- The model was trained on user-supplied web-style food photos. Verify dataset licensing and validate on your own target population before release.
- The reported accuracy is held-out accuracy for this 13-class dataset; it is not a guarantee of accuracy for arbitrary photos.
- Nutrition values are estimates per 100 g/ml and vary by recipe and portion.
- Desktop latency in `model_report.json` is informative only; benchmark on target phones.
- NutriScan is not a medical device or a substitute for professional advice.

---

## Key dependencies

`flutter_riverpod`, `tflite_flutter`, `image_picker`, `image`, `flutter_localizations`; Python: `tensorflow==2.21.0`, `scikit-learn`, `matplotlib`, `Pillow`.
