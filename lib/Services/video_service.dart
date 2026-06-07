import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class VideoService {
  static final _supabase = Supabase.instance.client;
  static const String _bucket = 'competition_matches';
  
  // REPLACE THIS with your actual Render URL after deployment
  static const String _renderUrl = 'https://your-service-name.onrender.com/process-video';

  static Future<void> uploadAndProcess({
    required File videoFile,
    required String matchName,
    required int matchId,
    String? oldMatchName,
  }) async {
    final sanitizedName = sanitizeName(matchName);
    
    // 1. Clean up old assets if necessary
    if (oldMatchName != null) {
      await deleteMatchAssets(oldMatchName);
    }

    // 2. Upload raw video to a temporary path
    final tempPath = '$sanitizedName/temp_raw.mp4';
    await _supabase.storage.from(_bucket).upload(
      tempPath,
      videoFile,
      fileOptions: const FileOptions(upsert: true),
    );

    // 3. Trigger Render processing (Async)
    // We don't await this because we want the app to close the form immediately
    http.post(
      Uri.parse(_renderUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'videoPath': tempPath,
        'matchId': matchId,
        'matchName': sanitizedName,
      }),
    ).then((response) {
      debugPrint('Render triggered: ${response.statusCode}');
    }).catchError((e) {
      debugPrint('Error triggering Render: $e');
    });
  }

  static String sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
  }

  static Future<void> deleteMatchAssets(String matchName) async {
    final sanitizedName = sanitizeName(matchName);
    try {
      final List<FileObject> objects = await _supabase.storage.from(_bucket).list(path: sanitizedName);
      if (objects.isEmpty) return;

      // Delete files in abr subfolder
      final List<FileObject> abrObjects = await _supabase.storage.from(_bucket).list(path: '$sanitizedName/abr');
      if (abrObjects.isNotEmpty) {
        await _supabase.storage.from(_bucket).remove(abrObjects.map((obj) => '$sanitizedName/abr/${obj.name}').toList());
      }

      // Delete top level files (thumbnail, etc)
      await _supabase.storage.from(_bucket).remove(objects.map((obj) => '$sanitizedName/${obj.name}').toList());
    } catch (e) {
      debugPrint('Error cleaning up assets: $e');
    }
  }
}
