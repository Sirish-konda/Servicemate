class ManualPageText {
  const ManualPageText({
    required this.manualId,
    required this.pdfPageNumber,
    required this.text,
  });

  final String manualId;
  final int pdfPageNumber;
  final String text;

  bool get hasText => text.trim().isNotEmpty;
}
