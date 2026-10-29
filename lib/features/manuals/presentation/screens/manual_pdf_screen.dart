import 'package:flutter/material.dart';

import '../../../../core/widgets/local_pdf_viewer.dart';
import '../../data/services/pdf_storage_service.dart';
import '../../domain/models/saved_manual.dart';

class ManualPdfScreen extends StatefulWidget {
  const ManualPdfScreen({
    super.key,
    required this.manual,
    this.initialPageNumber = 1,
  });

  final SavedManual manual;
  final int initialPageNumber;

  @override
  State<ManualPdfScreen> createState() => _ManualPdfScreenState();
}

class _ManualPdfScreenState extends State<ManualPdfScreen> {
  final PdfStorageService _storageService = PdfStorageService();

  late Future<String> _pdfPathFuture;

  @override
  void initState() {
    super.initState();
    _pdfPathFuture = _storageService.getPdfPath(widget.manual.id);
  }

  void _retry() {
    setState(() {
      _pdfPathFuture = _storageService.getPdfPath(widget.manual.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.manual.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _pdfPathFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 16),
                      const Text(
                        'The saved PDF could not be accessed.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _retry,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return LocalPdfViewer(
              filePath: snapshot.data!,
              initialPageNumber: widget.initialPageNumber,
            );
          },
        ),
      ),
    );
  }
}
