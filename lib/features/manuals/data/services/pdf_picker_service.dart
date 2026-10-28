import 'package:file_picker/file_picker.dart';
import 'package:servicemate/features/manuals/domain/models/selected_pdf.dart';

class PdfPickerException implements Exception {
  const PdfPickerException(this.message);

  final String message;
}

class PdfPickerService {
  Future<SelectedPdf?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (file == null) {
      return null;
    }

    if (!file.name.toLowerCase().endsWith('.pdf')) {
      throw const PdfPickerException('Please select a PDF file.');
    }

    final path = file.path;

    if (path == null || path.isEmpty) {
      throw const PdfPickerException(
        'This file could not be accessed locally.'
        'Download it to your device and try again.',
      );
    }

    final sizeBytes = await file.length();

    if (sizeBytes == 0) {
      throw const PdfPickerException(
        'The selected file is empty. Please choose another PDF',
      );
    }

    return SelectedPdf(name: file.name, path: path, sizeBytes: sizeBytes);
  }
}
