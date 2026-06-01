import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'member_form.dart';

class Members extends StatefulWidget {
  const Members({super.key});

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  final _supabase = Supabase.instance.client;

  late Future<_MembersPageData> _membersFuture;
  int? _selectedSeasonId;
  bool _isEditingSelectedSeason = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembersData();
  }

  Future<_MembersPageData> _loadMembersData() async {
    debugPrint('[_loadMembersData] fetching data...');
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
      _supabase
          .from('media_team')
          .select('id, name, position, image_url, is_active'),
      _supabase
          .from('teams')
          .select('id, team_name, team_number, team_code, is_active, season_id')
          .order('team_number'),
      _supabase.from('seasons').select('id, season_name').order('id'),
      _supabase.from('roles').select('id, role_name').order('role_name'),
    ]);
    debugPrint('[_loadMembersData] fetched ${results.length} result sets');

    final assignments = _asMapList(results[0]);
    debugPrint('[_loadMembersData] assignments count: ${assignments.length}');
    final roleRows = _asMapList(results[1]);
    final members = _asMapList(results[2]);
    final mediaTeam = _asMapList(results[3])
      ..sort(
        (a, b) => _stringValue(a['name']).compareTo(_stringValue(b['name'])),
      );
    final teams = _asMapList(
      results[4],
    ).map(_TeamOption.fromRow).where((team) => team.id != null).toList();
    final seasons = _asMapList(
      results[5],
    ).map(_SeasonOption.fromRow).where((season) => season.id != null).toList();
    final roles = _asMapList(
      results[6],
    ).map(_RoleOption.fromRow).where((role) => role.id != null).toList();

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

      final season = seasonsById.putIfAbsent(
        seasonId,
        () => _SeasonGroup(
          id: seasonId,
          name: _displaySeasonName(seasonMap, seasonId),
          teamsById: <int, _TeamGroup>{},
        ),
      );

      final team = season.teamsById.putIfAbsent(
        teamId,
        () => _TeamGroup(
          id: teamId,
          name: _displayTeamName(teamMap),
          number: _intValue(teamMap['team_number']) ?? 0,
          code: _stringValue(teamMap['team_code']),
          players: <_TeamPlayer>[],
        ),
      );

      team.players.add(
        _TeamPlayer(
          id: memberId,
          assignmentId: _intValue(row['id']),
          teamId: teamId,
          seasonId: seasonId,
          name: _stringValue(memberMap['name']),
          imageUrl: _nullableString(memberMap['profile_image_url']),
          isActive: memberMap['is_active'] == true,
          isGraduated: memberMap['is_graduated'] == true,
          roles: rolesByMemberSeason['$memberId:$seasonId'] ?? const <String>[],
        ),
      );
    }

    final seasonGroups = seasonsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final season in seasonGroups) {
      for (final team in season.teamsById.values) {
        team.players.sort((a, b) => a.name.compareTo(b.name));
      }
    }

    final totalPlayers = seasonGroups.fold<int>(
      0,
      (sum, s) => sum + s.teamsById.values.fold<int>(0, (tSum, t) => tSum + t.players.length),
    );
    debugPrint(
      '[_loadMembersData] built ${seasonGroups.length} seasons, $totalPlayers players',
    );
    for (final s in seasonGroups) {
      for (final t in s.teamsById.values) {
        debugPrint(
          '[_loadMembersData]   season="${s.name}" team="${t.name}" players=${t.players.length}',
        );
        for (final p in t.players) {
          debugPrint(
            '[_loadMembersData]     player id=${p.id} name="${p.name}" isActive=${p.isActive} isGraduated=${p.isGraduated}',
          );
        }
      }
    }

    return _MembersPageData(
      seasons: seasonGroups,
      members: members,
      mediaTeam: mediaTeam,
      teams: teams,
      seasonOptions: seasons,
      roles: roles,
    );
  }

  Future<void> _refresh() async {
    debugPrint('[_refresh] called');
    final future = _loadMembersData();
    setState(() {
      _membersFuture = future;
    });
    await future;
    debugPrint('[_refresh] complete');
  }

  Future<void> _reload() async {
    if (!mounted) return;
    debugPrint('[_reload] called');
    final future = _loadMembersData();
    setState(() {
      _membersFuture = future;
    });
    debugPrint('[_reload] complete');
  }

  Future<void> _openTeamPlayerForm({
    required _MembersPageData data,
    _TeamPlayer? player,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TeamPlayerFormSheet(
        player: player,
        teams: data.teams,
        seasons: data.seasonOptions,
        roles: data.roles,
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _openGenericMemberForm({Map<String, dynamic>? row}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GenericMemberFormSheet(row: row),
    );
    if (saved == true) await _reload();
  }

  Future<void> _openMediaMemberForm({Map<String, dynamic>? row}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MediaMemberFormSheet(row: row),
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: Stack(
        children: [
          const _MembersBackground(),
          SafeArea(
            child: FutureBuilder<_MembersPageData>(
              future: _membersFuture,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final selectedSeason = data == null
                    ? null
                    : _selectedSeason(data);
                return RefreshIndicator(
                  onRefresh: _refresh,
                  backgroundColor: const Color(0xFF111827),
                  color: const Color(0xFF6366F1),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                          child: _MembersTopBar(
                            isLoading:
                                snapshot.connectionState ==
                                ConnectionState.waiting,
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
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Team Players',
                            count: data.playerCount,
                            color: const Color(0xFF6366F1),
                            onAdd: () => _openTeamPlayerForm(data: data),
                          ),
                        ),
                        if (data.seasons.isEmpty)
                          const SliverToBoxAdapter(
                            child: _EmptyState(text: 'No team players found.'),
                          )
                        else ...[
                          SliverToBoxAdapter(
                            child: _SeasonSelector(
                              seasons: data.seasons,
                              selectedSeasonId: selectedSeason?.id,
                              onChanged: (seasonId) {
                                if (seasonId == null) return;
                                setState(() {
                                  _selectedSeasonId = seasonId;
                                  _isEditingSelectedSeason = false;
                                });
                              },
                            ),
                          ),
                          if (selectedSeason == null)
                            const SliverToBoxAdapter(
                              child: _EmptyState(text: 'Select a season.'),
                            )
                          else
                            SliverToBoxAdapter(
                              child: _SeasonPanel(
                                season: selectedSeason,
                                isEditing: _isEditingSelectedSeason,
                                onToggleEditing: () {
                                  setState(
                                    () => _isEditingSelectedSeason =
                                        !_isEditingSelectedSeason,
                                  );
                                },
                                onEditPlayer: (player) => _openTeamPlayerForm(
                                  data: data,
                                  player: player,
                                ),
                              ),
                            ),
                        ],
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Members',
                            count: data.members.length,
                            color: const Color(0xFF10B981),
                            topPadding: 28,
                            onAdd: _openGenericMemberForm,
                          ),
                        ),
                        if (data.members.isEmpty)
                          const SliverToBoxAdapter(
                            child: _EmptyState(text: 'No members found.'),
                          )
                        else
                          SliverList.builder(
                            itemCount: data.members.length,
                            itemBuilder: (context, index) {
                              return _GenericMemberCard(
                                row: data.members[index],
                                onEdit: () => _openGenericMemberForm(
                                  row: data.members[index],
                                ),
                              );
                            },
                          ),
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Media Team',
                            count: data.mediaTeam.length,
                            color: const Color(0xFFEC4899),
                            topPadding: 28,
                            onAdd: _openMediaMemberForm,
                          ),
                        ),
                        if (data.mediaTeam.isEmpty)
                          const SliverToBoxAdapter(
                            child: _EmptyState(text: 'No media team found.'),
                          )
                        else
                          SliverList.builder(
                            itemCount: data.mediaTeam.length,
                            itemBuilder: (context, index) {
                              return _MediaMemberCard(
                                row: data.mediaTeam[index],
                                onEdit: () => _openMediaMemberForm(
                                  row: data.mediaTeam[index],
                                ),
                              );
                            },
                          ),
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

  _SeasonGroup? _selectedSeason(_MembersPageData data) {
    if (data.seasons.isEmpty) return null;

    final selectedId = _selectedSeasonId;
    if (selectedId != null) {
      for (final season in data.seasons) {
        if (season.id == selectedId) return season;
      }
    }

    return data.seasons.first;
  }
}

class _MembersPageData {
  final List<_SeasonGroup> seasons;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> mediaTeam;
  final List<_TeamOption> teams;
  final List<_SeasonOption> seasonOptions;
  final List<_RoleOption> roles;

  const _MembersPageData({
    required this.seasons,
    required this.members,
    required this.mediaTeam,
    required this.teams,
    required this.seasonOptions,
    required this.roles,
  });

  int get playerCount {
    var total = 0;
    for (final season in seasons) {
      for (final team in season.teamsById.values) {
        total += team.players.length;
      }
    }
    return total;
  }
}

class _SeasonGroup {
  final int id;
  final String name;
  final Map<int, _TeamGroup> teamsById;

  const _SeasonGroup({
    required this.id,
    required this.name,
    required this.teamsById,
  });

  List<_TeamGroup> get teams {
    final teams = teamsById.values.toList()
      ..sort((a, b) {
        final numberCompare = a.number.compareTo(b.number);
        if (numberCompare != 0) return numberCompare;
        return a.name.compareTo(b.name);
      });
    return teams;
  }
}

class _TeamGroup {
  final int id;
  final String name;
  final int number;
  final String code;
  final List<_TeamPlayer> players;

  const _TeamGroup({
    required this.id,
    required this.name,
    required this.number,
    required this.code,
    required this.players,
  });
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
    required this.assignmentId,
    required this.teamId,
    required this.seasonId,
    required this.name,
    required this.imageUrl,
    required this.isActive,
    required this.isGraduated,
    required this.roles,
  });
}

class _TeamOption {
  final int? id;
  final String name;
  final int? seasonId;

  const _TeamOption({required this.id, required this.name, this.seasonId});

  factory _TeamOption.fromRow(Map<String, dynamic> row) {
    final id = _intValue(row['id']);
    final number = _intValue(row['team_number']);
    final code = _stringValue(row['team_code']);
    final name = _displayTeamName(row);
    final meta = <String>[
      if (number != null) 'Team $number',
      if (code.isNotEmpty) code,
    ].join(' | ');

    return _TeamOption(
      id: id,
      name: meta.isEmpty ? name : '$name ($meta)',
      seasonId: _intValue(row['season_id']),
    );
  }
}

class _SeasonOption {
  final int? id;
  final String name;

  const _SeasonOption({required this.id, required this.name});

  factory _SeasonOption.fromRow(Map<String, dynamic> row) {
    final id = _intValue(row['id']);
    return _SeasonOption(id: id, name: _displaySeasonName(row, id ?? 0));
  }
}

class _RoleOption {
  final int? id;
  final String name;

  const _RoleOption({required this.id, required this.name});

  factory _RoleOption.fromRow(Map<String, dynamic> row) {
    return _RoleOption(
      id: _intValue(row['id']),
      name: _stringValue(row['role_name']),
    );
  }
}

class _MembersBackground extends StatelessWidget {
  const _MembersBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.1,
          colors: [Color(0x246366F1), Color(0x1014B8A6), Color(0x000B1020)],
          stops: [0, 0.46, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _MembersTopBar extends StatelessWidget {
  final bool isLoading;

  const _MembersTopBar({required this.isLoading});

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
                'Members',
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
              color: Color(0xFF818CF8),
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

class _SeasonSelector extends StatelessWidget {
  final List<_SeasonGroup> seasons;
  final int? selectedSeasonId;
  final ValueChanged<int?> onChanged;

  const _SeasonSelector({
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
              color: Color(0xFF818CF8),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedSeasonId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF111827),
                  iconEnabledColor: const Color(0xFF818CF8),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  items: [
                    for (final season in seasons)
                      DropdownMenuItem(
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

class _SeasonPanel extends StatelessWidget {
  final _SeasonGroup season;
  final bool isEditing;
  final VoidCallback onToggleEditing;
  final ValueChanged<_TeamPlayer> onEditPlayer;

  const _SeasonPanel({
    required this.season,
    required this.isEditing,
    required this.onToggleEditing,
    required this.onEditPlayer,
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
                  color: Color(0xFF818CF8),
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
                _SmallIconButton(
                  icon: isEditing ? Icons.check_rounded : Icons.edit_rounded,
                  color: isEditing
                      ? const Color(0xFF10B981)
                      : const Color(0xFF818CF8),
                  onTap: onToggleEditing,
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final team in season.teams) ...[
              _TeamPanel(
                team: team,
                showEditActions: isEditing,
                onEditPlayer: onEditPlayer,
              ),
              if (team != season.teams.last) const SizedBox(height: 12),
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

  const _TeamPanel({
    required this.team,
    required this.showEditActions,
    required this.onEditPlayer,
  });

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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: Color(0xFF34D399),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _teamMeta(team),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _CountPill(
                count: team.players.length,
                color: const Color(0xFF34D399),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final player in team.players) ...[
            _PlayerTile(
              player: player,
              showEditAction: showEditActions,
              onEdit: () => onEditPlayer(player),
            ),
            if (player != team.players.last) const SizedBox(height: 9),
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

  const _PlayerTile({
    required this.player,
    required this.showEditAction,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(imageUrl: player.imageUrl, name: player.name, size: 42),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      player.name.isEmpty ? 'Unnamed Player' : player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (player.isGraduated)
                    const _StatusPill(
                      label: 'Graduated',
                      color: Color(0xFFF59E0B),
                    )
                  else if (player.isActive)
                    const _StatusPill(
                      label: 'Active',
                      color: Color(0xFF10B981),
                    ),
                  if (showEditAction) ...[
                    const SizedBox(width: 6),
                    _SmallIconButton(
                      icon: Icons.edit_rounded,
                      color: const Color(0xFF818CF8),
                      onTap: onEdit,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (player.roles.isEmpty)
                    const _RolePill(label: 'No role')
                  else
                    for (final role in player.roles) _RolePill(label: role),
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
    final subtitle = _displayGenericSubtitle(row);
    final imageUrl = _nullableString(
      row['profile_image_url'] ?? row['image_url'] ?? row['avatar_url'],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: _GlassCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            _Avatar(imageUrl: imageUrl, name: name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
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
            _SmallIconButton(
              icon: Icons.edit_rounded,
              color: const Color(0xFF34D399),
              onTap: onEdit,
            ),
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
    final position = _stringValue(row['position']);
    final isActive = row['is_active'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: _GlassCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            _Avatar(
              imageUrl: _nullableString(row['image_url']),
              name: name,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Unnamed Media Member' : name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (position.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      position,
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
            if (isActive)
              const _StatusPill(label: 'Active', color: Color(0xFFEC4899)),
            const SizedBox(width: 8),
            _SmallIconButton(
              icon: Icons.edit_rounded,
              color: const Color(0xFFEC4899),
              onTap: onEdit,
            ),
          ],
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

class _Avatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;

  const _Avatar({
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipOval(
        child: imageUrl == null
            ? _AvatarFallback(initials: initials)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarFallback(initials: initials),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;

  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFF1F2937),
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF818CF8),
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;

  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
                'Unable to load members',
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

class _TeamPlayerFormSheet extends StatefulWidget {
  final _TeamPlayer? player;
  final List<_TeamOption> teams;
  final List<_SeasonOption> seasons;
  final List<_RoleOption> roles;

  const _TeamPlayerFormSheet({
    required this.player,
    required this.teams,
    required this.seasons,
    required this.roles,
  });

  @override
  State<_TeamPlayerFormSheet> createState() => _TeamPlayerFormSheetState();
}

class _TeamPlayerFormSheetState extends State<_TeamPlayerFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int? _teamId;
  int? _seasonId;
  late bool _isActive;
  late bool _isGraduated;
  late Set<int> _roleIds;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  List<_TeamOption> get _teamsForSeason {
    if (_seasonId == null) return const [];
    return widget.teams
        .where((t) => t.seasonId == null || t.seasonId == _seasonId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final player = widget.player;
    _nameController.text = player?.name ?? '';
    _imageController.text = player?.imageUrl ?? '';
    _teamId = player?.teamId ?? widget.teams.firstOrNull?.id;
    _seasonId = player?.seasonId ?? widget.seasons.firstOrNull?.id;
    _isActive = player?.isActive ?? true;
    _isGraduated = player?.isGraduated ?? false;
    _roleIds = widget.roles
        .where((role) => player?.roles.contains(role.name) ?? false)
        .map((role) => role.id)
        .whereType<int>()
        .toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_teamId == null || _seasonId == null) {
      _showError('Select a team and season first.');
      return;
    }

    setState(() => _isSaving = true);
    final isEditing = widget.player != null;
    debugPrint('[_TeamPlayerFormSheet._save] isEditing=$isEditing');
    debugPrint(
      '[_TeamPlayerFormSheet._save] name="${_nameController.text.trim()}" teamId=$_teamId seasonId=$_seasonId',
    );
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'profile_image_url': _nullableString(_imageController.text),
        'is_active': _isActive,
        'is_graduated': _isGraduated,
      };

      final player = widget.player;
      late final int memberId;
      if (player == null) {
        debugPrint('[_TeamPlayerFormSheet._save] inserting new team_member');
        final inserted = await _supabase
            .from('team_members')
            .insert(payload)
            .select('id')
            .single();
        memberId = _intValue(inserted['id'])!;
        debugPrint('[_TeamPlayerFormSheet._save] new memberId=$memberId');
      } else {
        memberId = player.id;
        debugPrint('[_TeamPlayerFormSheet._save] updating team_members id=$memberId');
        await _supabase.from('team_members').update(payload).eq('id', memberId);
        debugPrint('[_TeamPlayerFormSheet._save] team_members updated');
      }

      final assignmentPayload = {
        'member_id': memberId,
        'team_id': _teamId,
        'season_id': _seasonId,
      };
      if (player?.assignmentId == null) {
        debugPrint('[_TeamPlayerFormSheet._save] inserting assignment');
        await _supabase.from('member_team_seasons').insert(assignmentPayload);
      } else {
        final assignmentId = player!.assignmentId!;
        debugPrint(
          '[_TeamPlayerFormSheet._save] updating assignment id=$assignmentId',
        );
        await _supabase
            .from('member_team_seasons')
            .update(assignmentPayload)
            .eq('id', assignmentId);
      }
      debugPrint('[_TeamPlayerFormSheet._save] assignment done');

      debugPrint('[_TeamPlayerFormSheet._save] deleting old roles for memberId=$memberId');
      await _supabase
          .from('member_roles')
          .delete()
          .eq('member_id', memberId)
          .eq('season_id', _seasonId!);
      if (_roleIds.isNotEmpty) {
        debugPrint('[_TeamPlayerFormSheet._save] inserting ${_roleIds.length} roles');
        await _supabase.from('member_roles').insert([
          for (final roleId in _roleIds)
            {
              'member_id': memberId,
              'role_id': roleId,
              'season_id': _seasonId,
            },
        ]);
      }
      debugPrint('[_TeamPlayerFormSheet._save] roles done');

      if (mounted) {
        await _showSuccess(isEditing ? 'Team player updated successfully.' : 'Team player added successfully.');
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('[_TeamPlayerFormSheet._save] ERROR: $error');
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final url = await _uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'team_players',
      );
      _imageController.text = url;
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF34D399), size: 26),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.player != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Team Player' : 'Add Team Player',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _PhotoPickerInput(
              imageUrl: _nullableString(_imageController.text),
              isUploading: _isUploadingPicture,
              onPick: _pickProfilePicture,
            ),
            const SizedBox(height: 12),
            _DropdownInput<int>(
              label: 'Team',
              value: _teamsForSeason.any((t) => t.id == _teamId) ? _teamId : null,
              items: [
                for (final team in _teamsForSeason)
                  DropdownMenuItem(value: team.id, child: Text(team.name)),
              ],
              onChanged: (value) => setState(() => _teamId = value),
            ),
            if (!isEditing) ...[
              const SizedBox(height: 12),
              _DropdownInput<int>(
                label: 'Season',
                value: _seasonId,
                items: [
                  for (final season in widget.seasons)
                    DropdownMenuItem(value: season.id, child: Text(season.name)),
                ],
                onChanged: (value) {
                  setState(() {
                    _seasonId = value;
                    if (!_teamsForSeason.any((t) => t.id == _teamId)) {
                      _teamId = _teamsForSeason.firstOrNull?.id;
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 10),
            _SwitchInput(
              label: 'Active',
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            _SwitchInput(
              label: 'Graduated',
              value: _isGraduated,
              onChanged: (value) => setState(() => _isGraduated = value),
            ),
            const SizedBox(height: 10),
            _RoleSelector(
              roles: widget.roles,
              selectedIds: _roleIds,
              onChanged: (ids) => setState(() => _roleIds = ids),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaMemberFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;

  const _MediaMemberFormSheet({required this.row});

  @override
  State<_MediaMemberFormSheet> createState() => _MediaMemberFormSheetState();
}

class _MediaMemberFormSheetState extends State<_MediaMemberFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late bool _isActive;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _nameController.text = _stringValue(row?['name']);
    _positionController.text = _stringValue(row?['position']);
    _imageController.text = _stringValue(row?['image_url']);
    _isActive = row?['is_active'] == true || row == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _positionController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = widget.row != null;
    debugPrint('[_MediaMemberFormSheet._save] isEditing=$isEditing');
    debugPrint('[_MediaMemberFormSheet._save] name="${_nameController.text.trim()}"');
    try {
      final payload = {
        'name': _nameController.text.trim(),
        'position': _nullableString(_positionController.text),
        'image_url': _nullableString(_imageController.text),
        'is_active': _isActive,
      };
      final id = _intValue(widget.row?['id']);
      if (id == null) {
        debugPrint('[_MediaMemberFormSheet._save] inserting new media member');
        await _supabase.from('media_team').insert(payload);
      } else {
        debugPrint('[_MediaMemberFormSheet._save] updating media_team id=$id');
        await _supabase.from('media_team').update(payload).eq('id', id);
      }
      debugPrint('[_MediaMemberFormSheet._save] success');
      if (mounted) {
        await _showSuccess(isEditing ? 'Media member updated successfully.' : 'Media member added successfully.');
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('[_MediaMemberFormSheet._save] ERROR: $error');
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final url = await _uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'media_team',
      );
      _imageController.text = url;
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF34D399), size: 26),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.row != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Media Member' : 'Add Media Member',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _TextFieldInput(controller: _positionController, label: 'Position'),
            const SizedBox(height: 12),
            _PhotoPickerInput(
              imageUrl: _nullableString(_imageController.text),
              isUploading: _isUploadingPicture,
              onPick: _pickProfilePicture,
            ),
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

class _GenericMemberFormSheet extends StatefulWidget {
  final Map<String, dynamic>? row;

  const _GenericMemberFormSheet({required this.row});

  @override
  State<_GenericMemberFormSheet> createState() =>
      _GenericMemberFormSheetState();
}

class _GenericMemberFormSheetState extends State<_GenericMemberFormSheet> {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();
  final _nameController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _imageController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final String _nameKey;
  late final String? _subtitleKey;
  late final String? _imageKey;
  late bool _isActive;
  bool _isSaving = false;
  bool _isUploadingPicture = false;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _nameKey =
        _firstExistingKey(row, ['name', 'full_name', 'username', 'email']) ??
        'name';
    _subtitleKey = _firstExistingKey(row, [
      'role',
      'position',
      'email',
      'status',
    ]);
    _imageKey =
        _firstExistingKey(row, [
          'profile_image_url',
          'image_url',
          'avatar_url',
        ]) ??
        'image_url';
    _nameController.text = _stringValue(row?[_nameKey]);
    if (_subtitleKey != null) {
      _subtitleController.text = _stringValue(row?[_subtitleKey]);
    }
    if (_imageKey != null) {
      _imageController.text = _stringValue(row?[_imageKey]);
    }
    _isActive = row?['is_active'] == true || row == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final isEditing = widget.row != null;
    debugPrint('[_GenericMemberFormSheet._save] isEditing=$isEditing');
    debugPrint('[_GenericMemberFormSheet._save] nameKey=$_nameKey name="${_nameController.text.trim()}"');
    try {
      final payload = <String, dynamic>{_nameKey: _nameController.text.trim()};
      final imageKey = _imageKey;
      if (imageKey != null) {
        payload[imageKey] = _nullableString(_imageController.text);
      }

      if (widget.row != null) {
        final subtitleKey = _subtitleKey;
        if (subtitleKey != null) {
          payload[subtitleKey] = _nullableString(_subtitleController.text);
        }
        if (widget.row!.containsKey('is_active')) {
          payload['is_active'] = _isActive;
        }
      }

      final id = _intValue(widget.row?['id']);
      debugPrint('[_GenericMemberFormSheet._save] id=$id payload=$payload');
      if (id == null) {
        debugPrint('[_GenericMemberFormSheet._save] inserting new member');
        await _supabase.from('members').insert(payload);
      } else {
        debugPrint('[_GenericMemberFormSheet._save] updating members id=$id');
        await _supabase.from('members').update(payload).eq('id', id);
      }
      debugPrint('[_GenericMemberFormSheet._save] success');
      if (mounted) {
        await _showSuccess(isEditing ? 'Member updated successfully.' : 'Member added successfully.');
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('[_GenericMemberFormSheet._save] ERROR: $error');
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickProfilePicture() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null) return;

    setState(() => _isUploadingPicture = true);
    try {
      final url = await _uploadMemberPicture(
        supabase: _supabase,
        image: image,
        folder: 'members',
      );
      _imageController.text = url;
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isUploadingPicture = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showSuccess(String message) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF34D399), size: 26),
            SizedBox(width: 10),
            Text('Success', style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.row != null;
    return _FormSheetScaffold(
      title: isEditing ? 'Edit Member' : 'Add Member',
      isSaving: _isSaving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TextFieldInput(
              controller: _nameController,
              label: 'Name',
              validator: _requiredValidator,
            ),
            if (_subtitleKey case final subtitleKey?) ...[
              const SizedBox(height: 12),
              _TextFieldInput(
                controller: _subtitleController,
                label: _fieldLabel(subtitleKey),
              ),
            ],
            if (_imageKey case final imageKey?) ...[
              const SizedBox(height: 12),
              _PhotoPickerInput(
                imageUrl: _nullableString(_imageController.text),
                isUploading: _isUploadingPicture,
                onPick: _pickProfilePicture,
              ),
            ],
            if (widget.row?.containsKey('is_active') ?? false) ...[
              const SizedBox(height: 10),
              _SwitchInput(
                label: 'Active',
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextFieldInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _TextFieldInput({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
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
          _Avatar(imageUrl: imageUrl, name: 'Profile Picture', size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile picture',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isUploading
                      ? 'Uploading to member_pictures...'
                      : 'Choose from gallery',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _SmallIconButton(
            icon: isUploading
                ? Icons.hourglass_top_rounded
                : Icons.photo_library_rounded,
            color: const Color(0xFF818CF8),
            onTap: isUploading ? () {} : onPick,
          ),
        ],
      ),
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: const Color(0xFF111827),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label),
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
      activeThumbColor: const Color(0xFF818CF8),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final List<_RoleOption> roles;
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;

  const _RoleSelector({
    required this.roles,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) {
      return Text(
        'No roles available.',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Roles',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in roles)
              Builder(
                builder: (context) {
                  final isSelected = selectedIds.contains(role.id);
                  return FilterChip(
                    label: Text(
                      role.name,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      final id = role.id;
                      if (id == null) return;
                      final next = Set<int>.from(selectedIds);
                      if (selected) {
                        next.add(id);
                      } else {
                        next.remove(id);
                      }
                      onChanged(next);
                    },
                    selectedColor: const Color(
                      0xFF6366F1,
                    ).withValues(alpha: 0.45),
                    backgroundColor: const Color(
                      0xFF111827,
                    ).withValues(alpha: 0.96),
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF818CF8).withValues(alpha: 0.62)
                          : Colors.white.withValues(alpha: 0.09),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                },
              ),
          ],
        ),
      ],
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
      borderSide: const BorderSide(color: Color(0xFF818CF8)),
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

Future<String> _uploadMemberPicture({
  required SupabaseClient supabase,
  required XFile image,
  required String folder,
}) async {
  final bytes = await image.readAsBytes();
  final extension = _fileExtension(image.name);
  final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final fileName =
      '$safeFolder/${DateTime.now().microsecondsSinceEpoch}$extension';

  await supabase.storage
      .from('member_pictures')
      .uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentTypeForExtension(extension),
          upsert: true,
        ),
      );

  return supabase.storage.from('member_pictures').getPublicUrl(fileName);
}

String _fileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) return '.jpg';
  return fileName.substring(dotIndex).toLowerCase();
}

String _contentTypeForExtension(String extension) {
  switch (extension.toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.heic':
      return 'image/heic';
    case '.jpg':
    case '.jpeg':
    default:
      return 'image/jpeg';
  }
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];

  return value
      .whereType<Map>()
      .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
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

String _displaySeasonName(Map seasonMap, int id) {
  final name = _stringValue(seasonMap['season_name']);
  return name.isEmpty ? 'Season $id' : name;
}

String _displayTeamName(Map teamMap) {
  final name = _stringValue(teamMap['team_name']);
  if (name.isNotEmpty) return name;

  final code = _stringValue(teamMap['team_code']);
  if (code.isNotEmpty) return code;

  final number = _intValue(teamMap['team_number']);
  return number == null ? 'Unnamed Team' : 'Team $number';
}

String _teamMeta(_TeamGroup team) {
  final parts = <String>[];
  if (team.number > 0) parts.add('Team ${team.number}');
  if (team.code.isNotEmpty) parts.add(team.code);
  return parts.isEmpty ? 'Team roster' : parts.join(' | ');
}

String _displayGenericName(Map<String, dynamic> row) {
  for (final key in ['name', 'full_name', 'username', 'email']) {
    final value = _stringValue(row[key]);
    if (value.isNotEmpty) return value;
  }
  return 'Unnamed Member';
}

String _displayGenericSubtitle(Map<String, dynamic> row) {
  for (final key in ['role', 'position', 'email', 'status']) {
    final value = _stringValue(row[key]);
    if (value.isNotEmpty && value != _displayGenericName(row)) return value;
  }
  return '';
}

String? _firstExistingKey(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return null;
  for (final key in keys) {
    if (row.containsKey(key)) return key;
  }
  return null;
}

String _fieldLabel(String key) {
  return key
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.characters.first.toUpperCase();
  return '${words.first.characters.first}${words.last.characters.first}'
      .toUpperCase();
}
