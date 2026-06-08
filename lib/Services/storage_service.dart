import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Widgets/design_system.dart';

class StorageService {
  static Future<String> uploadMemberPicture({
    required SupabaseClient supabase,
    required XFile image,
    required String folder,
    required String personName,
  }) async {
    return uploadFile(
      supabase: supabase,
      bucket: 'member-pictures',
      folder: folder,
      file: image,
      customName: personName,
    );
  }

  static Future<String> uploadFile({
    required SupabaseClient supabase,
    required String bucket,
    required String folder,
    required XFile file,
    String? customName,
    String? oldPath,
  }) async {
    // Delete old file if provided
    if (oldPath != null && oldPath.isNotEmpty) {
      try {
        final uri = Uri.parse(oldPath);
        final pathSegments = uri.pathSegments;
        // The path in the bucket usually starts after 'public' and bucket name
        // Depending on how getPublicUrl is structured.
        // Usually: /storage/v1/object/public/bucket-name/folder/filename
        final bucketIndex = pathSegments.indexOf(bucket);
        if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
          final actualPath = pathSegments.sublist(bucketIndex + 1).join('/');
          // Remove query params if any
          final cleanPath = actualPath.split('?').first;
          await supabase.storage.from(bucket).remove([cleanPath]);
        }
      } catch (e) {
        debugPrint('Error deleting old file: $e');
      }
    }

    final bytes = await file.readAsBytes();
    final extension = _fileExtension(file.name);
    final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    
    String fileName;
    if (customName != null && customName.trim().isNotEmpty) {
      final safeName = customName
          .trim()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      fileName = '$safeFolder/$safeName$extension';
    } else {
      fileName = '$safeFolder/${DateTime.now().microsecondsSinceEpoch}$extension';
    }

    await supabase.storage
        .from(bucket)
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(extension),
            upsert: true,
          ),
        );

    final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  static Future<void> deleteFile({
    required SupabaseClient supabase,
    required String bucket,
    required String path,
  }) async {
    try {
      // If path is a full URL, extract the relative path
      String cleanPath = path;
      if (path.startsWith('http')) {
        final uri = Uri.parse(path);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf(bucket);
        if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
          cleanPath = pathSegments.sublist(bucketIndex + 1).join('/');
        }
      }
      cleanPath = cleanPath.split('?').first;
      await supabase.storage.from(bucket).remove([cleanPath]);
    } catch (e) {
      debugPrint('Error deleting file: $e');
      rethrow;
    }
  }

  static Future<List<FileObject>> listFiles({
    required SupabaseClient supabase,
    required String bucket,
    required String folder,
  }) async {
    return await supabase.storage.from(bucket).list(path: folder);
  }

  static String getPublicUrl({
    required SupabaseClient supabase,
    required String bucket,
    required String path,
  }) {
    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  static String _fileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex == -1 ? '.jpg' : fileName.substring(dotIndex);
  }

  static String _contentTypeForExtension(String extension) {
    switch (extension.toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.heic':
        return 'image/heic';
      case '.jpg':
      case '.jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

Future<bool?> showPhotoConfirmDialog({
  required BuildContext context,
  required String url,
  required String name,
  Color accentColor = kAccent,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF34D399), size: 48),
          const SizedBox(height: 18),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      actions: [
        TechnicalButton(
          label: 'Acknowledge',
          onTap: () => Navigator.of(ctx).pop(true),
          color: accentColor,
        ),
      ],
    ),
  );
}
