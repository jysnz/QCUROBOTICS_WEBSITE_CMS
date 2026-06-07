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
    final bytes = await image.readAsBytes();
    final extension = _fileExtension(image.name);
    final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeName = personName
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = safeName.isEmpty
        ? '$safeFolder/${DateTime.now().microsecondsSinceEpoch}$extension'
        : '$safeFolder/$safeName$extension';

    await supabase.storage
        .from('member-pictures')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeForExtension(extension),
            upsert: true,
          ),
        );

    final publicUrl = supabase.storage.from('member-pictures').getPublicUrl(fileName);
    return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
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
