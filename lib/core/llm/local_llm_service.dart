import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class LocalLlmService {
  bool get hasModel => FlutterEdgeAi.hasActiveModel();

  Future<void> importModel(String sourcePath) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw StateError('The model file is missing.');
    }

    final sourceSize = await source.length();

    if (sourceSize == 0) {
      throw StateError('The model file is empty.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final modelsDirectory = Directory(p.join(documents.path, 'models'));

    await modelsDirectory.create(recursive: true);

    // Each import gets a separate directory, preserving earlier files.
    final installationDirectory = await modelsDirectory.createTemp('qwen3-');

    final destination = File(
      p.join(installationDirectory.path, 'qwen3-1.7b.litertlm'),
    );

    try {
      final copied = await source.copy(destination.path);

      if (await copied.length() != sourceSize) {
        throw StateError('The model copy is incomplete.');
      }
    } catch (_) {
      try {
        await installationDirectory.delete(recursive: true);
      } catch (error) {
        debugPrint('Cleaning incomplete model copy failed: $error');
      }

      rethrow;
    }

    // Keep this durable copy after registration. The package may
    // reference it directly for future inference and app restarts.
    await FlutterEdgeAi.installModel(
      modelType: ModelType.qwen3,
      fileType: ModelFileType.litertlm,
    ).fromFile(destination.path).install();
  }

  Stream<String> generate(String prompt) async* {
    if (!hasModel) {
      throw StateError('Import the model first.');
    }

    final timer = Stopwatch()..start();

    final model = await FlutterEdgeAi.getActiveModel(
      preferredBackend: PreferredBackend.cpu,
      maxTokens: 2048,
    );

    final loadedAt = timer.elapsedMilliseconds;
    debugPrint('[LLM] Model ready: $loadedAt ms');

    try {
      final chat = await model.createChat(
        modelType: ModelType.qwen3,
        enableThinking: false,
        topK: 1,
        maxOutputTokens: 96,
      );

      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

      final generationStartedAt = timer.elapsedMilliseconds;
      var receivedText = false;

      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse && response.token.isNotEmpty) {
          if (!receivedText) {
            receivedText = true;

            final firstTextAt = timer.elapsedMilliseconds;

            debugPrint('[LLM] First text from start: $firstTextAt ms');
            debugPrint(
              '[LLM] First text after generation started: '
              '${firstTextAt - generationStartedAt} ms',
            );
          }

          yield response.token;
        }
      }

      debugPrint(
        '[LLM] Generation finished: '
        '${timer.elapsedMilliseconds - generationStartedAt} ms',
      );
    } finally {
      final closeStartedAt = timer.elapsedMilliseconds;

      try {
        await model.close();
      } finally {
        timer.stop();

        debugPrint(
          '[LLM] Model close: '
          '${timer.elapsedMilliseconds - closeStartedAt} ms',
        );
        debugPrint('[LLM] Total: ${timer.elapsedMilliseconds} ms');
      }
    }
  }
}
