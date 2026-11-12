import 'package:flutter/material.dart';

import '../../../../core/llm/model_storage_service.dart';

class ModelStorageScreen extends StatefulWidget {
  const ModelStorageScreen({super.key});

  @override
  State<ModelStorageScreen> createState() => _ModelStorageScreenState();
}

class _ModelStorageScreenState extends State<ModelStorageScreen> {
  final ModelStorageService _service = ModelStorageService();

  late Future<List<StoredModelFile>> _filesFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _filesFuture = _service.getModelFiles();
  }

  void _reload() {
    setState(() {
      _filesFuture = _service.getModelFiles();
    });
  }

  Future<void> _delete(StoredModelFile file) async {
    if (_isBusy || file.isRegistered) return;

    setState(() {
      _isBusy = true;
    });

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete model copy?'),
          content: Text(
            '${file.relativePath}\n\n'
            'This file is not currently registered. Deleting it frees '
            '${(file.sizeBytes / 1000000).toStringAsFixed(1)} MB.\n\n'
            'To use this copy again, you would need to import '
            'or download it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (!mounted || confirmed != true) return;

      await _service.deleteUnregisteredFile(file.path);

      if (!mounted) return;

      _reload();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Model copy deleted.')));
    } catch (error, stackTrace) {
      debugPrint('Model cleanup failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not delete this copy. It may now be registered '
            'or unavailable. The list has been refreshed.',
          ),
        ),
      );
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
          title: const Text('Model storage'),
          automaticallyImplyLeading: !_isBusy,
          actions: [
            IconButton(
              tooltip: 'Refresh models',
              onPressed: _isBusy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<List<StoredModelFile>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Could not check model files and registry '
                          'references. Deletion is unavailable.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _isBusy ? null : _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final files = snapshot.data!;

              if (files.isEmpty) {
                return const Center(
                  child: Text('No model files in app model storage.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: files.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final file = files[index];

                  return Card(
                    child: ListTile(
                      title: Text(file.relativePath),
                      subtitle: Text(
                        '${(file.sizeBytes / 1000000).toStringAsFixed(1)} MB'
                        '\n${file.isRegistered ? 'Registered — protected' : 'Unregistered copy'}',
                      ),
                      trailing: file.isRegistered
                          ? const Icon(Icons.lock_outline)
                          : IconButton(
                              tooltip: 'Delete model copy',
                              onPressed: _isBusy ? null : () => _delete(file),
                              icon: const Icon(Icons.delete_outline),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
