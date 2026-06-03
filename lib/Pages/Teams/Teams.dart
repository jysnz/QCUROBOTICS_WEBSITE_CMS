import 'package:flutter/material.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Teams extends StatefulWidget {
  const Teams({super.key});

  @override
  State<Teams> createState() => _TeamsState();
}

class _TeamsState extends State<Teams> {
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  static const String _cacheKey = 'teams_page_data';
  static const Duration _cacheDuration = Duration(hours: 1);

  late Future<_TeamsPageData> _teamsFuture;
  int? _selectedSeasonId;

  @override
  void initState() {
    super.initState();
    _teamsFuture = _loadTeamsData();
  }

  Future<_TeamsPageData> _loadTeamsData() async {
    final cachedMap = await _cache.getData(_cacheKey);
    if (cachedMap != null) {
      try {
        final cachedData = _TeamsPageData.fromMap(cachedMap);
        _cache.getData(_cacheKey, maxAge: _cacheDuration).then((fresh) {
          if (fresh == null) {
            _fetchAndCacheTeams().then((freshData) {
              if (mounted) {
                setState(() {
                  _teamsFuture = Future.value(freshData);
                });
              }
            });
          }
        });
        return cachedData;
      } catch (e) {
        debugPrint('[_loadTeamsData] cache error: $e');
      }
    }
    return _fetchAndCacheTeams();
  }

  Future<_TeamsPageData> _fetchAndCacheTeams() async {
    debugPrint('[_fetchAndCacheTeams] fetching data...');
    final results = await Future.wait([
      _supabase.from('teams').select('''
        id,
        team_name,
        team_number,
        team_code,
        is_active,
        season_id,
        season:seasons(id, season_name)
      ''').order('team_number'),
      _supabase.from('seasons').select('id, season_name').order('id'),
    ]);

    final teamRows = _asMapList(results[0]);
    final seasonRows = _asMapList(results[1]);
    debugPrint('[_fetchAndCacheTeams] teams: ${teamRows.length}, seasons: ${seasonRows.length}');

    final seasons = seasonRows.map((r) => _SeasonInfo(
      id: _intValue(r['id']) ?? 0,
      name: _displaySeasonName(r),
    )).toList();

    debugPrint('[_fetchAndCacheTeams] teamRows count: ${teamRows.length}');
    for (final row in teamRows) {
      debugPrint('[_fetchAndCacheTeams] team row: id=${row['id']} name=${row['team_name']} season_id=${row['season_id']}');
    }

    final teamsBySeason = <int, List<_TeamInfo>>{};
    for (final row in teamRows) {
      final seasonId = _intValue(row['season_id']);
      final team = _TeamInfo(
        id: _intValue(row['id']) ?? 0,
        name: _stringValue(row['team_name']),
        number: _intValue(row['team_number']) ?? 0,
        code: _stringValue(row['team_code']),
        isActive: row['is_active'] == true,
        seasonId: seasonId,
      );
      final sid = seasonId ?? 0;
      teamsBySeason.putIfAbsent(sid, () => []).add(team);
    }

    debugPrint('[_fetchAndCacheTeams] teamsBySeason keys: ${teamsBySeason.keys}');
    for (final entry in teamsBySeason.entries) {
      debugPrint('[_fetchAndCacheTeams] season ${entry.key}: ${entry.value.length} teams');
    }

    _cachedSeasons = seasons;

    final data = _TeamsPageData(
      teamsBySeason: teamsBySeason,
      seasons: seasons,
    );

    await _cache.saveData(_cacheKey, data.toMap());
    return data;
  }

  Future<void> _refresh() async {
    final future = _fetchAndCacheTeams();
    setState(() {
      _teamsFuture = future;
    });
    await future;
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final future = _fetchAndCacheTeams();
    setState(() {
      _teamsFuture = future;
    });
    await future;
  }

  List<_SeasonInfo>? _cachedSeasons;

  Future<void> _openTeamForm({Map<String, dynamic>? row, List<_SeasonInfo>? seasons, int? presetSeasonId}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TeamFormSheet(
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
          const _TeamsBackground(),
          SafeArea(
            child: FutureBuilder<_TeamsPageData>(
              future: _teamsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: const Color(0xFF111827),
                  color: const Color(0xFF10B981),
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
                          child: TeamsSkeleton(),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Teams',
                            count: data.totalCount,
                            color: const Color(0xFF10B981),
                            onAdd: () => _openTeamForm(seasons: data.seasons),
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
                          if (data.teamsBySeason.containsKey(0)) ...[
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

  Widget _buildSeasonSection(_TeamsPageData data, _SeasonInfo season) {
    final teams = data.teamsBySeason[season.id] ?? [];
    return SliverToBoxAdapter(
      child: _SeasonCard(
        season: season,
        teams: teams,
        onEditTeam: (team) => _openTeamForm(row: team.toMap(), seasons: data.seasons),
        onAddTeam: () => _openTeamForm(seasons: data.seasons, presetSeasonId: season.id == 0 ? null : season.id),
      ),
    );
  }
}

class _SeasonInfo {
  final int id;
  final String name;
  const _SeasonInfo({required this.id, required this.name});
}

class _TeamInfo {
  final int id;
  final String name;
  final int number;
  final String code;
  final bool isActive;
  final int? seasonId;

  const _TeamInfo({
    required this.id,
    required this.name,
    required this.number,
    required this.code,
    required this.isActive,
    this.seasonId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'team_name': name,
      'team_number': number,
      'team_code': code,
      'is_active': isActive,
      'season_id': seasonId,
    };
  }
}

class _TeamsPageData {
  final Map<int, List<_TeamInfo>> teamsBySeason;
  final List<_SeasonInfo> seasons;

  const _TeamsPageData({
    required this.teamsBySeason,
    required this.seasons,
  });

  int get totalCount {
    var count = 0;
    for (final list in teamsBySeason.values) {
      count += list.length;
    }
    return count;
  }

  Map<String, dynamic> toMap() {
    return {
      'teamsBySeason': teamsBySeason.map(
        (k, v) => MapEntry(k.toString(), v.map((t) => t.toMap()).toList()),
      ),
      'seasons': seasons
          .map((s) => {'id': s.id, 'season_name': s.name})
          .toList(),
    };
  }

  factory _TeamsPageData.fromMap(Map<String, dynamic> map) {
    final seasons = (map['seasons'] as List).map((r) => _SeasonInfo(
      id: r['id'],
      name: r['season_name'] ?? '',
    )).toList();

    final teamsBySeason = <int, List<_TeamInfo>>{};
    if (map['teamsBySeason'] is Map) {
      (map['teamsBySeason'] as Map).forEach((key, value) {
        final seasonId = int.tryParse(key.toString()) ?? 0;
        teamsBySeason[seasonId] = (value as List).map((t) => _TeamInfo(
          id: t['id'],
          name: t['team_name'] ?? '',
          number: t['team_number'] ?? 0,
          code: t['team_code'] ?? '',
          isActive: t['is_active'] == true,
          seasonId: t['season_id'],
        )).toList();
      });
    }
    return _TeamsPageData(teamsBySeason: teamsBySeason, seasons: seasons);
  }
}

class _TeamsBackground extends StatelessWidget {
  const _TeamsBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.1,
          colors: [Color(0x2410B981), Color(0x1014B8A6), Color(0x000B1020)],
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
                'Teams',
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
              color: Color(0xFF34D399),
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
              color: Color(0xFF34D399),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedSeasonId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF111827),
                  iconEnabledColor: const Color(0xFF34D399),
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

class _SeasonCard extends StatefulWidget {
  final _SeasonInfo season;
  final List<_TeamInfo> teams;
  final void Function(_TeamInfo team)? onEditTeam;
  final VoidCallback? onAddTeam;

  const _SeasonCard({
    required this.season,
    required this.teams,
    this.onEditTeam,
    this.onAddTeam,
  });

  @override
  State<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends State<_SeasonCard> {
  bool _showEditActions = false;

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
                  color: Color(0xFF34D399),
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.season.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _CountPill(
                  count: widget.teams.length,
                  color: const Color(0xFF34D399),
                ),
                if (widget.onEditTeam != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: _showEditActions ? Icons.check_rounded : Icons.edit_rounded,
                    color: _showEditActions
                        ? const Color(0xFF059669)
                        : const Color(0xFF34D399),
                    onTap: () => setState(() => _showEditActions = !_showEditActions),
                  ),
                ],
                if (widget.onAddTeam != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: Icons.add_rounded,
                    color: const Color(0xFF10B981),
                    onTap: widget.onAddTeam!,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (widget.teams.isEmpty)
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
                      'No teams in this season yet.',
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
              for (final team in widget.teams) ...[
                _TeamCard(
                  team: team,
                  showEditAction: _showEditActions,
                  onEdit: widget.onEditTeam != null ? () => widget.onEditTeam!(team) : null,
                ),
                if (team != widget.teams.last) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final _TeamInfo team;
  final bool showEditAction;
  final VoidCallback? onEdit;

  const _TeamCard({required this.team, this.showEditAction = false, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (team.number > 0) 'Team ${team.number}',
      if (team.code.isNotEmpty) team.code,
    ].join(' | ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: Color(0xFF34D399),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name.isEmpty ? 'Unnamed Team' : team.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.48),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (team.isActive)
            const _StatusPill(label: 'Active', color: Color(0xFF10B981)),
          if (showEditAction && onEdit != null) ...[
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.edit_rounded,
              color: const Color(0xFF34D399),
              onTap: onEdit!,
            ),
          ],
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

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: _GlassCard(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.56),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                'Unable to load teams',
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

class _TeamFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;
  final List<_SeasonInfo> seasons;
  final int? presetSeasonId;

  const _TeamFormSheet({required this.row, this.seasons = const [], this.presetSeasonId});

  @override
  State<_TeamFormSheet> createState() => _TeamFormSheetState();
}

class _TeamFormSheetState extends State<_TeamFormSheet> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int? _seasonId;
  late bool _isActive;
  bool _isSaving = false;

  String? _initialName;
  String? _initialNumber;
  String? _initialCode;
  int? _initialSeasonId;
  bool _initialIsActive = true;

  bool get _hasChanges {
    if (widget.row == null) return true;
    return _nameController.text.trim() != _initialName
        || _numberController.text.trim() != _initialNumber
        || _codeController.text.trim() != _initialCode
        || _seasonId != _initialSeasonId
        || _isActive != _initialIsActive;
  }

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    final presetId = widget.presetSeasonId;
    _nameController.text = _stringValue(row?['team_name']);
    _numberController.text = row?['team_number']?.toString() ?? '';
    _codeController.text = _stringValue(row?['team_code']);
    _seasonId = _intValue(row?['season_id']) ?? presetId;
    _isActive = row?['is_active'] == true || row == null;
    _initialName = _stringValue(row?['team_name']);
    _initialNumber = row?['team_number']?.toString() ?? '';
    _initialCode = _stringValue(row?['team_code']);
    _initialSeasonId = _intValue(row?['season_id']) ?? presetId;
    _initialIsActive = row?['is_active'] == true || row == null;
    if (widget.row != null) {
      _nameController.addListener(_onFieldChanged);
      _numberController.addListener(_onFieldChanged);
      _codeController.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _numberController.removeListener(_onFieldChanged);
    _codeController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _numberController.dispose();
    _codeController.dispose();
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
        'team_name': _nameController.text.trim(),
        'team_number': int.tryParse(_numberController.text.trim()) ?? 0,
        'team_code': _nullableString(_codeController.text),
        'is_active': _isActive,
        'season_id': _seasonId,
      };
      final id = _intValue(widget.row?['id']);
      if (id == null) {
        await _supabase.from('teams').insert(payload);
      } else {
        await _supabase.from('teams').update(payload).eq('id', id);
      }
      if (mounted) {
        await _showResultDialog(
          icon: Icons.check_circle,
          iconColor: const Color(0xFF34D399),
          title: 'Success',
          message: isEditing ? 'Team updated successfully.' : 'Team added successfully.',
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
      title: isEditing ? 'Edit Team' : 'Add Team',
      isSaving: _isSaving,
      canSave: _hasChanges,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Team Name',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _TextFieldInput(
              controller: _numberController,
              label: 'Team Number',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _TextFieldInput(
              controller: _codeController,
              label: 'Team Code',
              validator: _requiredValidator,
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
            const SizedBox(height: 10),
            _SwitchInput(
              label: 'Active',
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
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
                            : const Color(0xFF10B981).withValues(alpha: 0.3),
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

class _SwitchInput extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      activeThumbColor: const Color(0xFF34D399),
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
      borderSide: const BorderSide(color: Color(0xFF34D399)),
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
