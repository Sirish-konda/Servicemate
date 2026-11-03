import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servicemate/core/llm/model_download_spec.dart';
import 'package:servicemate/core/llm/model_file_verifier.dart';

void main() {
  late Directory directory;
  late File file;

  final verifier = ModelFileVerifier();

  // Known SHA-256 for the three UTF-8 bytes "abc".
  const abcChecksum =
      'ba7816bf8f01cfea414140de5dae2223'
      'b00361a396177a9cb410ff61f20015ad';

  ModelDownloadSpec spec({int sizeBytes = 3, String checksum = abcChecksum}) {
    return ModelDownloadSpec(
      displayName: 'Test model',
      fileName: 'test.litertlm',
      url: Uri.parse('https://example.com/test.litertlm'),
      sizeBytes: sizeBytes,
      sha256Hex: checksum,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'servicemate-verifier-test-',
    );
    file = File(p.join(directory.path, 'test.litertlm'));
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('accepts a file with the expected size and checksum', () async {
    await file.writeAsBytes([97, 98, 99]);

    await verifier.verify(file: file, spec: spec());

    expect(await file.readAsBytes(), [97, 98, 99]);
  });

  test('rejects a missing file', () async {
    await expectLater(
      verifier.verify(file: file, spec: spec()),
      throwsA(isA<ModelVerificationException>()),
    );
  });

  test('rejects an incomplete file', () async {
    await file.writeAsBytes([97, 98]);

    await expectLater(
      verifier.verify(file: file, spec: spec()),
      throwsA(isA<ModelVerificationException>()),
    );
  });

  test('rejects altered contents even when the size matches', () async {
    await file.writeAsBytes([97, 98, 100]);

    await expectLater(
      verifier.verify(file: file, spec: spec()),
      throwsA(isA<ModelVerificationException>()),
    );

    // Verification must not modify or delete the file.
    expect(await file.readAsBytes(), [97, 98, 100]);
  });

  test('accepts an uppercase checksum', () async {
    await file.writeAsBytes([97, 98, 99]);

    await verifier.verify(
      file: file,
      spec: spec(checksum: abcChecksum.toUpperCase()),
    );
  });
}
