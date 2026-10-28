class SelectedPdf {
  const SelectedPdf({
    required this.name,
    required this.path,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final int? sizeBytes;
}
