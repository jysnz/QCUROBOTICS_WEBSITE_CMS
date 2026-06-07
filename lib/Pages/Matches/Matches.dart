import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../Services/video_service.dart';
import 'match_form.dart';

const _kResolutions = ['Original', '1080p', '720p', '480p', '360p'];

class MatchListSheet extends StatefulWidget {
  final int competitionId;
  final String competitionTitle;

  const MatchListSheet({
    super.key,
    required this.competitionId,
    required this.competitionTitle,
  });

  @override
  State<MatchListSheet> createState() => _MatchListSheetState();
}

class _MatchListSheetState extends State<MatchListSheet> {
  final _supabase = Supabase.instance.client;
  List<_MatchInfo>? _matches;
  List<_TeamInfo>? _teams;
  int? _selectedTeamId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchMatches(),
      _fetchTeams(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchTeams() async {
    try {
      final rows = await _supabase
          .from('team_competitions')
          .select('teams(id, team_name, team_number)')
          .eq('competition_id', widget.competitionId);

      final teams = (rows as List).map((r) {
        final team = r['teams'] as Map<String, dynamic>;
        return _TeamInfo(
          id: team['id'],
          name: team['team_name'] ?? '',
          number: team['team_number'] ?? 0,
        );
      }).toList();

      if (mounted) setState(() => _teams = teams);
    } catch (e) {
      debugPrint('[_fetchTeams] Error fetching teams: $e');
    }
  }

  Future<void> _fetchMatches() async {
    debugPrint('[_fetchMatches] Fetching matches for competitionId: ${widget.competitionId}');
    try {
      final rows = await _supabase
          .from('matches')
          .select('''
            id,
            competition_id,
            name,
            our_score,
            opponent_score,
            opponent_name,
            result,
            video_url,
            thumbnail,
            sequence,
            team_id,
            is_processing
          ''')
          .eq('competition_id', widget.competitionId)
          .order('sequence', ascending: true);

      debugPrint('[_fetchMatches] Successfully fetched ${rows.length} matches');

      final List<_MatchInfo> matches = (rows as List).map<_MatchInfo>((r) {
        final map = r as Map<String, dynamic>;
        return _MatchInfo(
          id: map['id'],
          competitionId: map['competition_id'] ?? widget.competitionId,
          name: map['name'] ?? '',
          ourScore: map['our_score'],
          opponentScore: map['opponent_score'],
          opponentName: map['opponent_name'] ?? '',
          result: map['result'] ?? '',
          videoUrl: map['video_url'],
          thumbnail: map['thumbnail'],
          sequence: map['sequence'],
          teamId: map['team_id'],
          isProcessing: map['is_processing'] ?? false,
        );
      }).toList();

      if (mounted) setState(() => _matches = matches);
    } catch (e) {
      debugPrint('[_fetchMatches] Error fetching matches: $e');
    }
  }

  Map<int?, List<_MatchInfo>> get _groupedMatches {
    if (_matches == null) return {};
    final grouped = <int?, List<_MatchInfo>>{};
    
    if (_selectedTeamId != null) {
      grouped[_selectedTeamId] = _matches!.where((m) => m.teamId == _selectedTeamId).toList();
    } else {
      for (final match in _matches!) {
        grouped.putIfAbsent(match.teamId, () => []).add(match);
      }
    }
    return grouped;
  }

  String _getTeamDisplayName(int? teamId) {
    if (teamId == null) return 'Unassigned Matches';
    final team = _teams?.firstWhere((t) => t.id == teamId, 
      orElse: () => _TeamInfo(id: teamId, name: 'Unknown Team', number: 0));
    if (team == null || (team.number == 0 && team.name == 'Unknown Team')) return 'Unassigned Matches';
    return team.number == 0 ? team.name : 'Team ${team.number}: ${team.name}';
  }

  void _showAddMatch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchForm(
        competitionId: widget.competitionId,
        teams: _teams ?? [],
      ),
    ).then((value) {
      if (value == true) _fetchMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final groupedMatches = _groupedMatches;
    final totalMatches = _matches?.length ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0B1020),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.competitionTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showAddMatch,
                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFBBF24)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_teams != null && _teams!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedTeamId,
                        hint: const Text(
                          'All Teams',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        dropdownColor: const Color(0xFF1F2937),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Teams', style: TextStyle(color: Colors.white)),
                          ),
                          ..._teams!.map((_TeamInfo team) => DropdownMenuItem<int?>(
                                value: team.id,
                                child: Text(
                                  'Team ${team.number}: ${team.name}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedTeamId = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _selectedTeamId == null 
                    ? '$totalMatches total match${totalMatches == 1 ? '' : 'es'}'
                    : '${groupedMatches[_selectedTeamId]?.length ?? 0} match${groupedMatches[_selectedTeamId]?.length == 1 ? '' : 'es'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (groupedMatches.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              size: 48, color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTeamId == null ? 'No matches yet' : 'No matches for this team',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: groupedMatches.length,
                      itemBuilder: (context, groupIndex) {
                        final teamId = groupedMatches.keys.elementAt(groupIndex);
                        final matches = groupedMatches[teamId]!;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_selectedTeamId == null) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 8, bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFBBF24),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _getTeamDisplayName(teamId),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${matches.length} matches',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            ...matches.map((match) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MatchCard(
                                match: match,
                                teams: _teams ?? [],
                                onUpdate: _fetchMatches,
                              ),
                            )),
                            const SizedBox(height: 10),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamInfo {
  final int id;
  final String name;
  final int number;

  _TeamInfo({required this.id, required this.name, required this.number});
}

class _MatchInfo {
  final int id;
  final int competitionId;
  final String name;
  final int? ourScore;
  final int? opponentScore;
  final String opponentName;
  final String result;
  final String? videoUrl;
  final String? thumbnail;
  final int? sequence;
  final dynamic teamId;
  final bool isProcessing;

  const _MatchInfo({
    required this.id,
    required this.competitionId,
    required this.name,
    this.ourScore,
    this.opponentScore,
    required this.opponentName,
    required this.result,
    this.videoUrl,
    this.thumbnail,
    this.sequence,
    this.teamId,
    this.isProcessing = false,
  });
}

class _MatchCard extends StatefulWidget {
  final _MatchInfo match;
  final List<_TeamInfo> teams;
  final VoidCallback onUpdate;

  const _MatchCard({
    required this.match,
    required this.teams,
    required this.onUpdate,
  });

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  final _supabase = Supabase.instance.client;
  String _selectedResolution = 'Original';
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isPlaying = false;
  bool _isInitializing = false;

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Color _resultColor(String result) {
    switch (result.toLowerCase()) {
      case 'win':
        return const Color(0xFF34D399);
      case 'loss':
        return const Color(0xFFF87171);
      default:
        return Colors.white.withValues(alpha: 0.45);
    }
  }

  Future<void> _openExternal() async {
    final url = widget.match.videoUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showEditForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MatchForm(
        competitionId: widget.match.competitionId, 
        teams: widget.teams,
        match: {
          'id': widget.match.id,
          'competition_id': widget.match.competitionId,
          'name': widget.match.name,
          'our_score': widget.match.ourScore,
          'opponent_score': widget.match.opponentScore,
          'opponent_name': widget.match.opponentName,
          'team_id': widget.match.teamId,
          'video_url': widget.match.videoUrl,
          'thumbnail': widget.match.thumbnail,
          'is_processing': widget.match.isProcessing,
        },
      ),
    ).then((value) {
      if (value == true) widget.onUpdate();
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text('Delete Match', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this match replay?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clean up storage assets first
        await VideoService.deleteMatchAssets(widget.match.name);
        
        await _supabase.from('matches').delete().eq('id', widget.match.id);
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting match: $e')));
        }
      }
    }
  }

  Future<void> _playVideo() async {
    debugPrint('[_playVideo] START - Match ID: ${widget.match.id}');
    if (widget.match.isProcessing) {
      debugPrint('[_playVideo] ABORT - Video is still processing');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is still processing. Please try again later.')),
      );
      return;
    }

    final url = widget.match.videoUrl;
    debugPrint('[_playVideo] URL: $url');
    if (url == null || url.isEmpty) {
      debugPrint('[_playVideo] ERROR - Video URL is null or empty');
      return;
    }

    setState(() {
      _isPlaying = true;
      _isInitializing = true;
    });

    try {
      debugPrint('[_playVideo] Checking cache...');
      final FileInfo? cacheInfo = await DefaultCacheManager().getFileFromCache(url);
      
      if (cacheInfo != null) {
        debugPrint('[_playVideo] SUCCESS - Playing from CACHE: ${cacheInfo.file.path}');
        _videoPlayerController = VideoPlayerController.file(cacheInfo.file);
      } else {
        debugPrint('[_playVideo] MISS - Cache missing. Attempting NETWORK playback.');
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
        
        debugPrint('[_playVideo] Starting background download task...');
        DefaultCacheManager().downloadFile(url, key: url).then((_) {
          debugPrint('[_playVideo] BACKGROUND CACHE COMPLETE: $url');
        }).catchError((e) {
          debugPrint('[_playVideo] BACKGROUND CACHE FAILED: $e');
        });
      }

      debugPrint('[_playVideo] Initializing VideoPlayerController...');
      await _videoPlayerController!.initialize();
      debugPrint('[_playVideo] VideoPlayerController INITIALIZED');
      
      debugPrint('[_playVideo] Creating ChewieController...');
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFFBBF24),
          handleColor: const Color(0xFFFBBF24),
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          bufferedColor: Colors.white.withValues(alpha: 0.4),
        ),
        placeholder: _thumbnailPlaceholder(),
        errorBuilder: (context, errorMessage) {
          debugPrint('[_playVideo] CHEWIE ERROR BUILDER TRIGGERED: $errorMessage');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Video Playback Error',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openExternal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFBBF24),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Open in Browser', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      );
      debugPrint('[_playVideo] ChewieController CREATED');

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('[_playVideo] CATCH BLOCK TRIGGERED: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            action: SnackBarAction(
              label: 'Open Browser',
              onPressed: _openExternal,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final hasVideo = match.videoUrl != null && match.videoUrl!.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _isPlaying
                    ? (_isInitializing
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFBBF24)))
                        : Chewie(controller: _chewieController!))
                    : (match.thumbnail != null && match.thumbnail!.isNotEmpty
                        ? Image.network(
                            match.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('[_MatchCard] Error loading thumbnail: $error');
                              return _thumbnailPlaceholder();
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                            },
                          )
                        : _thumbnailPlaceholder()),
              ),
              if (hasVideo && !_isPlaying)
                Positioned.fill(
                  child: Center(
                    child: match.isProcessing
                        ? Container(
                            color: Colors.black54,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.hourglass_empty, color: Colors.white70, size: 40),
                                const SizedBox(height: 10),
                                const Text(
                                  'Video is processing...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: Text(
                                    'This may take a few minutes.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _PlayButton(onTap: _playVideo),
                  ),
                ),
              if (!_isPlaying || _isInitializing)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      match.name.isEmpty ? 'Match ${match.sequence ?? ""}' : match.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _showEditForm,
                      icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.all(8)),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete, color: Color(0xFFF87171), size: 18),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.all(8)),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.opponentName.isEmpty ? 'Unknown Opponent' : match.opponentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opponent Team',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (match.ourScore != null && match.opponentScore != null) ...[
                              Text(
                                '${match.ourScore}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '-',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                '${match.opponentScore}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (match.result.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _resultColor(match.result).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _resultColor(match.result).withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                match.result.toUpperCase(),
                                style: TextStyle(
                                  color: _resultColor(match.result),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (hasVideo && !match.isProcessing) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.hd_outlined, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(width: 8),
                      Text(
                        'Playback Resolution',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedResolution,
                            dropdownColor: const Color(0xFF1F2937),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
                            items: [
                              for (final r in _kResolutions)
                                DropdownMenuItem(value: r, child: Text(r)),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedResolution = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF111827),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_esports_rounded,
              color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
              size: 42,
            ),
            const SizedBox(height: 8),
            Text(
              'No Thumbnail',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
      ),
    );
  }
}
