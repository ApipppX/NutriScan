# Artefak Training NutriScan

Folder ini menyimpan salinan terkurasi dari `ml_pipeline/output_bakso/` untuk
model **2.2.0** (14 kelas, dibuat 28 Oktober 2026). Folder asli tersebut
di-ignore oleh Git karena berisi model biner berukuran besar; salinan di sini
disediakan agar angka evaluasi dan gambar naskah tetap terlacak di repositori.

## Isi

| Berkas | Keterangan |
| --- | --- |
| `model_report.json` | Sumber utama angka evaluasi: akurasi, macro-F1, top-3, ECE, audit TFLite, dan latency |
| `training_history.json` | Riwayat loss/accuracy per epoch untuk tahap initial dan fine-tuning |
| `metrics_initial.csv`, `metrics_finetune.csv` | Metrik per epoch dalam format CSV |
| `training_curves.png` | Grafik training dan validasi |
| `validation_confusion_matrix.png` | Confusion matrix pada validation split |
| `test_confusion_matrix.png` | Confusion matrix Keras pada test split |
| `test_tflite_confusion_matrix.png` | Confusion matrix model TFLite pada test split |
| `test_classification_report.txt` | Precision/recall/F1 per kelas pada test split |
| `validation_classification_report.txt` | Precision/recall/F1 per kelas pada validation split |
| `test_tflite_classification_report.txt` | Laporan per kelas untuk model TFLite |
| `SHA256SUMS.txt` | Checksum SHA-256 untuk seluruh berkas di folder ini |

## Yang tidak disertakan

- `best_model.keras` (33,85 MB) — artefak training untuk fine-tuning lanjutan,
  bukan model yang dipakai aplikasi.
- `food_classifier*.tflite` — model yang dipakai aplikasi sudah dilacak di
  `assets/models/food_classifier.tflite`; salinan lain hanya varian konversi.
- `class_names.json` dan `nutrition_data.json` — versi kanonik ada di
  `assets/data/`.

## Catatan

- Dataset latih berada di luar repositori:
  `D:\Dataset Makanan 1GB\dataset_clean_mendeley_bakso`.
- `model_report.json` memuat path lokal dari mesin pelatihan; path tersebut tidak
  memengaruhi hasil evaluasi.
- Untuk mereproduksi artefak, lihat [`ml_pipeline/README.md`](../../ml_pipeline/README.md).
