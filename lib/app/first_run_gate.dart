import 'package:flutter/material.dart';
import 'package:servicemate/features/model_setup/presentation/screens/setup_guide_screen.dart';

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

        return SetupGuideScreen(
          isBusy: _isBusy,
          error: _error,
          onSetupPressed: () => _continue(openSetup: true),
          onContinuePressed: () => _continue(openSetup: false),
        );
      },
    );
  }
}
