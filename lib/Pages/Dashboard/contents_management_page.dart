import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
import 'package:qcurobotics_management_app/Services/storage_service.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';

class ContentsManagementPage extends StatefulWidget {
  const ContentsManagementPage({super.key});

  @override
  State<ContentsManagementPage> createState() => _ContentsManagementPageState();
}

class _ContentsManagementPageState extends State<ContentsManagementPage> {
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  final _cache = CacheService();

  static const String _carouselCacheKey = 'contents_carousel_images';
  static const String _aboutCacheKey = 'contents_about_images';
  static const Duration _cacheMaxAge = Duration(hours: 1);

  bool _isCarouselLoading = true;
  bool _isAboutLoading = true;
  List<String> _carouselImages = [];
  List<String> _aboutImages = [];

  @override
  void initState() {
    super.initState();
    _loadAllContents();
  }

  Future<void> _loadAllContents() async {
    // Try to load from cache first for immediate UI update
    final cachedCarousel = await _cache.getData(_carouselCacheKey);
    final cachedAbout = await _cache.getData(_aboutCacheKey);

    if (mounted) {
      setState(() {
        if (cachedCarousel != null) {
          _carouselImages = List<String>.from(cachedCarousel);
          _isCarouselLoading = false;
        }
        if (cachedAbout != null) {
          _aboutImages = List<String>.from(cachedAbout);
          _isAboutLoading = false;
        }
      });
    }

    // Then fetch fresh data
    await Future.wait([
      _loadCarouselImages(forceRefresh: true),
      _loadAboutImages(forceRefresh: true),
    ]);
  }

  Future<void> _loadCarouselImages({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.getData(_carouselCacheKey, maxAge: _cacheMaxAge);
      if (cached != null && mounted) {
        setState(() {
          _carouselImages = List<String>.from(cached);
          _isCarouselLoading = false;
        });
        return;
      }
    }

    setState(() => _isCarouselLoading = true);
    try {
      final files = await StorageService.listFiles(
        supabase: _supabase,
        bucket: 'images',
        folder: 'Carousel_pictures',
      );
      
      final urls = files
          .where((f) => f.name != '.emptyFolderPlaceholder')
          .map((f) => StorageService.getPublicUrl(
                supabase: _supabase,
                bucket: 'images',
                path: 'Carousel_pictures/${f.name}',
              ))
          .toList();

      await _cache.saveData(_carouselCacheKey, urls);

      if (mounted) {
        setState(() {
          _carouselImages = urls;
          _isCarouselLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading carousel: $e')),
        );
        setState(() => _isCarouselLoading = false);
      }
    }
  }

  Future<void> _loadAboutImages({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cache.getData(_aboutCacheKey, maxAge: _cacheMaxAge);
      if (cached != null && mounted) {
        setState(() {
          _aboutImages = List<String>.from(cached);
          _isAboutLoading = false;
        });
        return;
      }
    }

    setState(() => _isAboutLoading = true);
    try {
      final files = await StorageService.listFiles(
        supabase: _supabase,
        bucket: 'images',
        folder: 'About_pictures',
      );
      
      final urls = files
          .where((f) => f.name != '.emptyFolderPlaceholder')
          .map((f) => StorageService.getPublicUrl(
                supabase: _supabase,
                bucket: 'images',
                path: 'About_pictures/${f.name}',
              ))
          .toList();

      await _cache.saveData(_aboutCacheKey, urls);

      if (mounted) {
        setState(() {
          _aboutImages = urls;
          _isAboutLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading about images: $e')),
        );
        setState(() => _isAboutLoading = false);
      }
    }
  }

  Future<bool?> _showConfirmUploadDialog(XFile image, String title) async {
    try {
      final bytes = await image.readAsBytes();
      if (!mounted) return false;

      return await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: kSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Review selected image', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    height: 250,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: kAccent.withValues(alpha: 0.1),
                  foregroundColor: kAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing preview: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _addImage(String folder) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final confirmed = await _showConfirmUploadDialog(image, 'Add to ${folder.split('_').first}');
      if (confirmed != true) return;

      final bool isCarousel = folder == 'Carousel_pictures';
      if (isCarousel) {
        setState(() => _isCarouselLoading = true);
      } else {
        setState(() => _isAboutLoading = true);
      }

      await StorageService.uploadFile(
        supabase: _supabase,
        bucket: 'images',
        folder: folder,
        file: image,
      );
      
      if (isCarousel) {
        await _loadCarouselImages(forceRefresh: true);
      } else {
        await _loadAboutImages(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
        setState(() {
          _isCarouselLoading = false;
          _isAboutLoading = false;
        });
      }
    }
  }

  Future<void> _editImage(String folder, String oldUrl) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final confirmed = await _showConfirmUploadDialog(image, 'Replace Image');
      if (confirmed != true) return;

      final bool isCarousel = folder == 'Carousel_pictures';
      if (isCarousel) {
        setState(() => _isCarouselLoading = true);
      } else {
        setState(() => _isAboutLoading = true);
      }

      await StorageService.uploadFile(
        supabase: _supabase,
        bucket: 'images',
        folder: folder,
        file: image,
        oldPath: oldUrl,
      );
      
      if (isCarousel) {
        await _loadCarouselImages(forceRefresh: true);
      } else {
        await _loadAboutImages(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
        setState(() {
          _isCarouselLoading = false;
          _isAboutLoading = false;
        });
      }
    }
  }

  Future<void> _deleteImage(String folder, String url) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Delete Image', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this image?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final bool isCarousel = folder == 'Carousel_pictures';
    if (isCarousel) {
      setState(() => _isCarouselLoading = true);
    } else {
      setState(() => _isAboutLoading = true);
    }

    try {
      await StorageService.deleteFile(
        supabase: _supabase,
        bucket: 'images',
        path: url,
      );
      if (isCarousel) {
        await _loadCarouselImages(forceRefresh: true);
      } else {
        await _loadAboutImages(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: $e')),
        );
        if (isCarousel) {
          setState(() => _isCarouselLoading = false);
        } else {
          setState(() => _isAboutLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const TechnicalGridBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadAllContents,
              backgroundColor: kSurface,
              color: kAccent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                _buildAppBar(),
                const SliverToBoxAdapter(
                  child: TechnicalSectionHeader(
                    label: 'Carousel Images',
                    color: Color(0xFF6366F1),
                  ),
                ),
                _buildImageGrid(
                  images: _carouselImages,
                  isLoading: _isCarouselLoading,
                  folder: 'Carousel_pictures',
                ),
                const SliverToBoxAdapter(
                  child: TechnicalSectionHeader(
                    label: 'About Us Images',
                    color: Color(0xFFEC4899),
                    topPadding: 32,
                  ),
                ),
                _buildImageGrid(
                  images: _aboutImages,
                  isLoading: _isAboutLoading,
                  folder: 'About_pictures',
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(kPadding),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTENTS',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    'MANAGEMENT',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid({
    required List<String> images,
    required bool isLoading,
    required String folder,
  }) {
    if (isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: kPadding),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => const Skeleton(height: 150, width: double.infinity),
            childCount: 4,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: kPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == images.length) {
              return _AddImageButton(onTap: () => _addImage(folder));
            }
            final url = images[index];
            return _ImageCard(
              url: url,
              onEdit: () => _editImage(folder, url),
              onDelete: () => _deleteImage(folder, url),
            );
          },
          childCount: images.length + 1,
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final String url;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ImageCard({
    required this.url,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TechnicalCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
              child: Image.network(
                url,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kSurface.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(kRadius)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(icon: Icons.edit_outlined, color: kAccent, onTap: onEdit),
                Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.05)),
                _ActionButton(icon: Icons.delete_outline_rounded, color: Colors.redAccent, onTap: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color.withValues(alpha: 0.7), size: 18),
    );
  }
}

class _AddImageButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddImageButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kAccent.withValues(alpha: 0.2), style: BorderStyle.none),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined, color: kAccent, size: 24),
            ),
            const SizedBox(height: 12),
            const Text(
              'ADD IMAGE',
              style: TextStyle(
                color: kAccent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
