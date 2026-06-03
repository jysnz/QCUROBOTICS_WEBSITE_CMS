import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
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
    debugPrint('[_fetchAndCacheTournaments] fetching data...');
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
    debugPrint('[_fetchAndCacheTournaments] competitions: ${compRows.length}, seasons: ${seasonRows.length}');

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
    final future = _fetchAndCacheTournaments();
    setState(() {
      _tournamentsFuture = future;
    });
    await future;
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final future = _fetchAndCacheTournaments();
    setState(() {
      _tournamentsFuture = future;
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
      backgroundColor: const Color(0xFF0B1020),
      body: Stack(
        children: [
          const _TournamentsBackground(),
          SafeArea(
            child: FutureBuilder<_TournamentsPageData>(
              future: _tournamentsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: const Color(0xFF111827),
                  color: const Color(0xFFF59E0B),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
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
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Tournaments',
                            count: data.totalCount,
                            color: const Color(0xFFF59E0B),
                            onAdd: () => _openCompForm(seasons: data.seasons),
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
                        const SliverToBoxAdapter(child: SizedBox(height: 36)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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

class _TournamentsBackground extends StatelessWidget {
  const _TournamentsBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.1,
          colors: [Color(0x24F59E0B), Color(0x1014B8A6), Color(0x000B1020)],
          stops: [0, 0.46, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
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
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Management',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Tournaments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF111827).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final double topPadding;
  final VoidCallback? onAdd;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    this.topPadding = 18,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ),
          _CountPill(count: count, color: color),
          if (onAdd != null) ...[
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.add_rounded,
              color: color,
              onTap: onAdd!,
            ),
          ],
        ],
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
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Icon(icon, color: color, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: _GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFFFBBF24),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedSeasonId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF111827),
                  iconEnabledColor: const Color(0xFFFBBF24),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Seasons'),
                    ),
                    for (final season in seasons)
                      DropdownMenuItem<int?>(
                        value: season.id,
                        child: Text(
                          season.name,
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

class _SeasonCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFFFBBF24),
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    season.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _CountPill(
                  count: competitions.length,
                  color: const Color(0xFFFBBF24),
                ),
                if (onAddComp != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: Icons.add_rounded,
                    color: const Color(0xFFF59E0B),
                    onTap: onAddComp!,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (competitions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No tournaments in this season yet.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              for (final comp in competitions) ...[
                _CompCard(
                  competition: comp,
                  onEdit: onEditComp != null ? () => onEditComp!(comp) : null,
                ),
                if (comp != competitions.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CompCard extends StatelessWidget {
  final _CompetitionInfo competition;
  final VoidCallback? onEdit;

  const _CompCard({required this.competition, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: competition.imageUrl != null
                    ? Image.network(
                        competition.imageUrl!,
                        width: 48,
                        height: 48,
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
                      competition.title.isEmpty ? 'Untitled Tournament' : competition.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (competition.status.isNotEmpty)
                          _CompMetaChip(
                            icon: Icons.circle_rounded,
                            label: competition.status,
                          ),
                        if (competition.date.isNotEmpty)
                          _CompMetaChip(
                            icon: Icons.calendar_today_rounded,
                            label: competition.date,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                _SmallIconButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFFFBBF24),
                  onTap: onEdit!,
                ),
            ],
          ),
          if (competition.location.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.circle, size: 6, color: const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    competition.location,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _compIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.emoji_events_rounded,
        color: Color(0xFFFBBF24),
        size: 24,
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: iconColor ?? Colors.white.withValues(alpha: 0.45)),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
      padding: const EdgeInsets.all(20),
      child: Center(
        child: _GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFF87171),
                size: 34,
              ),
              const SizedBox(height: 10),
              const Text(
                'Unable to load tournaments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
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
      _showError('Please select a season.');
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
          icon: Icons.check_circle,
          iconColor: const Color(0xFF34D399),
          title: 'Success',
          message: isEditing ? 'Tournament updated successfully.' : 'Tournament added successfully.',
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
      final bytes = await image.readAsBytes();
      final ext = image.name.contains('.')
          ? image.name.substring(image.name.lastIndexOf('.'))
          : '.jpg';
      final name = _titleController.text.trim();
      final safeName = name.isEmpty
          ? 'comp_${DateTime.now().millisecondsSinceEpoch}'
          : name.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'competitions/$safeName$ext';

      await _supabase.storage.from('member-pictures').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          contentType: ext == '.png' ? 'image/png' : 'image/jpeg',
          upsert: true,
        ),
      );

      final url = '${_supabase.storage.from('member-pictures').getPublicUrl(fileName)}?t=${DateTime.now().millisecondsSinceEpoch}';

      if (mounted) {
        final confirmed = await _showPhotoConfirmDialog(
          context: context,
          url: url,
          name: name.isEmpty ? 'Tournament' : name,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString()), backgroundColor: const Color(0xFFB91C1C)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFF59E0B), size: 26),
            SizedBox(width: 10),
            Text('Validation', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF818CF8))),
          ),
        ],
      ),
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
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done', style: TextStyle(color: Color(0xFF818CF8))),
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
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0B1020),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: (isSaving || !canSave) ? null : onSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: canSave
                            ? null
                            : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                child,
              ],
            ),
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
      style: const TextStyle(color: Colors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          isExpanded: true,
          hint: Text('Status', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
          dropdownColor: const Color(0xFF1F2937),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: [
            for (final s in _statuses)
              DropdownMenuItem(value: s, child: Text(s)),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
                  )
                : _fallbackIcon(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tournament image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Choose from gallery',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: isUploading ? () {} : onPick,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.28)),
              ),
              child: Icon(
                isUploading ? Icons.hourglass_top_rounded : Icons.photo_library_rounded,
                color: const Color(0xFFFBBF24),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.image_rounded,
        color: Color(0xFFFBBF24),
        size: 26,
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
      value: value,
      isExpanded: true,
      dropdownColor: const Color(0xFF111827),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('Select a season'),
        ),
        for (final season in items)
          DropdownMenuItem<int>(
            value: season.id,
            child: Text(season.name),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.055),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFFBBF24)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFF87171)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFF87171)),
    ),
  );
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Required';
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

Future<bool?> _showPhotoConfirmDialog({
  required BuildContext context,
  required String url,
  required String name,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
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
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.25),
                  blurRadius: 20,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                url,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF1F2937),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: Color(0xFFFBBF24),
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name.isEmpty ? 'Image Uploaded' : name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name.isEmpty
                ? 'Photo uploaded successfully.'
                : 'Image ready.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Use Photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
