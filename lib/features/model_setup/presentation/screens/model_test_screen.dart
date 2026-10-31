import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/llm/local_llm_service.dart';

class ModelTestScreen extends StatefulWidget {
  const ModelTestScreen({super.key});

  @override
  State<ModelTestScreen> createState() => _ModelTestScreenState();
}

class _ModelTestScreenState extends State<ModelTestScreen> {
  final LocalLlmService _llmService = LocalLlmService();

  bool _isBusy = false;
  String _status = '';
  String _response = '';

  @override
  void initState() {
    super.initState();

    _status = _llmService.hasModel
        ? 'A model is registered. Run the test to check it loads.'
        : 'Import the Qwen3 0.6B .litertlm file first.';
  }

  Future<void> _importModel() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _status = 'Choose the downloaded model file.';
    });

    try {
      // Use any-file selection because .litertlm is a custom extension.
      final file = await FilePicker.pickFile(type: FileType.any);

      if (!mounted) return;

      if (file == null) {
        setState(() {
          _status = 'Selection cancelled.';
        });
        return;
      }

      final path = file.path;

      if (!file.name.toLowerCase().endsWith('.litertlm') || path == null) {
        throw StateError('Select a local .litertlm model file.');
      }

      setState(() {
        _status = 'Copying and registering the model...';
      });

      await _llmService.importModel(path);

      if (!mounted) return;

      setState(() {
        _status = 'Model registered. Tap Run test.';
      });
    } catch (error, stackTrace) {
      debugPrint('Model import failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _status = 'Could not import the model. Check the debug console.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _runTest() async {
    if (_isBusy || !_llmService.hasModel) return;

    setState(() {
      _isBusy = true;
      _response = '';
      _status = 'Loading the model on CPU...';
    });

    final buffer = StringBuffer();
    final stopwatch = Stopwatch()..start();

    try {
      await for (final token in _llmService.generate(
        'Reply with one short sentence explaining what a refrigerator does.',
      )) {
        buffer.write(token);

        if (!mounted) continue;

        setState(() {
          _response = buffer.toString();
          _status = 'Generating locally...';
        });
      }

      stopwatch.stop();

      if (!mounted) return;

      setState(() {
        _status = buffer.isEmpty
            ? 'The model returned no text. Check the debug console.'
            : 'Finished in '
                  '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} '
                  'seconds, including model loading and closing.';
      });
    } catch (error, stackTrace) {
      debugPrint('Local inference failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _status = 'The test failed. Check the debug console.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Local model test'),
          automaticallyImplyLeading: !_isBusy,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'First local response',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'This tests the language model only. '
                'It is not using your manual or search results yet.',
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _isBusy ? null : _importModel,
                child: const Text('Import model'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isBusy || !_llmService.hasModel ? null : _runTest,
                child: const Text('Run test'),
              ),
              const SizedBox(height: 24),
              if (_isBusy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              Text(_status),
              const SizedBox(height: 24),
              if (_response.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(_response),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
