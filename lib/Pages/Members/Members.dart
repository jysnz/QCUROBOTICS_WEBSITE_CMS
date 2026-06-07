import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
import 'package:qcurobotics_management_app/Services/storage_service.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'member_form.dart';

class Members extends StatefulWidget {
  const Members({super.key});

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();
  static const String _membersCacheKey = 'members_page_data';
  static const Duration _membersCacheDuration = Duration(hours: 1);

  late Future<_MembersPageData> _membersFuture;
  Key _futureKey = UniqueKey();
  int? _selectedSeasonId;
  bool _isEditingSelectedSeason = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembersData();
  }

  Future<_MembersPageData> _loadMembersData() async {
    final cachedMap = await _cache.getData(_membersCacheKey);
    if (cachedMap != null) {
      try {
        final cachedData = _MembersPageData.fromMap(cachedMap);
        _cache.getData(_membersCacheKey, maxAge: _membersCacheDuration).then((fresh) {
          if (fresh == null) {
            _fetchAndCacheMembers().then((freshData) {
              if (mounted) {
                setState(() {
                  _membersFuture = Future.value(freshData);
                  _futureKey = UniqueKey();
                });
              }
            });
          }
        });
        return cachedData;
      } catch (e) {
        debugPrint('[_loadMembersData] cache error: $e');
      }
    }
    return _fetchAndCacheMembers();
  }

  Future<_MembersPageData> _fetchAndCacheMembers() async {
    final results = await Future.wait([
      _supabase.from('member_team_seasons').select('''
            id,
            member:team_members(
              id,
              name,
              profile_image_url,
              is_graduated,
              is_active
            ),
            team:teams(
              id,
              team_name,
              team_number,
              team_code,
              is_active,
              season_id
            ),
            season:seasons(
              id,
              season_name
            )
          '''),
      _supabase.from('member_roles').select('member_id, season_id, role:roles(role_name)'),
      _supabase.from('members').select(),
      _supabase.from('media_team').select('id, name, position, image_url, is_active'),
      _supabase.from('Coaches').select('id, name, image_url, is_active'),
      _supabase.from('teams').select('id, team_name, team_number, team_code, is_active, season_id').order('team_number'),
      _supabase.from('seasons').select('id, season_name').order('id'),
      _supabase.from('roles').select('id, role_name').order('role_name'),
    ]);

    final assignments = _asMapList(results[0]);
    final roleRows = _asMapList(results[1]);
    final members = _asMapList(results[2]);
    final mediaTeam = _asMapList(results[3])..sort((a, b) => _stringValue(a['name']).compareTo(_stringValue(b['name'])));
    final coaches = _asMapList(results[4])..sort((a, b) => _stringValue(a['name']).compareTo(_stringValue(b['name'])));
    final teams = _asMapList(results[5]).map(_TeamOption.fromRow).where((t) => t.id != null).toList();
    final seasons = _asMapList(results[6]).map(_SeasonOption.fromRow).where((s) => s.id != null).toList();
    final roles = _asMapList(results[7]).map(_RoleOption.fromRow).where((r) => r.id != null).toList();

    final rolesByMemberSeason = <String, List<String>>{};
    for (final row in roleRows) {
      final memberId = _intValue(row['member_id']);
      final seasonId = _intValue(row['season_id']);
      final role = row['role'];
      if (memberId == null || seasonId == null || role is! Map) continue;
      final roleName = _stringValue(role['role_name']);
      if (roleName.isEmpty) continue;
      final key = '$memberId:$seasonId';
      rolesByMemberSeason.putIfAbsent(key, () => <String>[]).add(roleName);
    }

    final seasonsById = <int, _SeasonGroup>{};
    for (final row in assignments) {
      final memberMap = row['member'];
      final teamMap = row['team'];
      final seasonMap = row['season'];
      if (memberMap is! Map || teamMap is! Map || seasonMap is! Map) continue;

      final memberId = _intValue(memberMap['id']);
      final teamId = _intValue(teamMap['id']);
      final seasonId = _intValue(seasonMap['id']);
      if (memberId == null || teamId == null || seasonId == null) continue;

      final season = seasonsById.putIfAbsent(seasonId, () => _SeasonGroup(id: seasonId, name: _displaySeasonName(seasonMap, seasonId), teamsById: <int, _TeamGroup>{}));
      final team = season.teamsById.putIfAbsent(teamId, () => _TeamGroup(id: teamId, name: _displayTeamName(teamMap), number: _intValue(teamMap['team_number']) ?? 0, code: _stringValue(teamMap['team_code']), players: <_TeamPlayer>[]));
      team.players.add(_TeamPlayer(id: memberId, assignmentId: _intValue(row['id']), teamId: teamId, seasonId: seasonId, name: _stringValue(memberMap['name']), imageUrl: _nullableString(memberMap['profile_image_url']), isActive: memberMap['is_active'] == true, isGraduated: memberMap['is_graduated'] == true, roles: rolesByMemberSeason['$memberId:$seasonId'] ?? const <String>[]));
    }

    final seasonGroups = seasonsById.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    for (final s in seasonGroups) {
      for (final t in s.teamsById.values) {
        t.players.sort((a, b) => a.name.compareTo(b.name));
      }
    }

    final data = _MembersPageData(seasons: seasonGroups, members: members, mediaTeam: mediaTeam, coaches: coaches, teams: teams, seasonOptions: seasons, roles: roles);
    await _cache.saveData(_membersCacheKey, data.toMap());
    return data;
  }

  Future<void> _refresh() async {
    await _cache.clearData(_membersCacheKey);
    final future = _fetchAndCacheMembers();
    setState(() {
      _membersFuture = future;
      _futureKey = UniqueKey();
    });
    await future;
  }

  Future<void> _reload() async {
    if (!mounted) return;
    await _cache.clearData(_membersCacheKey);
    final future = _fetchAndCacheMembers();
    setState(() {
      _membersFuture = future;
      _futureKey = UniqueKey();
    });
    await future;
  }

  Future<void> _openTeamPlayerForm({required _MembersPageData data, _TeamPlayer? player, int? presetTeamId, int? presetSeasonId}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (context) => _TeamPlayerFormSheet(
        player: player, 
        teams: data.teams, 
        seasons: data.seasonOptions, 
        roles: data.roles,
        presetTeamId: presetTeamId,
        presetSeasonId: presetSeasonId,
      )
    );
    if (saved == true) await _reload();
  }

  Future<void> _openGenericMemberForm({Map<String, dynamic>? row}) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _GenericMemberFormSheet(row: row));
    if (saved == true) await _reload();
  }

  Future<void> _openMediaMemberForm({Map<String, dynamic>? row}) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _MediaMemberFormSheet(row: row));
    if (saved == true) await _reload();
  }

  Future<void> _openCoachForm({Map<String, dynamic>? row}) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _CoachFormSheet(row: row));
    if (saved == true) await _reload();
  }

  Future<void> _confirmDeleteMember({
    required String table,
    required int id,
    required String name,
    String? title,
  }) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        title: Text(title ?? 'Delete Member', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this member? This action cannot be undone and all associated data will be removed.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            Text('Type "$name" to confirm:', style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kAccent)),
                hintText: 'Enter name',
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
              final canDelete = controller.text.trim() == name;
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
      try {
        await _supabase.from(table).delete().eq('id', id);
        await _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            child: FutureBuilder<_MembersPageData>(
              key: _futureKey,
              future: _membersFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final selectedSeason = data == null ? null : _selectedSeason(data);
                return RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: kSurface,
                  color: kAccent,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(kPadding), child: _MembersTopBar(isLoading: snapshot.connectionState == ConnectionState.waiting))),
                      if (snapshot.hasError) SliverFillRemaining(hasScrollBody: false, child: _ErrorState(message: snapshot.error.toString(), onRetry: _refresh))
                      else if (data == null) const SliverFillRemaining(hasScrollBody: false, child: MembersSkeleton())
                      else ...[
                        const SliverToBoxAdapter(child: TechnicalSectionHeader(label: 'Team Members', color: Color(0xFF6366F1), topPadding: 0)),
                        if (data.seasons.isEmpty) const SliverToBoxAdapter(child: _EmptyState(text: 'No members found.'))
                        else ...[
                          SliverToBoxAdapter(child: _SeasonSelector(seasons: data.seasons, selectedSeasonId: selectedSeason?.id, onChanged: (id) { if (id == null) return; setState(() { _selectedSeasonId = id; _isEditingSelectedSeason = false; }); })),
                          if (selectedSeason == null) const SliverToBoxAdapter(child: _EmptyState(text: 'Select a season.'))
                          else SliverToBoxAdapter(child: _SeasonPanel(season: selectedSeason, isEditing: _isEditingSelectedSeason, onToggleEditing: () => setState(() => _isEditingSelectedSeason = !_isEditingSelectedSeason), onEditPlayer: (player) => _openTeamPlayerForm(data: data, player: player), onAddPlayer: (teamId) => _openTeamPlayerForm(data: data, presetTeamId: teamId, presetSeasonId: selectedSeason.id))),
                        ],
                        const SliverToBoxAdapter(child: TechnicalSectionHeader(label: 'Members', color: Color(0xFF10B981), topPadding: 24)),
                        if (data.members.isEmpty) const SliverToBoxAdapter(child: _EmptyState(text: 'No personnel found.'))
                        else SliverList.builder(itemCount: data.members.length, itemBuilder: (context, index) => _GenericMemberCard(row: data.members[index], onEdit: () => _openGenericMemberForm(row: data.members[index]))),
                        const SliverToBoxAdapter(child: TechnicalSectionHeader(label: 'Media Team', color: Color(0xFFEC4899), topPadding: 24)),
                        if (data.mediaTeam.isEmpty) const SliverToBoxAdapter(child: _EmptyState(text: 'No media team found.'))
                        else SliverList.builder(itemCount: data.mediaTeam.length, itemBuilder: (context, index) => _MediaMemberCard(row: data.mediaTeam[index], onEdit: () => _openMediaMemberForm(row: data.mediaTeam[index]))),
                        const SliverToBoxAdapter(child: TechnicalSectionHeader(label: 'Coaches', color: Color(0xFFF59E0B), topPadding: 24)),
                        if (data.coaches.isEmpty) const SliverToBoxAdapter(child: _EmptyState(text: 'No coaches found.'))
                        else SliverList.builder(itemCount: data.coaches.length, itemBuilder: (context, index) => _CoachCard(row: data.coaches[index], onEdit: () => _openCoachForm(row: data.coaches[index]))),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
        onPressed: () async {
          final data = await _membersFuture;
          if (!mounted) return;
          _showAddMemberMenu(data);
        }, 
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddMemberMenu(_MembersPageData data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddMemberMenu(
        onAddTeamPlayer: () {
          Navigator.pop(context);
          _openTeamPlayerForm(data: data);
        },
        onAddGeneric: () {
          Navigator.pop(context);
          _openGenericMemberForm();
        },
        onAddMedia: () {
          Navigator.pop(context);
          _openMediaMemberForm();
        },
        onAddCoach: () {
          Navigator.pop(context);
          _openCoachForm();
        },
      ),
    );
  }

  _SeasonGroup? _selectedSeason(_MembersPageData data) {
    if (data.seasons.isEmpty) return null;
    final selectedId = _selectedSeasonId;
    if (selectedId != null) {
      for (final s in data.seasons) {
        if (s.id == selectedId) return s;
      }
    }
    return data.seasons.first;
  }
}

class _MembersPageData {
  final List<_SeasonGroup> seasons;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> mediaTeam;
  final List<Map<String, dynamic>> coaches;
  final List<_TeamOption> teams;
  final List<_SeasonOption> seasonOptions;
  final List<_RoleOption> roles;

  const _MembersPageData({
    required this.seasons,
    required this.members,
    required this.mediaTeam,
    required this.coaches,
    required this.teams,
    required this.seasonOptions,
    required this.roles,
  });

  Map<String, dynamic> toMap() {
    return {
      'seasons': seasons.map((s) => s.toMap()).toList(),
      'members': members,
      'mediaTeam': mediaTeam,
      'coaches': coaches,
      'teams': teams.map((t) => t.toMap()).toList(),
      'seasonOptions': seasonOptions.map((s) => s.toMap()).toList(),
      'roles': roles.map((r) => r.toMap()).toList()
    };
  }

  factory _MembersPageData.fromMap(Map<String, dynamic> map) {
    return _MembersPageData(
      seasons: (map['seasons'] as List).map((s) => _SeasonGroup.fromMap(s)).toList(),
      members: List<Map<String, dynamic>>.from(map['members']),
      mediaTeam: List<Map<String, dynamic>>.from(map['mediaTeam']),
      coaches: List<Map<String, dynamic>>.from(map['coaches'] ?? []),
      teams: (map['teams'] as List).map((t) => _TeamOption.fromMap(t)).toList(),
      seasonOptions: (map['seasonOptions'] as List).map((s) => _SeasonOption.fromMap(s)).toList(),
      roles: (map['roles'] as List).map((r) => _RoleOption.fromMap(r)).toList(),
    );
  }

  int get playerCount {
    var total = 0;
    for (final s in seasons) {
      for (final t in s.teamsById.values) {
        total += t.players.length;
      }
    }
    return total;
  }
}

class _SeasonGroup {
  final int id;
  final String name;
  final Map<int, _TeamGroup> teamsById;
  const _SeasonGroup({required this.id, required this.name, required this.teamsById});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'teamsById': teamsById.map((k, v) => MapEntry(k.toString(), v.toMap())),
  };

  factory _SeasonGroup.fromMap(Map<String, dynamic> map) => _SeasonGroup(
    id: map['id'],
    name: map['name'],
    teamsById: (map['teamsById'] as Map).map((k, v) => MapEntry(int.parse(k), _TeamGroup.fromMap(v))),
  );

  List<_TeamGroup> get teams {
    final list = teamsById.values.toList()..sort((a, b) {
      final n = a.number.compareTo(b.number);
      if (n != 0) return n;
      return a.name.compareTo(b.name);
    });
    return list;
  }
}

class _TeamGroup {
  final int id;
  final String name;
  final int number;
  final String code;
  final List<_TeamPlayer> players;
  const _TeamGroup({required this.id, required this.name, required this.number, required this.code, required this.players});

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'number': number,
    'code': code,
    'players': players.map((p) => p.toMap()).toList(),
  };

  factory _TeamGroup.fromMap(Map<String, dynamic> map) => _TeamGroup(
    id: map['id'],
    name: map['name'],
    number: map['number'],
    code: map['code'],
    players: (map['players'] as List).map((p) => _TeamPlayer.fromMap(p)).toList(),
  );
}

class _TeamPlayer {
  final int id;
  final int? assignmentId;
  final int teamId;
  final int seasonId;
  final String name;
  final String? imageUrl;
  final bool isActive;
  final bool isGraduated;
  final List<String> roles;
  const _TeamPlayer({
    required this.id,
    this.assignmentId,
    required this.teamId,
    required this.seasonId,
    required this.name,
    this.imageUrl,
    required this.isActive,
    required this.isGraduated,
    required this.roles,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'assignmentId': assignmentId,
    'teamId': teamId,
    'seasonId': seasonId,
    'name': name,
    'imageUrl': imageUrl,
    'isActive': isActive,
    'isGraduated': isGraduated,
    'roles': roles,
  };

  factory _TeamPlayer.fromMap(Map<String, dynamic> map) => _TeamPlayer(
    id: map['id'],
    assignmentId: map['assignmentId'],
    teamId: map['teamId'],
    seasonId: map['seasonId'],
    name: map['name'],
    imageUrl: map['imageUrl'],
    isActive: map['isActive'],
    isGraduated: map['isGraduated'],
    roles: List<String>.from(map['roles']),
  );
}

class _TeamOption {
  final int? id;
  final String name;
  final int? seasonId;
  const _TeamOption({this.id, required this.name, this.seasonId});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'seasonId': seasonId};
  factory _TeamOption.fromMap(Map<String, dynamic> map) => _TeamOption(id: map['id'], name: map['name'], seasonId: map['seasonId']);
  factory _TeamOption.fromRow(Map<String, dynamic> row) {
    final id = _intValue(row['id']);
    final n = _intValue(row['team_number']);
    final c = _stringValue(row['team_code']);
    final name = _displayTeamName(row);
    final meta = [if (n != null) 'Team $n', if (c.isNotEmpty) c].join(' | ');
    return _TeamOption(id: id, name: meta.isEmpty ? name : '$name ($meta)', seasonId: _intValue(row['season_id']));
  }
}

class _SeasonOption {
  final int? id;
  final String name;
  const _SeasonOption({this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory _SeasonOption.fromMap(Map<String, dynamic> map) => _SeasonOption(id: map['id'], name: map['name']);
  factory _SeasonOption.fromRow(Map<String, dynamic> row) {
    final id = _intValue(row['id']);
    return _SeasonOption(id: id, name: _displaySeasonName(row, id ?? 0));
  }
}

class _RoleOption {
  final int? id;
  final String name;
  const _RoleOption({this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory _RoleOption.fromMap(Map<String, dynamic> map) => _RoleOption(id: map['id'], name: map['name']);
  factory _RoleOption.fromRow(Map<String, dynamic> row) => _RoleOption(id: _intValue(row['id']), name: _stringValue(row['role_name']));
}

class _MembersTopBar extends StatelessWidget {
  final bool isLoading;
  const _MembersTopBar({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop()),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADMIN', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
              Text('Members', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ],
          ),
        ),
        if (isLoading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.0, color: kAccent))
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
  const _SmallIconButton({required this.icon, required this.color, required this.onTap});

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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'Monospace'),
      ),
    );
  }
}

class _SeasonSelector extends StatelessWidget {
  final List<_SeasonGroup> seasons;
  final int? selectedSeasonId;
  final ValueChanged<int?> onChanged;
  const _SeasonSelector({required this.seasons, this.selectedSeasonId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 14),
      child: TechnicalCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.calendar_view_day_outlined, color: Color(0xFF6366F1), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedSeasonId,
                  isExpanded: true,
                  dropdownColor: kSurface,
                  iconEnabledColor: const Color(0xFF6366F1),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                  items: [for (final s in seasons) DropdownMenuItem(value: s.id, child: Text(s.name.toUpperCase(), overflow: TextOverflow.ellipsis))],
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

class _SeasonPanel extends StatelessWidget {
  final _SeasonGroup season;
  final bool isEditing;
  final VoidCallback onToggleEditing;
  final ValueChanged<_TeamPlayer> onEditPlayer;
  final ValueChanged<int> onAddPlayer;
  const _SeasonPanel({required this.season, required this.isEditing, required this.onToggleEditing, required this.onEditPlayer, required this.onAddPlayer});

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
                const Icon(Icons.layers_outlined, color: Color(0xFF6366F1), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(season.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0))),
                _SmallIconButton(icon: isEditing ? Icons.done_all_rounded : Icons.edit_outlined, color: isEditing ? kAccent : const Color(0xFF6366F1), onTap: onToggleEditing)
              ],
            ),
            const SizedBox(height: 16),
            for (final t in season.teams) ...[
              _TeamPanel(team: t, showEditActions: isEditing, onEditPlayer: onEditPlayer, onAddPlayer: () => onAddPlayer(t.id)),
              if (t != season.teams.last) const SizedBox(height: 12)
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamPanel extends StatelessWidget {
  final _TeamGroup team;
  final bool showEditActions;
  final ValueChanged<_TeamPlayer> onEditPlayer;
  final VoidCallback onAddPlayer;
  const _TeamPanel({required this.team, required this.showEditActions, required this.onEditPlayer, required this.onAddPlayer});

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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.hub_outlined, color: Color(0xFF34D399), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                    Text(_teamMeta(team), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (showEditActions) _SmallIconButton(icon: Icons.person_add_rounded, color: const Color(0xFF10B981), onTap: onAddPlayer),
              const SizedBox(width: 8),
              _CountPill(count: team.players.length, color: const Color(0xFF34D399))
            ],
          ),
          const SizedBox(height: 12),
          for (final p in team.players) ...[
            _PlayerTile(player: p, showEditAction: showEditActions, onEdit: () => onEditPlayer(p)),
            if (p != team.players.last) const SizedBox(height: 9)
          ],
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final _TeamPlayer player;
  final bool showEditAction;
  final VoidCallback onEdit;
  const _PlayerTile({required this.player, required this.showEditAction, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(imageUrl: player.imageUrl, name: player.name, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(player.name.isEmpty ? 'UNNAMED MEMBER' : player.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                  if (player.isGraduated) const _StatusPill(label: 'OFFLINE', color: Color(0xFFF59E0B))
                  else if (player.isActive) const _StatusPill(label: 'ACTIVE', color: Color(0xFF10B981)),
                  if (showEditAction) ...[
                    const SizedBox(width: 6),
                    _SmallIconButton(icon: Icons.edit_outlined, color: const Color(0xFF6366F1), onTap: onEdit),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (player.roles.isEmpty) const _RolePill(label: 'UNASSIGNED')
                  else for (final r in player.roles) _RolePill(label: r.toUpperCase())
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GenericMemberCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  const _GenericMemberCard({required this.row, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = _displayGenericName(row);
    final sub = _displayGenericSubtitle(row);
    final img = _nullableString(row['profile_image_url'] ?? row['image_url'] ?? row['avatar_url']);
    final active = row['is_active'] == true;
    final grad = row['is_graduated'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 10),
      child: TechnicalCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Avatar(imageUrl: img, name: name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
                      if (grad) const _StatusPill(label: 'OFFLINE', color: Color(0xFFF59E0B))
                      else if (active) const _StatusPill(label: 'ACTIVE', color: Color(0xFF10B981))
                    ],
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10, fontWeight: FontWeight.w700))
                  ]
                ],
              ),
            ),
            const SizedBox(width: 8),
            _SmallIconButton(icon: Icons.edit_outlined, color: const Color(0xFF34D399), onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

class _MediaMemberCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  const _MediaMemberCard({required this.row, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = _stringValue(row['name']);
    final pos = _stringValue(row['position']);
    final active = row['is_active'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 10),
      child: TechnicalCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Avatar(imageUrl: _nullableString(row['image_url']), name: name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'UNNAMED MEDIA' : name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  if (pos.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(pos.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10, fontWeight: FontWeight.w700))
                  ],
                ],
              ),
            ),
            if (active) const _StatusPill(label: 'ACTIVE', color: Color(0xFFEC4899)),
            const SizedBox(width: 8),
            _SmallIconButton(icon: Icons.edit_outlined, color: const Color(0xFFEC4899), onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  const _CoachCard({required this.row, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final name = _stringValue(row['name']);
    final active = row['is_active'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 10),
      child: TechnicalCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Avatar(imageUrl: _nullableString(row['image_url']), name: name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'UNNAMED COACH' : name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (active) const _StatusPill(label: 'ACTIVE', color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _SmallIconButton(icon: Icons.edit_outlined, color: const Color(0xFFF59E0B), onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  const _Avatar({this.imageUrl, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: ClipOval(child: imageUrl == null ? _AvatarFallback(initials: initials) : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _AvatarFallback(initials: initials))),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;
  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center, color: kSurface, child: Text(initials, style: const TextStyle(color: kAccent, fontSize: 10, fontWeight: FontWeight.w900)));
  }
}

class _RolePill extends StatelessWidget {
  final String label;
  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kPadding, 0, kPadding, 10),
      child: TechnicalCard(child: Text(text.toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
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
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF87171), size: 32),
              const SizedBox(height: 12),
              const Text('ERROR', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              const SizedBox(height: 8),
              Text(message.toUpperCase(), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TechnicalButton(label: 'Retry', onTap: onRetry, color: const Color(0xFFF87171))
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMemberMenu extends StatelessWidget {
  final VoidCallback onAddTeamPlayer;
  final VoidCallback onAddGeneric;
  final VoidCallback onAddMedia;
  final VoidCallback onAddCoach;

  const _AddMemberMenu({
    required this.onAddTeamPlayer,
    required this.onAddGeneric,
    required this.onAddMedia,
    required this.onAddCoach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuOption(label: 'TEAM MEMBER', icon: Icons.group_add_rounded, color: const Color(0xFF6366F1), onTap: onAddTeamPlayer),
          const SizedBox(height: 12),
          _MenuOption(label: 'PERSONNEL', icon: Icons.person_add_rounded, color: const Color(0xFF10B981), onTap: onAddGeneric),
          const SizedBox(height: 12),
          _MenuOption(label: 'MEDIA TEAM', icon: Icons.camera_enhance_rounded, color: const Color(0xFFEC4899), onTap: onAddMedia),
          const SizedBox(height: 12),
          _MenuOption(label: 'COACH', icon: Icons.sports_rounded, color: const Color(0xFFF59E0B), onTap: onAddCoach),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MenuOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuOption({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label.toUpperCase(),
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0),
    filled: true,
    fillColor: kBackground.withValues(alpha: 0.3),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: const BorderSide(color: kAccent, width: 1.0)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: const BorderSide(color: Color(0xFFF87171))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius), borderSide: const BorderSide(color: Color(0xFFF87171))),
  );
}

String? _requiredValidator(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

String _stringValue(Object? v) => v?.toString().trim() ?? '';

String? _nullableString(Object? v) {
  final s = _stringValue(v);
  return s.isEmpty ? null : s;
}

int? _intValue(Object? v) {
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '');
}

List<Map<String, dynamic>> _asMapList(Object? v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((r) => r.map((k, v) => MapEntry(k.toString(), v))).toList();
}

String _displaySeasonName(Map r, int id) {
  final n = _stringValue(r['season_name']);
  return n.isEmpty ? 'Season $id' : n;
}

String _displayTeamName(Map r) => _stringValue(r['team_name']).isEmpty ? 'TEAM ${_intValue(r['id']) ?? 0}' : _stringValue(r['team_name']);

String _teamMeta(_TeamGroup t) => [if (t.number > 0) 'Team ${t.number}', if (t.code.isNotEmpty) t.code].join(' | ');

String _displayGenericName(Map r) => _stringValue(r['name'] ?? r['full_name'] ?? r['username'] ?? r['email']).isEmpty ? 'MEMBER ${_intValue(r['id']) ?? 0}' : _stringValue(r['name'] ?? r['full_name'] ?? r['username'] ?? r['email']);

String _displayGenericSubtitle(Map r) => _stringValue(rowValue(r, ['role', 'position', 'email', 'status']));

String rowValue(Map r, List<String> keys) {
  for (final k in keys) {
    if (r.containsKey(k)) return _stringValue(r[k]);
  }
  return '';
}

String? _firstExistingKey(Map<String, dynamic>? r, List<String> keys) {
  if (r == null) return null;
  for (final k in keys) {
    if (r.containsKey(k)) return k;
  }
  return null;
}

String _fieldLabel(String key) => key.split('_').where((p) => p.isNotEmpty).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join(' ');

String _initials(String v) {
  final words = v.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return '${words.first.characters.first}${words.last.characters.first}'.toUpperCase();
}
