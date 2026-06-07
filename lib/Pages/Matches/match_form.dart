import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../Services/video_service.dart';
import '../../Widgets/design_system.dart';

class MatchForm extends StatefulWidget {
  final int competitionId;
  final Map<String, dynamic>? match; // null for add, not null for edit
  final List<dynamic> teams;

  const MatchForm({
    super.key,
    required this.competitionId,
    this.match,
    required this.teams,
  });

  @override
  State<MatchForm> createState() => _MatchFormState();
}

class _MatchFormState extends State<MatchForm> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _ourScoreController;
  late TextEditingController _opponentScoreController;
  late TextEditingController _opponentNameController;
  
  int? _selectedTeamId;
  File? _videoFile;
  File? _thumbnailFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.match?['name'] ?? '');
    _ourScoreController = TextEditingController(text: (widget.match?['our_score'] ?? 0).toString());
    _opponentScoreController = TextEditingController(text: (widget.match?['opponent_score'] ?? 0).toString());
    _opponentNameController = TextEditingController(text: widget.match?['opponent_name'] ?? '');
    _selectedTeamId = widget.match?['team_id'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ourScoreController.dispose();
    _opponentScoreController.dispose();
    _opponentNameController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _videoFile = File(video.path));
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _thumbnailFile = File(image.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? videoUrl = widget.match?['video_url'];
      String? thumbnailUrl = widget.match?['thumbnail'];

      final data = {
        'competition_id': widget.competitionId,
        'name': _nameController.text.trim(),
        'our_score': int.tryParse(_ourScoreController.text) ?? 0,
        'opponent_score': int.tryParse(_opponentScoreController.text) ?? 0,
        'opponent_name': _opponentNameController.text.trim(),
        'team_id': _selectedTeamId,
        'video_url': videoUrl,
        'thumbnail': thumbnailUrl,
        'is_processing': _videoFile != null, 
      };

      int matchId;
      if (widget.match == null) {
        final response = await _supabase.from('matches').insert(data).select().single();
        matchId = response['id'];
      } else {
        matchId = widget.match!['id'];
        await _supabase.from('matches').update(data).eq('id', matchId);
      }

      if (_videoFile != null) {
        await VideoService.uploadAndProcess(
          videoFile: _videoFile!,
          matchName: _nameController.text.trim(),
          matchId: matchId,
          thumbnailFile: _thumbnailFile,
          oldMatchName: widget.match?['name'],
        );
      } else if (_thumbnailFile != null) {
        final sanitizedName = VideoService.sanitizeName(_nameController.text.trim());
        final path = '$sanitizedName/thumbnail.jpg';
        await _supabase.storage.from('competition_matches').upload(
          path, 
          _thumbnailFile!,
          fileOptions: const FileOptions(upsert: true),
        );
        thumbnailUrl = _supabase.storage.from('competition_matches').getPublicUrl(path);
        await _supabase.from('matches').update({'thumbnail': thumbnailUrl}).eq('id', matchId);
      }

      if (mounted) {
        if (_videoFile != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: kSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
              title: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, color: Color(0xFFFBBF24)),
                  SizedBox(width: 10),
                  Text('LINK ESTABLISHED', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
              content: const Text(
                'Telemetry feed has been routed to processing servers. Background encoding initialized.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ACKNOWLEDGE', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ],
            ),
          );
        }
        
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PROTOCOL ERROR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (widget.match == null ? 'Initialize Log' : 'Edit Log').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Log Designation'),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  validator: (v) => v == null || v.isEmpty ? 'REQUIRED' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedTeamId,
                  dropdownColor: kSurface,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: _inputDecoration('Operational Squad'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('UNASSIGNED TEAM')),
                    ...widget.teams.map((t) => DropdownMenuItem(value: t.id as int, child: Text('TEAM ${t.number}: ${t.name.toUpperCase()}'))),
                  ],
                  onChanged: (v) => setState(() => _selectedTeamId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ourScoreController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Home Score'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _opponentScoreController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Target Score'),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opponentNameController,
                  decoration: _inputDecoration('Target Designation'),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: _AssetBtn(
                        label: 'FEED',
                        isSelected: _videoFile != null,
                        icon: Icons.videocam_outlined,
                        onTap: _pickVideo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AssetBtn(
                        label: 'THUMB',
                        isSelected: _thumbnailFile != null,
                        icon: Icons.image_outlined,
                        onTap: _pickThumbnail,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                TechnicalButton(
                  label: _isSaving ? 'PROCESSING...' : 'EXECUTE COMMAND',
                  onTap: _isSaving ? () {} : _save,
                  isLoading: _isSaving,
                  color: const Color(0xFFFBBF24),
                ),
                if (widget.match != null) ...[
                  const SizedBox(height: 12),
                  TechnicalButton(
                    label: 'TERMINATE RECORD',
                    onTap: _isSaving ? () {} : _confirmDelete,
                    color: const Color(0xFFF87171),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final matchName = widget.match?['name'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: const Text('Delete Match', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this match? This action cannot be undone.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            Text('Type "$matchName" to confirm:', style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: kBackground.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFF87171))),
                hintText: 'Enter match title',
                hintStyle: const TextStyle(color: Colors.white10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w700))),
          ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              final canDelete = controller.text.trim() == matchName;
              return TextButton(
                onPressed: canDelete ? () => Navigator.pop(context, true) : null,
                child: Text('Delete', style: TextStyle(color: canDelete ? const Color(0xFFF87171) : Colors.white10, fontSize: 13, fontWeight: FontWeight.w800)),
              );
            },
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        await VideoService.deleteMatchAssets(matchName);
        await _supabase.from('matches').delete().eq('id', widget.match!['id']);
        if (mounted) Navigator.of(context).pop(true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label.toUpperCase(),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
      filled: true,
      fillColor: kBackground.withValues(alpha: 0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: Color(0xFFFBBF24), width: 1.0),
      ),
    );
  }
}

class _AssetBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _AssetBtn({required this.label, required this.isSelected, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFBBF24).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: isSelected ? const Color(0xFFFBBF24).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFBBF24) : Colors.white38, size: 18),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(color: isSelected ? const Color(0xFFFBBF24) : Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0),
            ),
          ],
        ),
      ),
    );
  }
}
