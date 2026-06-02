import 'package:flutter/material.dart';
import 'package:qcurobotics_management_app/Pages/Members/Members.dart';
import 'package:qcurobotics_management_app/Pages/Profile/profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardOverviewData {
  final int totalMembers;
  final int totalTournaments;
  final int totalAchievements;
  final int totalSponsors;
  final int totalTeams;

  const _DashboardOverviewData({
    required this.totalMembers,
    required this.totalTournaments,
    required this.totalAchievements,
    required this.totalSponsors,
    required this.totalTeams,
  });
}

class _DashboardState extends State<Dashboard> {
  static const Duration _overviewCacheDuration = Duration(minutes: 5);
  static _DashboardOverviewData? _cachedOverview;
  static DateTime? _cachedOverviewAt;

  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;

  int _totalMembers = 0;
  int _totalTournaments = 0;
  int _totalAchievements = 0;
  int _totalSponsors = 0;
  int _totalTeams = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  bool get _hasFreshOverviewCache {
    final cachedAt = _cachedOverviewAt;
    if (_cachedOverview == null || cachedAt == null) return false;
    return DateTime.now().difference(cachedAt) < _overviewCacheDuration;
  }

  void _applyOverviewData(
    _DashboardOverviewData data, {
    required bool loading,
  }) {
    _totalMembers = data.totalMembers;
    _totalTournaments = data.totalTournaments;
    _totalAchievements = data.totalAchievements;
    _totalSponsors = data.totalSponsors;
    _totalTeams = data.totalTeams;
    _isLoading = loading;
  }

  Future<void> _loadOverviewData({bool forceRefresh = false}) async {
    if (!mounted) return;

    final cachedData = _cachedOverview;
    if (!forceRefresh && _hasFreshOverviewCache && cachedData != null) {
      setState(() => _applyOverviewData(cachedData, loading: false));
      debugPrint('Using cached dashboard overview data.');
      return;
    }

    await _fetchOverviewData();
  }

  Future<void> _fetchOverviewData() async {
    if (!mounted) return;
    setState(() {
      final cachedData = _cachedOverview;
      if (cachedData != null) {
        _applyOverviewData(cachedData, loading: false);
      } else {
        _isLoading = true;
      }
    });
    debugPrint('🔄 Starting fetch...');
    try {
      debugPrint('📡 Fetching team_members...');
      final teamMembersRes = await _supabase.from('team_members').count();
      debugPrint('✅ team_members count: $teamMembersRes');

      debugPrint('📡 Fetching media_team...');
      final mediaTeamRes = await _supabase.from('media_team').count();
      debugPrint('✅ media_team count: $mediaTeamRes');

      debugPrint('📡 Fetching members...');
      final membersRes = await _supabase.from('members').count();
      debugPrint('✅ members count: $membersRes');

      debugPrint('📡 Fetching competitions...');
      final tournamentsRes = await _supabase.from('competitions').count();
      debugPrint('✅ competitions count: $tournamentsRes');

      debugPrint('📡 Fetching Achievements...');
      final achievementsRes = await _supabase.from('Achievements').count();
      debugPrint('✅ Achievements count: $achievementsRes');

      debugPrint('📡 Fetching sponsors...');
      final sponsorsRes = await _supabase.from('sponsors').count();
      debugPrint('✅ sponsors count: $sponsorsRes');

      debugPrint('📡 Fetching active teams...');
      final activeTeamsRes = await _supabase
          .from('teams')
          .count()
          .eq('is_active', true);
      debugPrint('✅ active teams count: $activeTeamsRes');

      if (mounted) {
        final overviewData = _DashboardOverviewData(
          totalMembers: teamMembersRes + mediaTeamRes + membersRes,
          totalTournaments: tournamentsRes,
          totalAchievements: achievementsRes,
          totalSponsors: sponsorsRes,
          totalTeams: activeTeamsRes,
        );
        _cachedOverview = overviewData;
        _cachedOverviewAt = DateTime.now();

        setState(() {
          _applyOverviewData(overviewData, loading: false);
        });
        debugPrint(
          '✅ State updated — Members: $_totalMembers, Tournaments: $_totalTournaments, Achievements: $_totalAchievements, Sponsors: $_totalSponsors, Teams: $_totalTeams',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR: $e');
      debugPrint('📋 StackTrace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0B1020),
      body: Stack(
        children: [
          const _DashboardBackground(),

          RepaintBoundary(
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: () => _loadOverviewData(forceRefresh: true),
                backgroundColor: const Color(0xFF1a1a3e),
                color: const Color(0xFF6366F1),
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(),
                  cacheExtent: 360,
                  slivers: [
                    // Top bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: _TopBar(
                          greeting: _getGreeting(),
                          userName: _supabase.auth.currentUser?.userMetadata?['full_name'],
                          photoUrl: _supabase.auth.currentUser?.userMetadata?['avatar_url'],
                        ),
                      ),
                    ),

                    // Overview header
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        label: 'Overview',
                        color: Colors.cyanAccent,
                      ),
                    ),

                    // Stats grid (2x2)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.65,
                            ),
                        delegate: SliverChildListDelegate([
                          _StatCard(
                            title: 'Total Members',
                            value: _totalMembers.toString(),
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF6366F1),
                            isLoading: _isLoading,
                          ),
                          _StatCard(
                            title: 'Tournaments',
                            value: _totalTournaments.toString(),
                            icon: Icons.emoji_events_rounded,
                            color: const Color(0xFFF59E0B),
                            isLoading: _isLoading,
                          ),
                          _StatCard(
                            title: 'Achievements',
                            value: _totalAchievements.toString(),
                            icon: Icons.military_tech_rounded,
                            color: const Color(0xFF10B981),
                            isLoading: _isLoading,
                          ),
                          _StatCard(
                            title: 'Sponsors',
                            value: _totalSponsors.toString(),
                            icon: Icons.business_center_rounded,
                            color: const Color(0xFFEC4899),
                            isLoading: _isLoading,
                          ),
                        ]),
                      ),
                    ),

                    // Active teams full-width
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _StatCard(
                          title: 'Active Teams',
                          value: _totalTeams.toString(),
                          icon: Icons.hub_rounded,
                          color: const Color(0xFF06B6D4),
                          isLoading: _isLoading,
                          fullWidth: true,
                        ),
                      ),
                    ),

                    // Management header
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        label: 'Management',
                        color: const Color(0xFF6366F1),
                        topPadding: 32,
                      ),
                    ),

                    // Management actions
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _ManagementRow(),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 140)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── Glow blob ──────────────────────────────────────────────────────────────

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.15,
            colors: [Color(0x1F6366F1), Color(0x0F14B8A6), Color(0x000B1020)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.bottomLeft,
                radius: 1.1,
                colors: [Color(0x1414B8A6), Color(0x000B1020)],
                stops: [0, 0.72],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Glass card ─────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final List<BoxShadow>? shadows;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tint,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow:
            shadows ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: tint ?? const Color(0xFF111827).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.012),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final double topPadding;

  const _SectionHeader({
    required this.label,
    required this.color,
    this.topPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 16),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String greeting;
  final String? userName;
  final String? photoUrl;

  const _TopBar({
    required this.greeting,
    this.userName,
    this.photoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = (userName ?? 'User').split(' ').first;

    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
              ),
            ),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0B1020),
              ),
              padding: const EdgeInsets.all(2),
              child: CircleAvatar(
                radius: 23,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl!)
                    : const NetworkImage('https://i.pravatar.cc/150?img=11'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                firstName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        _GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 18,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: Colors.white,
                size: 24,
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final bool fullWidth;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isLoading,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 18,
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.24),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLoading)
                  Container(
                    height: 22,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fullWidth ? 26 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (fullWidth)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: color, size: 7),
                  const SizedBox(width: 5),
                  Text(
                    'Active',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Management actions ─────────────────────────────────────────────────────

class _ManagementRow extends StatelessWidget {
  const _ManagementRow();

  final _items = const [
    _MgmtItem(
      label: 'Members',
      icon: Icons.people_alt_rounded,
      color: Color(0xFF6366F1),
      destination: Members(),
    ),
    _MgmtItem(
      label: 'Teams',
      icon: Icons.hub_rounded,
      color: Color(0xFF10B981),
    ),
    _MgmtItem(
      label: 'Competitions',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFFF59E0B),
    ),
    _MgmtItem(
      label: 'Contents',
      icon: Icons.auto_awesome_motion_rounded,
      color: Color(0xFFEC4899),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in _items) ...[
          _ManagementButton(item: item),
          if (item != _items.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MgmtItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget? destination;
  const _MgmtItem({
    required this.label,
    required this.icon,
    required this.color,
    this.destination,
  });
}

class _ManagementButton extends StatefulWidget {
  final _MgmtItem item;
  const _ManagementButton({required this.item});

  @override
  State<_ManagementButton> createState() => _ManagementButtonState();
}

class _ManagementButtonState extends State<_ManagementButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        final destination = item.destination;
        if (destination == null) return;

        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => destination));
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  item.color.withValues(alpha: 0.16),
                  const Color(0xFF111827).withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: item.color.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.045),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: item.color.withValues(alpha: 0.82),
                    size: 24,
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

// ── Bottom nav ─────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 126,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF050816).withValues(alpha: 0.76),
                    ],
                    stops: const [0.08, 1],
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.42),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _GlassCard(
              padding: EdgeInsets.zero,
              radius: 28,
              tint: const Color(0xFF0B1020).withValues(alpha: 0.98),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavIcon(
                    icon: Icons.grid_view_rounded,
                    active: selectedIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _NavIcon(
                    icon: Icons.analytics_outlined,
                    active: selectedIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  _NavIcon(
                    icon: Icons.person_outline_rounded,
                    active: selectedIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  _NavIcon(
                    icon: Icons.settings_rounded,
                    active: selectedIndex == 3,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6366F1).withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          icon,
          color: active
              ? const Color(0xFF818CF8)
              : Colors.white.withValues(alpha: 0.3),
          size: 26,
        ),
      ),
    );
  }
}
