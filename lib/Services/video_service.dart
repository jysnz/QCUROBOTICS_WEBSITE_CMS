import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class VideoService {
  static final _supabase = Supabase.instance.client;
  static const String _bucket = 'competition_matches';
  
  // REPLACE THIS with your actual Render URL
  static const String _renderUrl = 'https://qcu-robotics-website-cms-server-1.onrender.com/process-video';

  /// Sends the video and optional thumbnail directly to the server for processing.
  static Future<void> uploadAndProcess({
    required File videoFile,
    required String matchName,
    required int matchId,
    File? thumbnailFile,
    String? oldMatchName,
  }) async {
    final sanitizedName = sanitizeName(matchName);
    
    // 1. Clean up old assets if necessary (this still happens in Supabase)
    if (oldMatchName != null) {
      await deleteMatchAssets(oldMatchName);
    } else {
      await deleteMatchAssets(sanitizedName);
    }

    try {
      // 2. Prepare Multipart Request
      var request = http.MultipartRequest('POST', Uri.parse(_renderUrl));
      
      request.fields['matchId'] = matchId.toString();
      request.fields['matchName'] = sanitizedName;
      
      // Add Video File
      request.files.add(await http.MultipartFile.fromPath(
        'video', 
        videoFile.path,
        filename: 'video.mp4',
      ));

      // Add Thumbnail File if provided
      if (thumbnailFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'thumbnail', 
          thumbnailFile.path,
          filename: 'thumbnail.jpg',
        ));
      }

      // 3. Send Request
      debugPrint('Sending video to server for match $matchId...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        debugPrint('Server accepted video for processing.');
      } else {
        throw Exception('Server failed to accept video: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error uploading to server: $e');
      // If server upload fails, we should probably mark as not processing
      await _supabase.from('matches').update({'is_processing': false}).eq('id', matchId);
      rethrow;
    }
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
