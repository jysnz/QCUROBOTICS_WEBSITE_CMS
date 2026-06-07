import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../Services/video_service.dart';
import '../../Widgets/design_system.dart';
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
    if (teamId == null) return 'Unassigned';
    final team = _teams?.firstWhere((t) => t.id == teamId, 
      orElse: () => _TeamInfo(id: teamId, name: 'Unknown', number: 0));
    if (team == null || (team.number == 0 && team.name == 'Unknown')) return 'Unassigned';
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

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MATCHES',
                            style: TextStyle(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            widget.competitionTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showAddMatch,
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFFBBF24)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              if (_teams != null && _teams!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: kBackground.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedTeamId,
                        hint: Text(
                          'Filter by Team',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        dropdownColor: kSurface,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFFBBF24)),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Teams', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          ..._teams!.map((_TeamInfo team) => DropdownMenuItem<int?>(
                                value: team.id,
                                child: Text(
                                  'Team ${team.number}: ${team.name}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedTeamId = value);
                        },
                      ),
                    ),
                  ),
                ),
              ],
              Flexible(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)))
                    : groupedMatches.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No matches found',
                                    style: TextStyle(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            itemCount: groupedMatches.length,
                            itemBuilder: (context, groupIndex) {
                              final teamId = groupedMatches.keys.elementAt(groupIndex);
                              final matches = groupedMatches[teamId]!;
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_selectedTeamId == null) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                                      child: Row(
                                        children: [
                                          Container(width: 2, height: 12, color: const Color(0xFFFBBF24)),
                                          const SizedBox(width: 8),
                                          Text(
                                            _getTeamDisplayName(teamId),
                                            style: const TextStyle(
                                              color: Color(0xFFFBBF24),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${matches.length} matches',
                                            style: TextStyle(
                                              color: Colors.white24,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  ...matches.map((match) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _MatchCard(
                                      match: match,
                                      teams: _teams ?? [],
                                      onUpdate: _fetchMatches,
                                    ),
                                  )),
                                ],
                              );
                            },
                          ),
              ),
            ],
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
        return const Color(0xFF10B981);
      case 'loss':
        return const Color(0xFFF87171);
      default:
        return Colors.white24;
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
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: const Text('Delete Match', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to delete this match?', style: TextStyle(color: Colors.white70, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await VideoService.deleteMatchAssets(widget.match.name);
        await _supabase.from('matches').delete().eq('id', widget.match.id);
        widget.onUpdate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _playVideo() async {
    if (widget.match.isProcessing) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
          title: const Text('Video Processing', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          content: const Text(
            'This video is still being processed. Please try again in a few minutes.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      return;
    }

    final url = widget.match.videoUrl;
    if (url == null || url.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _isInitializing = true;
    });

    try {
      final FileInfo? cacheInfo = await DefaultCacheManager().getFileFromCache(url);
      
      if (cacheInfo != null) {
        _videoPlayerController = VideoPlayerController.file(cacheInfo.file);
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
        DefaultCacheManager().downloadFile(url, key: url).catchError((Object e) => debugPrint(e.toString()));
      }

      await _videoPlayerController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFFBBF24),
          handleColor: const Color(0xFFFBBF24),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          bufferedColor: Colors.white.withValues(alpha: 0.2),
        ),
        placeholder: _thumbnailPlaceholder(),
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final hasVideo = match.videoUrl != null && match.videoUrl!.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: kBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                            errorBuilder: (context, error, stackTrace) => _thumbnailPlaceholder(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)));
                            },
                          )
                        : _thumbnailPlaceholder()),
              ),
              if (hasVideo && !_isPlaying)
                Positioned.fill(
                  child: Center(
                    child: match.isProcessing
                        ? Container(
                            color: Colors.black87,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sync_rounded, color: Color(0xFFFBBF24), size: 32),
                                SizedBox(height: 12),
                                Text(
                                  'Processing...',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          )
                        : _PlayButton(onTap: _playVideo),
                  ),
                ),
              if (!_isPlaying || _isInitializing)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      match.name.isEmpty ? 'Match ${match.sequence ?? ""}' : match.name,
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    _SmallActionBtn(icon: Icons.edit_note_rounded, onTap: _showEditForm),
                    const SizedBox(width: 6),
                    _SmallActionBtn(icon: Icons.delete_sweep_rounded, onTap: _confirmDelete, color: const Color(0xFFF87171)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Opponent',
                            style: TextStyle(
                              color: Colors.white24,
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
                        if (match.ourScore != null && match.opponentScore != null)
                          Text(
                            '${match.ourScore} : ${match.opponentScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Monospace',
                            ),
                          ),
                        if (match.result.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _resultColor(match.result).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                match.result.toUpperCase(),
                                style: TextStyle(
                                  color: _resultColor(match.result),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (hasVideo && !match.isProcessing) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.video_settings_outlined, size: 14, color: Colors.white24),
                      const SizedBox(width: 8),
                      Text(
                        'Video Quality',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedResolution,
                          dropdownColor: kSurface,
                          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w800),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFFFBBF24)),
                          items: [
                            for (final r in _kResolutions)
                              DropdownMenuItem(value: r, child: Text(r)),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedResolution = v);
                          },
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
      color: kBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              color: Colors.white.withValues(alpha: 0.05),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No Video',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.1),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _SmallActionBtn({required this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Icon(icon, color: color.withValues(alpha: 0.8), size: 16),
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
              blurRadius: 15,
            ),
          ],
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
      ),
    );
  }
}
