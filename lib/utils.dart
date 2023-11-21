import 'dart:io';
import 'package:file/local.dart';

extension FileUtils on LocalFileSystem {
  Future<String> validateFilepath(String? filepath) async {

    var generalMessage = "Recorder not initialized.";
    if (filepath == null) {
      return "Filepath is null.$generalMessage";
    }

    File file = this.file(filepath);
    if (await file.exists()) {
      return "A file already exists at the path :$filepath.$generalMessage";
    } else if (!await file.parent.exists()) {
      return "The specified parent directory does not exist.$generalMessage";
    }

    return "";
  }
}