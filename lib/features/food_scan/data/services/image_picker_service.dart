import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/scan_source.dart';

/// Wraps platform picker concerns so the presentation layer only sees bytes.
final class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Returns null when the user cancels the picker.
  Future<Uint8List?> pick(ScanSource source) async {
    try {
      final file = await _picker.pickImage(
        source: switch (source) {
          ScanSource.camera => ImageSource.camera,
          ScanSource.gallery => ImageSource.gallery,
        },
        maxWidth: AppConfig.pickerMaxDimension.toDouble(),
        maxHeight: AppConfig.pickerMaxDimension.toDouble(),
        imageQuality: AppConfig.pickerImageQuality,
        requestFullMetadata: false,
      );
      if (file == null) return null;

      final length = await file.length();
      if (length <= 0) {
        throw const ImagePickerException('Picker returned an empty file.');
      }
      if (length > AppConfig.maxImageBytes) {
        throw const ImagePickerException(
          'Selected image exceeds the size limit.',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ImagePickerException('Picker returned empty image bytes.');
      }
      return bytes;
    } on AppException {
      rethrow;
    } catch (error) {
      throw ImagePickerException(
        'Image picker failed for source ${source.name}.',
        cause: error,
      );
    }
  }
}
