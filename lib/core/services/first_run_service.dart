import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FirstRunService {
  Future<File> _settingsFile() async {
    final directory = await getApplicationDocumentsDirectory();

    return File(p.join(directory.path, 'first_run.json'));
  }

  Future<bool> isCompleted() async {
    final file = await _settingsFile();

    if (!await file.exists()) return false;

    try {
      final decoded = jsonDecode(await file.readAsString());

      return decoded is Map<String, dynamic> &&
          decoded['schemaVersion'] == 1 &&
          decoded['completed'] == true;
    } on FormatException {
      return false;
    }
  }

  Future<void> complete() async {
    final file = await _settingsFile();
    final temporary = File('${file.path}.tmp');

    try {
      await temporary.writeAsString(
        jsonEncode({'schemaVersion': 1, 'completed': true}),
        flush: true,
      );

      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
