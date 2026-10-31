import 'package:flutter/material.dart';

import '../../../model_setup/presentation/screens/model_test_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.memory_outlined),
              title: const Text('Local model test'),
              subtitle: const Text('Import a model and test CPU inference'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const ModelTestScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
