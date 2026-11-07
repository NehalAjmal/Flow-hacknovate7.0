import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<bool> saveBytes(Uint8List bytes, {required String suggestedName, required String mimeType, required String extension}) async {
  final loc = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: [
      XTypeGroup(label: extension.toUpperCase(), extensions: [extension], mimeTypes: [mimeType]),
    ],
  );
  if (loc == null) return false;
  await XFile.fromData(bytes, mimeType: mimeType, name: suggestedName).saveTo(loc.path);
  return true;
}
