import 'dart:io';
import 'package:gal/gal.dart';

/// Saves a finished video to the user's Photos or gallery.
/// Returns null on success, or a short message the UI can show.
class PhotoSaveService {
  static Future<String?> saveVideo(String path) async {
    try {
      if (!await File(path).exists()) {
        return 'That video file could not be found.';
      }
      var allowed = await Gal.hasAccess();
      if (!allowed) {
        allowed = await Gal.requestAccess();
      }
      if (!allowed) {
        return 'Photos access was denied. You can allow it in Settings.';
      }
      await Gal.putVideo(path);
      return null;
    } on GalException catch (e) {
      return 'Could not save the video (${e.type.name}).';
    } catch (_) {
      return 'Could not save the video.';
    }
  }
}
