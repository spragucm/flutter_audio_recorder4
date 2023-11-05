import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';

Future<io.Directory?> getAppDocDirectory() async {
  if (io.Platform.isIOS) {
    return await getApplicationDocumentsDirectory();
  }
  return await getExternalStorageDirectory();
}