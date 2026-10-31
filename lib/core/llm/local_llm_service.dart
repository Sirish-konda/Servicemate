import 'dart:io';

import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalLlmService {
  bool get hasModel => FlutterEdgeAi.hasActiveModel();

  Future<void> importModel(String sourcePath) async {
    final source = File(sourcePath);

    if (!await source.exists() || await source.length() == 0) {
      throw StateError('The model file is missing or empty.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final modelDirectory = Directory(p.join(documents.path, 'models'));

    await modelDirectory.create(recursive: true);

    final destination = p.join(modelDirectory.path, 'qwen3-1.7b.litertlm');

    // Keep our own copy instead of relying on the picker's temporary path.
    if (p.normalize(sourcePath) != p.normalize(destination)) {
      await source.copy(destination);
    }

    await FlutterEdgeAi.installModel(
      modelType: ModelType.qwen3,
      fileType: ModelFileType.litertlm,
    ).fromFile(destination).install();
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
    print('[LLM] Model ready: ${loadedAt} ms');

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

            print('[LLM] First text from start: $firstTextAt ms');
            print(
              '[LLM] First text after generation started: '
              '${firstTextAt - generationStartedAt} ms',
            );
          }

          yield response.token;
        }
      }

      print(
        '[LLM] Generation finished: '
        '${timer.elapsedMilliseconds - generationStartedAt} ms',
      );
    } finally {
      final closeStartedAt = timer.elapsedMilliseconds;

      try {
        await model.close();
      } finally {
        timer.stop();

        print(
          '[LLM] Model close: '
          '${timer.elapsedMilliseconds - closeStartedAt} ms',
        );
        print('[LLM] Total: ${timer.elapsedMilliseconds} ms');
      }
    }
  }
}
