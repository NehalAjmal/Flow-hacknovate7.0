import 'dart:typed_data';

import 'save_file_io.dart' if (dart.library.js_interop) 'save_file_web.dart' as impl;

/// Saves [bytes] where the person chooses: a save dialog on desktop, a
/// download on web. Returns false if they cancelled.
Future<bool> saveBytes(Uint8List bytes, {required String suggestedName, required String mimeType, required String extension}) =>
    impl.saveBytes(bytes, suggestedName: suggestedName, mimeType: mimeType, extension: extension);
