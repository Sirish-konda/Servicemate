import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class LocalPdfViewer extends StatelessWidget {
  const LocalPdfViewer({
    super.key,
    required this.filePath,
    this.initialPageNumber = 1,
  }) : assert(initialPageNumber >= 1);

  final String filePath;
  final int initialPageNumber;

  @override
  Widget build(BuildContext context) {
    return PdfViewer.file(
      filePath,
      initialPageNumber: initialPageNumber,
      params: PdfViewerParams(
        errorBannerBuilder: (context, error, stackTrace, documentRef) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This PDF could not be opened. '
                'It may be damaged or require a password.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    );
  }
}
