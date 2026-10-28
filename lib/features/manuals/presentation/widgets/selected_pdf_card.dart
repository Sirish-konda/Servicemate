import 'package:flutter/material.dart';
import 'package:servicemate/features/manuals/domain/models/selected_pdf.dart';

class SelectedPdfCard extends StatelessWidget {
  final SelectedPdf pdf;
  final VoidCallback onRemove;
  const SelectedPdfCard({super.key, required this.onRemove, required this.pdf});

  String _formatSize(int? bytes) {
    if (bytes == null) {
      return 'Size unavailable';
    }

    if (bytes < 1024) {
      return '$bytes bytes';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          Icons.picture_as_pdf_outlined,
          color: colors.primary,
          size: 32,
        ),
        title: Text(pdf.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_formatSize(pdf.sizeBytes)),
        trailing: IconButton(
          onPressed: onRemove,
          icon: Icon(Icons.close),
          tooltip: 'Remove selected PDF',
        ),
      ),
    );
  }
}
