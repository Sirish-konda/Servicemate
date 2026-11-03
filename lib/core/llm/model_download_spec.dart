class ModelDownloadSpec {
  const ModelDownloadSpec({
    required this.displayName,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256Hex,
  });

  final String displayName;
  final String fileName;
  final Uri url;
  final int sizeBytes;
  final String sha256Hex;

  static final qwen3 = ModelDownloadSpec(
    displayName: 'Qwen3 1.7B',
    fileName: 'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
    url: Uri.parse(
      'https://huggingface.co/litert-community/Qwen3-1.7B/'
      'resolve/87603f0ff3fe74b9b77ed0477edb773b4b596f32/'
      'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
    ),
    sizeBytes: 977184032,
    sha256Hex:
        '2a72330b504a6596d53a2c00923c57173b10f1b83e6a541213ffec08d1fc5de8',
  );
}
