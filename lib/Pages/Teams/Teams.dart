import 'package:flutter/material.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';
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
  Key _futureKey = UniqueKey();
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
                  _futureKey = UniqueKey();
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

    final seasons = seasonRows.map((r) => _SeasonInfo(
      id: _intValue(r['id']) ?? 0,
      name: _displaySeasonName(r),
    )).toList();

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

    _cachedSeasons = seasons;

    final data = _TeamsPageData(
      teamsBySeason: teamsBySeason,
      seasons: seasons,
    );

    await _cache.saveData(_cacheKey, data.toMap());
    return data;
  }

  Future<void> _refresh() async {
    await _cache.clearData(_cacheKey);
    final future = _fetchAndCacheTeams();
    setState(() {
      _teamsFuture = future;
      _futureKey = UniqueKey();
    });
    await future;
  }

  Future<void> _reload() async {
    if (!mounted) return;
    await _cache.clearData(_cacheKey);
    final future = _fetchAndCacheTeams();
    setState(() {
      _teamsFuture = future;
      _futureKey = UniqueKey();
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
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const TechnicalGridBackground(),
          SafeArea(
            child: FutureBuilder<_TeamsPageData>(
              key: _futureKey,
              future: _teamsFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: kSurface,
                  color: kAccent,
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
                          child: TeamsSkeleton(),
                        )
                      else ...[
                        const SliverToBoxAdapter(
                          child: TechnicalSectionHeader(
                            label: 'Teams',
                            color: kAccent,
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
        backgroundColor: kAccent,
        foregroundColor: kBackground,
        onPressed: () => _openTeamForm(seasons: _cachedSeasons),
        child: const Icon(Icons.add),
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
                'ADMIN',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Teams',
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
              color: kAccent,
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
              color: kAccent,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedSeasonId,
                  isExpanded: true,
                  dropdownColor: kSurface,
                  iconEnabledColor: kAccent,
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
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 14),
      child: TechnicalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.layers_outlined,
                  color: kAccent,
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
                  count: widget.teams.length,
                  color: kAccent,
                ),
                if (widget.onEditTeam != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: _showEditActions ? Icons.done_all_rounded : Icons.edit_outlined,
                    color: _showEditActions
                        ? kAccent
                        : Colors.white38,
                    onTap: () => setState(() => _showEditActions = !_showEditActions),
                  ),
                ],
                if (widget.onAddTeam != null) ...[
                  const SizedBox(width: 8),
                  _SmallIconButton(
                    icon: Icons.add,
                    color: kAccent,
                    onTap: widget.onAddTeam!,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (widget.teams.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'NO TEAMS FOUND IN THIS SEASON.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
      if (team.number > 0) 'Unit ${team.number}',
      if (team.code.isNotEmpty) team.code,
    ].join(' | ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: kAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name.isEmpty ? 'UNNAMED TEAM' : team.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (team.isActive)
            const _StatusPill(label: 'ACTIVE', color: kAccent),
          if (showEditAction && onEdit != null) ...[
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.edit_note_outlined,
              color: const Color(0xFF6366F1),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
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
      _showError('Select a season.');
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
          icon: Icons.check_circle_outline_rounded,
          iconColor: kAccent,
          title: 'Success',
          message: isEditing ? 'Team updated.' : 'New team added.',
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFB91C1C)),
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
            child: const Text('OK', style: TextStyle(color: kAccent, fontWeight: FontWeight.w800, fontSize: 13)),
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
              label: 'Active Status',
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
                  color: canSave ? kAccent : Colors.white24,
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
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      activeThumbColor: kAccent,
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
      borderSide: const BorderSide(color: kAccent, width: 1.0),
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
