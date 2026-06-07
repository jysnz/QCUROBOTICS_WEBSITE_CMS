import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../Services/video_service.dart';

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

    // Validation: Ensure video is provided for new matches or preserved for existing ones
    if (_videoFile == null && (widget.match == null || widget.match!['video_url'] == null)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Video Required', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You haven\'t added a video for this match. Please select a video before saving.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFFFBBF24))),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? videoUrl = widget.match?['video_url'];
      String? thumbnailUrl = widget.match?['thumbnail'];

      final data = {
        'competition_id': widget.competitionId,
        'name': _nameController.text,
        'our_score': int.parse(_ourScoreController.text),
        'opponent_score': int.parse(_opponentScoreController.text),
        'opponent_name': _opponentNameController.text,
        'team_id': _selectedTeamId,
        'video_url': videoUrl,
        'thumbnail': thumbnailUrl,
        'is_processing': _videoFile != null, // Mark as processing if new video is uploaded
      };

      int matchId;
      if (widget.match == null) {
        final response = await _supabase.from('matches').insert(data).select().single();
        matchId = response['id'];
      } else {
        matchId = widget.match!['id'];
        await _supabase.from('matches').update(data).eq('id', matchId);
      }

      // Handle video upload and remote processing trigger
      if (_videoFile != null) {
        await VideoService.uploadAndProcess(
          videoFile: _videoFile!,
          matchName: _nameController.text,
          matchId: matchId,
          oldMatchName: widget.match?['name'],
        );
      } else if (_thumbnailFile != null) {
        // Handle manual thumbnail upload
        final sanitizedName = VideoService.sanitizeName(_nameController.text);
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
        Navigator.of(context).pop(true);
        if (_videoFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video is uploading. Processing will happen in the background.')),
          );
        }
      }
    } catch (e) {

      if (mounted) {
        Navigator.of(context).pop(true);
        if (_videoFile != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match saved! Video has been processed and is ready.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving match: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving match: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1020),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.match == null ? 'Add Match' : 'Edit Match',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Match Name', labelStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                value: _selectedTeamId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('No Team')),
                  ...widget.teams.map((t) => DropdownMenuItem(value: t.id as int, child: Text('Team ${t.number}: ${t.name}'))),
                ],
                onChanged: (v) => setState(() => _selectedTeamId = v),
                decoration: const InputDecoration(labelText: 'Team', labelStyle: TextStyle(color: Colors.white70)),
                dropdownColor: const Color(0xFF1F2937),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ourScoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Our Score', labelStyle: TextStyle(color: Colors.white70)),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _opponentScoreController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Opponent Score', labelStyle: TextStyle(color: Colors.white70)),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _opponentNameController,
                decoration: const InputDecoration(labelText: 'Opponent Name', labelStyle: TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.video_library),
                      label: Text(_videoFile != null ? 'Video Selected' : 'Pick Video'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickThumbnail,
                      icon: const Icon(Icons.image),
                      label: Text(_thumbnailFile != null ? 'Thumb Selected' : 'Pick Thumb'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving ? const CircularProgressIndicator() : const Text('Save Match'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
