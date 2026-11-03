import 'dart:io';

import 'package:crypto/crypto.dart';

import 'model_download_spec.dart';

class ModelVerificationException implements Exception {
  const ModelVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ModelFileVerifier {
  Future<void> verify({
    required File file,
    required ModelDownloadSpec spec,
  }) async {
    if (!await file.exists()) {
      throw const ModelVerificationException(
        'The downloaded model file is missing.',
      );
    }

    final size = await file.length();

    if (size != spec.sizeBytes) {
      throw const ModelVerificationException(
        'The model download has an unexpected size. Please retry.',
      );
    }

    // Read incrementally rather than loading the whole model into memory.
    final digest = await sha256.bind(file.openRead()).single;

    if (digest.toString() != spec.sha256Hex.toLowerCase()) {
      throw const ModelVerificationException(
        'The model checksum does not match. Please retry.',
      );
    }
  }
}
