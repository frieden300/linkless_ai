import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class MediaService {
  /// Takes an external path and returns a persistent internal path
  static Future<String> persistImage(String originalPath) async {
    final File originalFile = File(originalPath);
    
    if (!await originalFile.exists()) {
      throw Exception("Source file no longer exists");
    }

    // 1. Get the app's private internal directory
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String mediaFolder = p.join(appDir.path, 'linkless_ai_data', 'chat_media');
    
    // 2. Ensure the media folder exists
    final Directory directory = Directory(mediaFolder);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // 3. Generate a unique filename using a timestamp to avoid name collisions
    final String extension = p.extension(originalPath);
    final String fileName = "img_${DateTime.now().millisecondsSinceEpoch}$extension";
    final String newPath = p.join(mediaFolder, fileName);

    // 4. Clone the file to internal storage
    await originalFile.copy(newPath);

    return newPath; // Store this string in your database
  }

  /// Clears all stored images in the chat_media folder
  static Future<void> clearAllImages() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String mediaFolder = p.join(appDir.path, 'linkless_ai_data', 'chat_media');
      final Directory directory = Directory(mediaFolder);
      
      if (await directory.exists()) {
        final List<FileSystemEntity> files = directory.listSync();
        for (final FileSystemEntity file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint("Error clearing images: $e");
    }
  }
}
