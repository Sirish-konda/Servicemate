import 'package:flutter/material.dart';

import '../core/llm/local_llm_service.dart';
import '../core/services/first_run_service.dart';
import '../features/model_setup/presentation/screens/model_test_screen.dart';
import 'app_shell.dart';

class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key});

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  final FirstRunService _firstRunService = FirstRunService();
  final LocalLlmService _llmService = LocalLlmService();

  late Future<bool> _completedFuture;

  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _completedFuture = _load();
  }

  Future<bool> _load() async {
    if (_llmService.hasModel) return true;

    return _firstRunService.isCompleted();
  }

  Future<void> _finish() async {
    await _firstRunService.complete();

    if (!mounted) return;

    setState(() {
      _completedFuture = Future.value(true);
    });
  }

  Future<void> _continue({required bool openSetup}) async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      if (openSetup) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ModelTestScreen()),
        );

        if (!mounted) return;

        // Returning without installing leaves the welcome screen open.
        if (!_llmService.hasModel) return;
      }

      await _finish();
    } catch (error, stackTrace) {
      debugPrint('First-run setup failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = 'Could not save your setup choice. Please try again.';
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
    return FutureBuilder<bool>(
      future: _completedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () {
                  setState(() {
                    _completedFuture = _load();
                  });
                },
                child: const Text('Retry loading setup'),
              ),
            ),
          );
        }

        if (snapshot.data == true) {
          return const AppShell();
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Welcome to ServiceMate')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Your manuals, on your device',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Import PDF manuals, search their text, and open '
                  'the original pages when you need them.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'To generate AI answers offline, download the '
                  'Qwen3 1.7B model once. The download is about '
                  '977 MB and installation needs extra storage '
                  'for a second copy. Wi-Fi is recommended.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can continue without AI and set it up later '
                  'in Settings. PDF reading and prepared-text search '
                  'do not require the model.',
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isBusy ? null : () => _continue(openSetup: true),
                  child: const Text('Set up offline AI'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isBusy ? null : () => _continue(openSetup: false),
                  child: const Text('Continue without AI'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
