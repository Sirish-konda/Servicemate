import 'package:flutter/material.dart';

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

    setState(() {
      // Read the latest registration status when rebuilding.
    });
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
