import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    debugPrint('[_fetchMatches] Fetching matches for competitionId: ${widget.competitionId}');
    setState(() => _isLoading = true);
    try {
      final rows = await _supabase
          .from('matches')
          .select('''
            id,
            name,
            our_score,
            opponent_score,
            opponent_name,
            result,
            video_url,
            thumbnail,
            sequence,
            team_id
          ''')
          .eq('competition_id', widget.competitionId)
          .order('sequence', ascending: true);

      debugPrint('[_fetchMatches] Successfully fetched ${rows.length} matches');
      if (rows.isNotEmpty) {
        debugPrint('[_fetchMatches] First match data: ${rows.first}');
      }

      final matches = (rows as List).map((r) => _MatchInfo(
        id: r['id'],
        name: r['name'] ?? '',
        ourScore: r['our_score'],
        opponentScore: r['opponent_score'],
        opponentName: r['opponent_name'] ?? '',
        result: r['result'] ?? '',
        videoUrl: r['video_url'],
        thumbnail: r['thumbnail'],
        sequence: r['sequence'],
        teamId: r['team_id'],
      )).toList();

      if (mounted) setState(() => _matches = matches);
    } catch (e) {
      debugPrint('[_fetchMatches] Error fetching matches: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_matches?.length ?? 0} match${_matches?.length == 1 ? '' : 'es'}',
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
                else if (_matches == null || _matches!.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              size: 48, color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          Text(
                            'No matches yet',
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
                    child: ListView.separated(
                      itemCount: _matches!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final match = _matches![index];
                        return _MatchCard(match: match);
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

class _MatchCard extends StatefulWidget {
  final _MatchInfo match;

  const _MatchCard({required this.match});

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
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

  Future<void> _playVideo() async {
    final url = widget.match.videoUrl;
    debugPrint('[_playVideo] Attempting to play video in-app from URL: $url');

    if (url == null || url.isEmpty) {
      debugPrint('[_playVideo] Error: Video URL is null or empty');
      return;
    }

    setState(() {
      _isPlaying = true;
      _isInitializing = true;
    });

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoPlayerController!.initialize();
      
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white60, size: 32),
                const SizedBox(height: 8),
                Text(
                  'The video cannot be played: $errorMessage',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('[_playVideo] Exception occurred during initialization: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('The video cannot be played: $e')),
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
          // Row 1: Video / Thumbnail
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
                            errorBuilder: (_, __, ___) => _thumbnailPlaceholder(),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return _thumbnailPlaceholder();
                            },
                          )
                        : _thumbnailPlaceholder()),
              ),
              if (hasVideo && !_isPlaying)
                Positioned.fill(
                  child: Center(
                    child: _PlayButton(onTap: _playVideo),
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
            ],
          ),

          // Row 2: Details
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
                if (hasVideo) ...[
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

class _MatchInfo {
  final int id;
  final String name;
  final int? ourScore;
  final int? opponentScore;
  final String opponentName;
  final String result;
  final String? videoUrl;
  final String? thumbnail;
  final int? sequence;
  final dynamic teamId;

  const _MatchInfo({
    required this.id,
    required this.name,
    this.ourScore,
    this.opponentScore,
    required this.opponentName,
    required this.result,
    this.videoUrl,
    this.thumbnail,
    this.sequence,
    this.teamId,
  });
}
