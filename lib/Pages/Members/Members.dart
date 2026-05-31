import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Members extends StatefulWidget {
  const Members({super.key});

  @override
  State<Members> createState() => _MembersState();
}

class _MembersState extends State<Members> {
  final _supabase = Supabase.instance.client;

  late Future<_MembersPageData> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembersData();
  }

  Future<_MembersPageData> _loadMembersData() async {
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
              is_active
            ),
            season:seasons(
              id,
              season_name
            )
          '''),
      _supabase.from('member_roles').select('member_id, role:roles(role_name)'),
      _supabase.from('members').select(),
      _supabase
          .from('media_team')
          .select('id, name, position, image_url, is_active'),
    ]);

    final assignments = _asMapList(results[0]);
    final roleRows = _asMapList(results[1]);
    final members = _asMapList(results[2]);
    final mediaTeam = _asMapList(results[3])
      ..sort(
        (a, b) => _stringValue(a['name']).compareTo(_stringValue(b['name'])),
      );

    final rolesByMemberId = <int, List<String>>{};
    for (final row in roleRows) {
      final memberId = _intValue(row['member_id']);
      final role = row['role'];
      if (memberId == null || role is! Map) continue;

      final roleName = _stringValue(role['role_name']);
      if (roleName.isEmpty) continue;
      rolesByMemberId.putIfAbsent(memberId, () => <String>[]).add(roleName);
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
          name: _stringValue(memberMap['name']),
          imageUrl: _nullableString(memberMap['profile_image_url']),
          isActive: memberMap['is_active'] == true,
          isGraduated: memberMap['is_graduated'] == true,
          roles: rolesByMemberId[memberId] ?? const <String>[],
        ),
      );
    }

    final seasons = seasonsById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final season in seasons) {
      for (final team in season.teamsById.values) {
        team.players.sort((a, b) => a.name.compareTo(b.name));
      }
    }

    return _MembersPageData(
      seasons: seasons,
      members: members,
      mediaTeam: mediaTeam,
    );
  }

  Future<void> _refresh() async {
    setState(() => _membersFuture = _loadMembersData());
    await _membersFuture;
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
                          ),
                        ),
                        if (data.seasons.isEmpty)
                          const SliverToBoxAdapter(
                            child: _EmptyState(text: 'No team players found.'),
                          )
                        else
                          SliverList.builder(
                            itemCount: data.seasons.length,
                            itemBuilder: (context, index) {
                              return _SeasonPanel(season: data.seasons[index]);
                            },
                          ),
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Members',
                            count: data.members.length,
                            color: const Color(0xFF10B981),
                            topPadding: 28,
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
                              );
                            },
                          ),
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            label: 'Media Team',
                            count: data.mediaTeam.length,
                            color: const Color(0xFFEC4899),
                            topPadding: 28,
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
}

class _MembersPageData {
  final List<_SeasonGroup> seasons;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> mediaTeam;

  const _MembersPageData({
    required this.seasons,
    required this.members,
    required this.mediaTeam,
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
  final String name;
  final String? imageUrl;
  final bool isActive;
  final bool isGraduated;
  final List<String> roles;

  const _TeamPlayer({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.isActive,
    required this.isGraduated,
    required this.roles,
  });
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

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    this.topPadding = 18,
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
        ],
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

class _SeasonPanel extends StatelessWidget {
  final _SeasonGroup season;

  const _SeasonPanel({required this.season});

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
              ],
            ),
            const SizedBox(height: 14),
            for (final team in season.teams) ...[
              _TeamPanel(team: team),
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

  const _TeamPanel({required this.team});

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
            _PlayerTile(player: player),
            if (player != team.players.last) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final _TeamPlayer player;

  const _PlayerTile({required this.player});

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

  const _GenericMemberCard({required this.row});

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
          ],
        ),
      ),
    );
  }
}

class _MediaMemberCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _MediaMemberCard({required this.row});

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
