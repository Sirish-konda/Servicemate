import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:servicemate/core/llm/model_download_service.dart';
import 'package:servicemate/core/llm/model_download_spec.dart';

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

  final ModelDownloadService _downloadService = ModelDownloadService();

  double? _downloadProgress;
  bool _canCancelDownload = false;
  bool _downloadCancelRequested = false;

  @override
  void initState() {
    super.initState();
    _status = _llmService.hasModel
        ? 'A model is registered. Run the test to check it loads.'
        : 'Download the AI model or import a local .litertlm file.';
  }

  Future<void> _importModel() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _response = '';
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
      await for (final token in _llmService.generate('''
Read this fictional reference:
Compartment A has a default temperature of 9 degrees.
Compartment B has a default temperature of -12 degrees.

What is the default temperature of Compartment A?
Answer in one short sentence.
''')) {
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

  Future<void> _downloadModel() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _llmService.hasModel
              ? 'Download a replacement model?'
              : 'Download AI model?',
        ),
        content: Text(
          'Download Qwen3 1.7B, approximately 977 MB. '
          'Wi-Fi is recommended.\n\n'
          'Installation temporarily needs space for the download '
          'and another full copy. Previous model files are retained.'
          '${_llmService.hasModel ? '\n\nThe new model will become active after registration.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _isBusy) return;

    setState(() {
      _isBusy = true;
      _response = '';
      _downloadProgress = 0;
      _canCancelDownload = true;
      _downloadCancelRequested = false;
      _status = 'Starting download...';
    });

    DownloadedModel? downloaded;

    try {
      downloaded = await _downloadService.download(
        spec: ModelDownloadSpec.qwen3,
        onProgress: (received, total) {
          if (!mounted || _downloadCancelRequested) return;

          final progress = received / total;

          // Avoid rebuilding for every network chunk.
          final previous = _downloadProgress ?? 0;
          if (received != total && progress - previous < 0.01) {
            return;
          }

          setState(() {
            _downloadProgress = progress;
            _status =
                'Downloading model: '
                '${(progress * 100).toStringAsFixed(0)}%';
          });
        },
        onVerifying: () {
          if (!mounted || _downloadCancelRequested) return;

          setState(() {
            _downloadProgress = null;
            _status = 'Checking model size and checksum...';
          });
        },
      );

      if (!mounted || _downloadCancelRequested) {
        throw const ModelDownloadCancelled();
      }

      setState(() {
        _canCancelDownload = false;
        _downloadProgress = null;
        _status = 'Installing the verified model...';
      });

      await _llmService.importModel(downloaded.file.path);

      if (!mounted) return;

      setState(() {
        _status = 'Model registered. Tap Run test to check it loads.';
      });
    } on ModelDownloadCancelled {
      if (!mounted) return;

      setState(() {
        _status = 'Download cancelled.';
      });
    } catch (error, stackTrace) {
      debugPrint('Model download or installation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _status =
            'Could not download or install the model. '
            'Check your connection and available storage, then retry. '
            'See the debug console for details.';
      });
    } finally {
      try {
        await downloaded?.cleanup();
      } catch (error) {
        debugPrint('Temporary model cleanup failed: $error');
      }

      if (mounted) {
        setState(() {
          _isBusy = false;
          _canCancelDownload = false;
          _downloadProgress = null;
          _downloadCancelRequested = false;
        });
      }
    }
  }

  void _cancelDownload() {
    if (!_canCancelDownload || _downloadCancelRequested) return;

    _downloadService.cancel();

    setState(() {
      _downloadCancelRequested = true;
      _status = 'Cancelling download or verification...';
    });
  }

  @override
  void dispose() {
    _downloadService.cancel();
    super.dispose();
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
                'Check your local model',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'This test uses a short fictional reference, not your manuals. '
                'The expected answer is 9 degrees for Compartment A. '
                'A successful test does not guarantee accurate manual answers.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isBusy ? null : _downloadModel,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Download AI model'),
              ),
              const SizedBox(height: 12),
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
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 16),
              ],
              if (_canCancelDownload) ...[
                OutlinedButton(
                  onPressed: _downloadCancelRequested ? null : _cancelDownload,
                  child: Text(
                    _downloadCancelRequested
                        ? 'Cancelling...'
                        : 'Cancel download',
                  ),
                ),
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
