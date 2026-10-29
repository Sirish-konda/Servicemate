class ManualChunk {
  const ManualChunk({
    required this.id,
    required this.manualId,
    required this.pdfPageNumber,
    required this.text,
  });

  final String id;
  final String manualId;
  final int pdfPageNumber;
  final String text;
}
