import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qcurobotics_management_app/Pages/Matches/matches.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
import 'package:qcurobotics_management_app/Services/storage_service.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Tournaments extends StatefulWidget {
  const Tournaments({super.key});

  @override
  State<Tournaments> createState() => _TournamentsState();
}

class _TournamentsState extends State<Tournaments> {
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  static const String _cacheKey = 'tournaments_page_data';
  static const Duration _cacheDuration = Duration(hours: 1);

  late Future<_TournamentsPageData> _tournamentsFuture;
  Key _futureKey = UniqueKey();
  int? _selectedSeasonId;

  @override
  void initState() {
    super.initState();
    _tournamentsFuture = _loadTournamentsData();
  }

  Future<_TournamentsPageData> _loadTournamentsData() async {
    final cachedMap = await _cache.getData(_cacheKey);
    if (cachedMap != null) {
      try {
        final cachedData = _TournamentsPageData.fromMap(cachedMap);
        _cache.getData(_cacheKey, maxAge: _cacheDuration).then((fresh) {
          if (fresh == null) {
            _fetchAndCacheTournaments().then((freshData) {
              if (mounted) {
                setState(() {
                  _tournamentsFuture = Future.value(freshData);
                  _futureKey = UniqueKey();
                });
              }
            });
          }
        });
        return cachedData;
      } catch (e) {
        debugPrint('[_loadTournamentsData] cache error: $e');
      }
    }
    return _fetchAndCacheTournaments();
  }

  List<_SeasonInfo>? _cachedSeasons;

  Future<_TournamentsPageData> _fetchAndCacheTournaments() async {
    final results = await Future.wait([
      _supabase.from('competitions').select('''
        id,
        title,
        status,
        date,
        location,
        image_url,
        season_id,
        season:seasons(id, season_name)
      ''').order('date'),
      _supabase.from('seasons').select('id, season_name').order('id'),
    ]);

    final compRows = _asMapList(results[0]);
    final seasonRows = _asMapList(results[1]);

    final seasons = seasonRows.map((r) => _SeasonInfo(
      id: _intValue(r['id']) ?? 0,
      name: _displaySeasonName(r),
    )).toList();
    _cachedSeasons = seasons;

    final compsBySeason = <int, List<_CompetitionInfo>>{};
    for (final row in compRows) {
      final seasonId = _intValue(row['season_id']);
      final comp = _CompetitionInfo(
        id: _intValue(row['id']) ?? 0,
        title: _stringValue(row['title']),
        status: _stringValue(row['status']),
        date: _stringValue(row['date']),
        location: _stringValue(row['location']),
        imageUrl: _nullableString(row['image_url']),
        seasonId: seasonId,
      );
      final sid = seasonId ?? 0;
      compsBySeason.putIfAbsent(sid, () => []).add(comp);
    }

    final data = _TournamentsPageData(
      compsBySeason: compsBySeason,
      seasons: seasons,
    );

    await _cache.saveData(_cacheKey, data.toMap());
    return data;
  }

  Future<void> _refresh() async {
    await _cache.clearData(_cacheKey);
    final future = _fetchAndCacheTournaments();
    setState(() {
      _tournamentsFuture = future;
      _futureKey = UniqueKey();
    });
    await future;
  }

  Future<void> _reload() async {
    if (!mounted) return;
    await _cache.clearData(_cacheKey);
    final future = _fetchAndCacheTournaments();
    setState(() {
      _tournamentsFuture = future;
      _futureKey = UniqueKey();
    });
    await future;
  }

  Future<void> _openCompForm({Map<String, dynamic>? row, List<_SeasonInfo>? seasons, int? presetSeasonId}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompFormSheet(
        row: row,
        seasons: seasons ?? _cachedSeasons ?? const [],
        presetSeasonId: presetSeasonId,
      ),
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const TechnicalGridBackground(),
          SafeArea(
            child: FutureBuilder<_TournamentsPageData>(
              key: _futureKey,
              future: _tournamentsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: kSurface,
                  color: const Color(0xFFF59E0B),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(kPadding),
                          child: _TopBar(
                            isLoading: snapshot.connectionState == ConnectionState.waiting,
                          ),
                        ),
                      ),
                      if (snapshot.hasError)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _ErrorState(
                            message: snapshot.error.toString(),
                            onRetry: _refresh,
                          ),
                        )
                      else if (data == null)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: CompetitionSkeleton(),
                        )
                      else ...[
                        const SliverToBoxAdapter(
                          child: TechnicalSectionHeader(
                            label: 'Tournaments',
                            color: Color(0xFFF59E0B),
                            topPadding: 0,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _SeasonDropdown(
                            seasons: data.seasons,
                            selectedSeasonId: _selectedSeasonId,
                            onChanged: (id) {
                              setState(() {
                                _selectedSeasonId = id;
                              });
                            },
                          ),
                        ),
                        if (_selectedSeasonId == null) ...[
                          for (final season in data.seasons) ...[
                            _buildSeasonSection(data, season),
                          ],
                          if (data.compsBySeason.containsKey(0)) ...[
                            _buildSeasonSection(
                              data,
                              const _SeasonInfo(id: 0, name: 'Unassigned'),
                            ),
                          ],
                        ] else ...[
                          _buildSeasonSection(
                            data,
                            data.seasons.firstWhere(
                              (s) => s.id == _selectedSeasonId,
                              orElse: () => const _SeasonInfo(id: 0, name: 'Unassigned'),
                            ),
                          ),
                        ],
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: kBackground,
        onPressed: () => _openCompForm(seasons: _cachedSeasons),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSeasonSection(_TournamentsPageData data, _SeasonInfo season) {
    final comps = data.compsBySeason[season.id] ?? [];
    return SliverToBoxAdapter(
      child: _SeasonCard(
        season: season,
        competitions: comps,
        onEditComp: (comp) => _openCompForm(row: comp.toMap(), seasons: data.seasons),
        onAddComp: () => _openCompForm(seasons: data.seasons, presetSeasonId: season.id == 0 ? null : season.id),
      ),
    );
  }
}

class _MatchesButton extends StatelessWidget {
  final int competitionId;
  final String competitionTitle;

  const _MatchesButton({
    required this.competitionId,
    required this.competitionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MatchListSheet(
          competitionId: competitionId,
          competitionTitle: competitionTitle,
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_esports_rounded, size: 14, color: const Color(0xFFFBBF24).withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            const Text(
              'VIEW MATCHES',
              style: TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonInfo {
  final int id;
  final String name;
  const _SeasonInfo({required this.id, required this.name});
}

class _CompetitionInfo {
  final int id;
  final String title;
  final String status;
  final String date;
  final String location;
  final String? imageUrl;
  final int? seasonId;

  const _CompetitionInfo({
    required this.id,
    required this.title,
    required this.status,
    required this.date,
    required this.location,
    this.imageUrl,
    this.seasonId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'date': date,
      'location': location,
      'image_url': imageUrl,
      'season_id': seasonId,
    };
  }
}

class _TournamentsPageData {
  final Map<int, List<_CompetitionInfo>> compsBySeason;
  final List<_SeasonInfo> seasons;

  const _TournamentsPageData({
    required this.compsBySeason,
    required this.seasons,
  });

  int get totalCount {
    var count = 0;
    for (final list in compsBySeason.values) {
      count += list.length;
    }
    return count;
  }

  Map<String, dynamic> toMap() {
    return {
      'compsBySeason': compsBySeason.map(
        (k, v) => MapEntry(k.toString(), v.map((t) => t.toMap()).toList()),
      ),
      'seasons': seasons
          .map((s) => {'id': s.id, 'season_name': s.name})
          .toList(),
    };
  }

  factory _TournamentsPageData.fromMap(Map<String, dynamic> map) {
    final seasons = (map['seasons'] as List).map((r) => _SeasonInfo(
      id: r['id'],
      name: r['season_name'] ?? '',
    )).toList();

    final compsBySeason = <int, List<_CompetitionInfo>>{};
    if (map['compsBySeason'] is Map) {
      (map['compsBySeason'] as Map).forEach((key, value) {
        final seasonId = int.tryParse(key.toString()) ?? 0;
        compsBySeason[seasonId] = (value as List).map((c) => _CompetitionInfo(
          id: c['id'],
          title: c['title'] ?? '',
          status: c['status'] ?? '',
          date: c['date'] ?? '',
          location: c['location'] ?? '',
          imageUrl: c['image_url'],
          seasonId: c['season_id'],
        )).toList();
      });
    }
    return _TournamentsPageData(compsBySeason: compsBySeason, seasons: seasons);
  }
}

class _TopBar extends StatelessWidget {
  final bool isLoading;

  const _TopBar({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MANAGEMENT',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Tournaments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              color: Color(0xFFF59E0B),
            ),
          ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SmallIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  final Color color;

  const _CountPill({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(
        count.toString().padLeft(2, '0'),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'Monospace',
        ),
      ),
    );
  }
}

class _SeasonDropdown extends StatelessWidget {
  final List<_SeasonInfo> seasons;
  final int? selectedSeasonId;
  final ValueChanged<int?> onChanged;

  const _SeasonDropdown({
    required this.seasons,
    required this.selectedSeasonId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 14),
      child: TechnicalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              color: Color(0xFFFBBF24),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedSeasonId,
                  isExpanded: true,
                  dropdownColor: kSurface,
                  iconEnabledColor: const Color(0xFFFBBF24),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ALL SEASONS'),
                    ),
                    for (final season in seasons)
                      DropdownMenuItem<int?>(
                        value: season.id,
                        child: Text(
                          season.name.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonCard extends StatefulWidget {
  final _SeasonInfo season;
  final List<_CompetitionInfo> competitions;
  final void Function(_CompetitionInfo comp)? onEditComp;
  final VoidCallback? onAddComp;

  const _SeasonCard({
    required this.season,
    required this.competitions,
    this.onEditComp,
    this.onAddComp,
  });

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  bool _showEditActions = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 14),
      child: TechnicalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.layers_outlined,
                  color: Color(0xFFFBBF24),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.season.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                _CountPill(
                  count: widget.competitions.length,
                  color: const Color(0xFFFBBF24),
                ),
                if (widget.onEditComp != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: _showEditActions ? Icons.done_all_rounded : Icons.edit_outlined,
                    color: _showEditActions
                        ? const Color(0xFFD97706)
                        : Colors.white38,
                    onTap: () => setState(() => _showEditActions = !_showEditActions),
                  ),
                ],
                if (widget.onAddComp != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: Icons.add,
                    color: const Color(0xFFF59E0B),
                    onTap: widget.onAddComp!,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (widget.competitions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'NO TOURNAMENTS FOUND.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              for (final comp in widget.competitions) ...[
                _CompCard(
                  competition: comp,
                  showEditAction: _showEditActions,
                  onEdit: widget.onEditComp != null ? () => widget.onEditComp!(comp) : null,
                ),
                if (comp != widget.competitions.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CompCard extends StatelessWidget {
  final _CompetitionInfo competition;
  final bool showEditAction;
  final VoidCallback? onEdit;

  const _CompCard({required this.competition, this.showEditAction = false, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: competition.imageUrl != null
                    ? Image.network(
                        competition.imageUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _compIcon(),
                      )
                    : _compIcon(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      competition.title.isEmpty ? 'UNTITLED EVENT' : competition.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (competition.status.isNotEmpty)
                          _CompMetaChip(
                            icon: Icons.sensors_rounded,
                            label: competition.status,
                            iconColor: _statusColor(competition.status),
                          ),
                        if (competition.date.isNotEmpty)
                          _CompMetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: competition.date,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showEditAction && onEdit != null)
                _SmallIconButton(
                  icon: Icons.settings_input_component_outlined,
                  color: const Color(0xFFFBBF24),
                  onTap: onEdit!,
                ),
            ],
          ),
          if (competition.location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 10, color: Color(0xFFF87171)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    competition.location.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _MatchesButton(
              competitionId: competition.id,
              competitionTitle: competition.title,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing': return const Color(0xFF10B981);
      case 'upcoming': return const Color(0xFF6366F1);
      case 'finished':
      case 'completed': return Colors.white24;
      default: return Colors.white24;
    }
  }

  Widget _compIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.emoji_events_outlined,
        color: Color(0xFFFBBF24),
        size: 20,
      ),
    );
  }
}

class _CompMetaChip extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final String label;

  const _CompMetaChip({this.icon, this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: iconColor ?? Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kPadding),
      child: Center(
        child: TechnicalCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF87171),
                size: 32,
              ),
              const SizedBox(height: 12),
              const Text(
                'CONNECTION ERROR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              TechnicalButton(
                label: 'RETRY',
                onTap: onRetry,
                color: const Color(0xFFF87171),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;
  final List<_SeasonInfo> seasons;
  final int? presetSeasonId;

  const _CompFormSheet({required this.row, this.seasons = const [], this.presetSeasonId});

  @override
  State<_CompFormSheet> createState() => _CompFormSheetState();
}

class _CompFormSheetState extends State<_CompFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int? _seasonId;
  String _statusValue = '';
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  String? _initialTitle;
  String? _initialStatus;
  String? _initialDate;
  String? _initialLocation;
  String? _initialImageUrl;
  int? _initialSeasonId;

  bool get _hasChanges {
    if (widget.row == null) return true;
    return _titleController.text.trim() != _initialTitle
        || _statusValue != _initialStatus
        || _dateController.text.trim() != _initialDate
        || _locationController.text.trim() != _initialLocation
        || _imageController.text != _initialImageUrl
        || _seasonId != _initialSeasonId;
  }

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    final presetId = widget.presetSeasonId;
    _titleController.text = _stringValue(row?['title']);
    _statusValue = _stringValue(row?['status']);
    _dateController.text = _stringValue(row?['date']);
    _locationController.text = _stringValue(row?['location']);
    _imageController.text = _stringValue(row?['image_url']);
    _seasonId = _intValue(row?['season_id']) ?? presetId;
    _initialTitle = _stringValue(row?['title']);
    _initialStatus = _stringValue(row?['status']);
    _initialDate = _stringValue(row?['date']);
    _initialLocation = _stringValue(row?['location']);
    _initialImageUrl = _stringValue(row?['image_url']);
    _initialSeasonId = _intValue(row?['season_id']) ?? presetId;
    if (widget.row != null) {
      _titleController.addListener(_onFieldChanged);
      _dateController.addListener(_onFieldChanged);
      _locationController.addListener(_onFieldChanged);
      _imageController.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _dateController.removeListener(_onFieldChanged);
    _locationController.removeListener(_onFieldChanged);
    _imageController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seasonId == null) {
      _showError('Select a season.');
      return;
    }
    setState(() => _isSaving = true);
    final isEditing = widget.row != null;
    try {
      final payload = {
        'title': _titleController.text.trim(),
        'status': _nullableString(_statusValue),
        'date': _nullableString(_dateController.text),
        'location': _nullableString(_locationController.text),
        'image_url': _nullableString(_imageController.text),
        'season_id': _seasonId,
      };
      final id = _intValue(widget.row?['id']);
      if (id == null) {
        await _supabase.from('competitions').insert(payload);
      } else {
        await _supabase.from('competitions').update(payload).eq('id', id);
      }
      if (mounted) {
        await _showResultDialog(
          icon: Icons.check_circle_outline_rounded,
          iconColor: const Color(0xFFFBBF24),
          title: 'Success',
          message: isEditing ? 'Tournament updated.' : 'New tournament added.',
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        _showResultDialog(
          icon: Icons.error_outline_rounded,
          iconColor: const Color(0xFFF87171),
          title: 'Error',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final name = _titleController.text.trim();
      final url = await StorageService.uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'competitions',
        personName: name.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : name,
      );

      if (mounted) {
        final confirmed = await showPhotoConfirmDialog(
          context: context,
          url: url,
          name: name.isEmpty ? 'Tournament' : name,
          accentColor: const Color(0xFFFBBF24),
        );
        if (confirmed == true) {
          _imageController.text = url;
          if (widget.row != null) {
            final id = _intValue(widget.row!['id']);
            if (id != null) {
              await _supabase.from('competitions').update({'image_url': url}).eq('id', id);
            }
          }
        }
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.toUpperCase()), backgroundColor: const Color(0xFFB91C1C)),
    );
  }

  Future<void> _showResultDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.row != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Tournament' : 'Add Tournament',
      isSaving: _isSaving,
      canSave: _hasChanges,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _titleController,
              label: 'Title',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _StatusDropdown(
              value: _statusValue,
              onChanged: (v) {
                setState(() => _statusValue = v);
                _onFieldChanged();
              },
            ),
            const SizedBox(height: 12),
            _TextFieldInput(
              controller: _dateController,
              label: 'Date',
            ),
            const SizedBox(height: 12),
            _TextFieldInput(
              controller: _locationController,
              label: 'Location',
            ),
            const SizedBox(height: 12),
            _PhotoPickerInput(
              imageUrl: _nullableString(_imageController.text),
              isUploading: _isUploadingPicture,
              onPick: _pickImage,
            ),
            if (widget.seasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              _SeasonDropdownInput(
                label: 'Season',
                value: _seasonId,
                items: widget.seasons,
                onChanged: (value) => setState(() => _seasonId = value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isSaving;
  final VoidCallback onSave;
  final bool canSave;

  const _FormSheetScaffold({
    required this.title,
    required this.child,
    required this.isSaving,
    required this.onSave,
    this.canSave = true,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                      child: Text(
                        title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: child,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: TechnicalButton(
                  label: isSaving ? 'SAVING...' : 'SAVE',
                  onTap: (isSaving || !canSave) ? () {} : onSave,
                  isLoading: isSaving,
                  color: canSave ? const Color(0xFFFBBF24) : Colors.white24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextFieldInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _TextFieldInput({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(label),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _StatusDropdown({required this.value, required this.onChanged});

  static const _statuses = ['Upcoming', 'Ongoing', 'Finished', 'Completed'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: kBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text('STATUS', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w800)),
          dropdownColor: kSurface,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          items: [
            for (final s in _statuses)
              DropdownMenuItem(value: s, child: Text(s.toUpperCase())),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PhotoPickerInput extends StatelessWidget {
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onPick;

  const _PhotoPickerInput({
    required this.imageUrl,
    required this.isUploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return TechnicalCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
                  )
                : _fallbackIcon(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EVENT IMAGE',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'CHANGE IMAGE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SmallIconButton(
            icon: isUploading
                ? Icons.sync_rounded
                : Icons.add_a_photo_outlined,
            color: const Color(0xFFFBBF24),
            onTap: isUploading ? () {} : onPick,
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFFFBBF24),
        size: 20,
      ),
    );
  }
}

class _SeasonDropdownInput extends StatelessWidget {
  final String label;
  final int? value;
  final List<_SeasonInfo> items;
  final ValueChanged<int?> onChanged;

  const _SeasonDropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: kSurface,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: _inputDecoration(label),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('SELECT SEASON'),
        ),
        for (final season in items)
          DropdownMenuItem<int>(
            value: season.id,
            child: Text(season.name.toUpperCase()),
          ),
      ],
      onChanged: onChanged,
    );
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadius),
      borderSide: const BorderSide(color: Color(0xFFF87171)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadius),
      borderSide: const BorderSide(color: Color(0xFFF87171)),
    ),
  );
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'REQUIRED';
  return null;
}

String _stringValue(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final text = _stringValue(value);
  return text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

String _displaySeasonName(Map row) {
  final name = _stringValue(row['season_name']);
  return name.isEmpty ? 'Season ${_intValue(row['id']) ?? 0}' : name;
}
