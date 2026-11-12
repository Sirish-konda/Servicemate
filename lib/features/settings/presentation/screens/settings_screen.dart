import 'package:flutter/material.dart';
import 'package:servicemate/core/llm/model_storage_service.dart';
import 'package:servicemate/features/model_setup/presentation/screens/model_storage_screen.dart';
import 'package:servicemate/features/model_setup/presentation/screens/setup_guide_screen.dart';

import '../../../../core/llm/local_llm_service.dart';
import '../../../model_setup/presentation/screens/model_test_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalLlmService _llmService = LocalLlmService();
  Future<void> _openModelSetup() async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const ModelTestScreen()));

    if (!mounted) return;

    _refreshStorage();
  }

  final ModelStorageService _storageService = ModelStorageService();

  late Future<ModelStorageSummary> _storageFuture;

  late Future<RegisteredModelInfo?> _registeredModelFuture;

  @override
  void initState() {
    super.initState();
    _storageFuture = _storageService.getSummary();
    _registeredModelFuture = _llmService.getRegisteredModelInfo();
  }

  void _refreshStorage() {
    setState(() {
      _storageFuture = _storageService.getSummary();
      _registeredModelFuture = _llmService.getRegisteredModelInfo();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1000000000) {
      return '${(bytes / 1000000000).toStringAsFixed(2)} GB';
    }

    return '${(bytes / 1000000).toStringAsFixed(1)} MB';
  }

  Future<void> _openSetupGuide() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (guideContext) => SetupGuideScreen(
          isFirstRun: false,
          onSetupPressed: _openModelSetup,
          onContinuePressed: () {
            Navigator.of(guideContext).pop();
          },
        ),
      ),
    );

    if (!mounted) return;

    _refreshStorage();
  }

  Future<void> _openModelStorage() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ModelStorageScreen()));

    if (!mounted) return;

    _refreshStorage();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasModel = _llmService.hasModel;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Setup guide'),
                subtitle: const Text('How manuals and offline AI work'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openSetupGuide,
              ),
            ),
            const SizedBox(height: 24),
            Text('Local AI', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      hasModel
                          ? Icons.check_circle_outline
                          : Icons.download_outlined,
                    ),
                    title: Text(
                      hasModel
                          ? 'A model is registered'
                          : 'No model registered',
                    ),
                    subtitle: Text(
                      hasModel
                          ? 'Run the model test to check that it loads '
                                'and generates a response.'
                          : 'Import a compatible model to answer '
                                'questions about your manuals.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.memory_outlined),
                    title: const Text('Model setup and test'),
                    subtitle: const Text(
                      'Import a model or test local CPU inference',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openModelSetup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Manage model storage'),
                    subtitle: const Text('Remove unregistered model copies'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openModelStorage,
                  ),
                  const Divider(height: 1),
                  FutureBuilder<RegisteredModelInfo?>(
                    future: _registeredModelFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const ListTile(
                          leading: Icon(Icons.description_outlined),
                          title: Text('Registered model file'),
                          subtitle: Text('Checking file details...'),
                        );
                      }

                      if (snapshot.hasError) {
                        return const ListTile(
                          leading: Icon(Icons.error_outline),
                          title: Text('Registered model file'),
                          subtitle: Text(
                            'Could not access its details. '
                            'Open model setup to check or replace the model.',
                          ),
                        );
                      }

                      final info = snapshot.data;

                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('Registered model file'),
                        subtitle: Text(
                          info == null
                              ? 'No active model registered.'
                              : '${info.fileName}\n${_formatBytes(info.sizeBytes)}',
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  FutureBuilder<ModelStorageSummary>(
                    future: _storageFuture,
                    builder: (context, snapshot) {
                      final String subtitle;

                      if (snapshot.connectionState != ConnectionState.done) {
                        subtitle = 'Checking stored model files...';
                      } else if (snapshot.hasError) {
                        subtitle = 'Could not read model storage. Tap refresh to retry.';
                      } else {
                        final summary = snapshot.data!;
                        final count = summary.fileCount;

                        subtitle =
                            '$count ${count == 1 ? 'file' : 'files'} · '
                            '${_formatBytes(summary.totalBytes)}\n'
                            'Includes retained imports. Excludes downloads and caches.';
                      }

                      return ListTile(
                        leading: const Icon(Icons.storage_outlined),
                        title: const Text('Stored model files'),
                        subtitle: Text(subtitle),
                        trailing: IconButton(
                          tooltip: 'Refresh model storage',
                          onPressed:
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? null
                              : _refreshStorage,
                          icon: const Icon(Icons.refresh),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('On-device processing', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Imported PDFs, extracted text, search passages, and '
              'saved answers are stored in the app’s local storage. '
              'The current question-answering flow searches your '
              'manual and runs the language model on this device.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Preparation makes PDF text searchable. '
              'It does not train the model. '
              'Scanned PDFs need OCR, which is not supported yet.',
            ),
            const SizedBox(height: 28),
            Text('Answer accuracy', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'AI answers can be incorrect. Check the retrieved '
              'sources and original PDF before acting. '
              'A numbered citation alone does not prove that '
              'an answer is supported.',
            ),
          ],
        ),
      ),
    );
  }
}
