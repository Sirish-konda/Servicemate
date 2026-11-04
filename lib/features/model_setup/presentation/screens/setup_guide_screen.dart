import 'package:flutter/material.dart';

class SetupGuideScreen extends StatelessWidget {
  const SetupGuideScreen({
    super.key,
    required this.onSetupPressed,
    required this.onContinuePressed,
    this.isBusy = false,
    this.error,
    this.isFirstRun = true,
  });

  final VoidCallback onSetupPressed;
  final VoidCallback onContinuePressed;
  final bool isBusy;
  final String? error;
  final bool isFirstRun;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isBusy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isFirstRun ? 'Welcome to ServiceMate' : 'Setup guide'),
          automaticallyImplyLeading: !isBusy,
        ),
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
                'You can use the app without AI and set it up later '
                'in Settings. PDF reading and prepared-text search '
                'do not require the model.',
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: isBusy ? null : onSetupPressed,
                child: Text(
                  isFirstRun ? 'Set up offline AI' : 'Open model setup',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: isBusy ? null : onContinuePressed,
                child: Text(isFirstRun ? 'Continue without AI' : 'Done'),
              ),
              if (isBusy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (error != null) ...[const SizedBox(height: 16), Text(error!)],
            ],
          ),
        ),
      ),
    );
  }
}
