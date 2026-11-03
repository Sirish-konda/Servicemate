import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model_download_spec.dart';
import 'model_file_verifier.dart';

class ModelDownloadCancelled implements Exception {
  const ModelDownloadCancelled();
}

class DownloadedModel {
  DownloadedModel({required this.file, required Directory directory})
    : _directory = directory;

  final File file;
  final Directory _directory;

  Future<void> cleanup() async {
    if (await _directory.exists()) {
      await _directory.delete(recursive: true);
    }
  }
}

class ModelDownloadService {
  final ModelFileVerifier _verifier = ModelFileVerifier();

  HttpClient? _client;
  bool _isRunning = false;
  bool _cancelRequested = false;

  void cancel() {
    if (!_isRunning) return;

    _cancelRequested = true;
    _client?.close(force: true);
  }

  void _checkCancelled() {
    if (_cancelRequested) {
      throw const ModelDownloadCancelled();
    }
  }

  Future<DownloadedModel> download({
    required ModelDownloadSpec spec,
    required void Function(int receivedBytes, int totalBytes) onProgress,
    required VoidCallback onVerifying,
  }) async {
    if (_isRunning) {
      throw StateError('A model download is already running.');
    }

    _isRunning = true;
    _cancelRequested = false;

    Directory? directory;
    RandomAccessFile? output;
    var keepDownload = false;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);

    _client = client;

    try {
      final temporaryDirectory = await getTemporaryDirectory();

      directory = await temporaryDirectory.createTemp('servicemate-model-');

      _checkCancelled();

      final file = File(p.join(directory.path, spec.fileName));
      final request = await client
          .getUrl(spec.url)
          .timeout(const Duration(seconds: 30));

      _checkCancelled();

      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Model download failed with HTTP ${response.statusCode}.',
          uri: spec.url,
        );
      }

      if (response.contentLength >= 0 &&
          response.contentLength != spec.sizeBytes) {
        throw const ModelVerificationException(
          'The server returned an unexpected model size.',
        );
      }

      final writer = await file.open(mode: FileMode.write);
      output = writer;

      var receivedBytes = 0;
      onProgress(0, spec.sizeBytes);

      await for (final bytes in response.timeout(const Duration(seconds: 60))) {
        _checkCancelled();

        receivedBytes += bytes.length;

        if (receivedBytes > spec.sizeBytes) {
          throw const ModelVerificationException(
            'The download exceeds the expected model size.',
          );
        }

        await writer.writeFrom(bytes);
        onProgress(receivedBytes, spec.sizeBytes);
      }

      _checkCancelled();

      await writer.flush();
      await writer.close();
      output = null;

      onVerifying();
      _checkCancelled();

      await _verifier.verify(file: file, spec: spec);

      _checkCancelled();

      keepDownload = true;

      return DownloadedModel(file: file, directory: directory);
    } catch (_) {
      if (_cancelRequested) {
        throw const ModelDownloadCancelled();
      }

      rethrow;
    } finally {
      client.close(force: true);

      try {
        await output?.close();
      } catch (error) {
        debugPrint('Closing model download file failed: $error');
      }

      if (!keepDownload && directory != null) {
        try {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        } catch (error) {
          debugPrint('Cleaning model download failed: $error');
        }
      }

      _client = null;
      _isRunning = false;
    }
  }
}
