import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'supabase_service.dart';

/// Picks a local image with a native file dialog and uploads it to Supabase
/// Storage, returning the public URL to store in the database. Returns null
/// if the user cancelled the dialog.
class ImageUpload {
  static Future<String?> pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      final f = File(file.path!);
      if (!await f.exists()) return null;
      bytes = Uint8List.fromList(await f.readAsBytes());
    } else {
      return null;
    }

    final name = file.name.isEmpty ? 'image.jpg' : file.name;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';
    final sanitizedExt = RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'news/$ts.$sanitizedExt';

    final tmp = File('${Directory.systemTemp.path}/betadmin_$ts.$sanitizedExt');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      final bucket = SupabaseService.client.storage.from(AppConfig.storageBucket);
      await bucket.upload(
        path,
        tmp,
        fileOptions: FileOptions(contentType: _contentType(sanitizedExt)),
      );
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
    return bucket.getPublicUrl(path);
  }

  static String _contentType(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'svg' => 'image/svg+xml',
      _ => 'image/jpeg',
    };
  }
}
