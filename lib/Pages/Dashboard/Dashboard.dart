import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _bgController;
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
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    _fetchOverviewData();
  }

  Future<void> _fetchOverviewData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
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
      final activeTeamsRes =
      await _supabase.from('teams').count().eq('is_active', true);
      debugPrint('✅ active teams count: $activeTeamsRes');

      if (mounted) {
        setState(() {
          _totalMembers = teamMembersRes + mediaTeamRes + membersRes;
          _totalTournaments = tournamentsRes;
          _totalAchievements = achievementsRes;
          _totalSponsors = sponsorsRes;
          _totalTeams = activeTeamsRes;
          _isLoading = false;
        });
        debugPrint(
            '✅ State updated — Members: $_totalMembers, Tournaments: $_totalTournaments, Achievements: $_totalAchievements, Sponsors: $_totalSponsors, Teams: $_totalTeams');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR: $e');
      debugPrint('📋 StackTrace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF080720),
      body: Stack(
        children: [
          // Animated background blobs
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) => Stack(
              children: [
                Positioned(
                  top: -80 + (40 * _bgController.value),
                  right: -60 - (30 * _bgController.value),
                  child: _GlowBlob(
                      color: const Color(0xFF6366F1).withOpacity(0.18),
                      size: 380),
                ),
                Positioned(
                  bottom: 80 - (40 * _bgController.value),
                  left: -100 + (50 * _bgController.value),
                  child: _GlowBlob(
                      color: const Color(0xFFEC4899).withOpacity(0.10),
                      size: 420),
                ),
                Positioned(
                  top: 300 + (20 * _bgController.value),
                  right: 100 - (20 * _bgController.value),
                  child: _GlowBlob(
                      color: const Color(0xFF06B6D4).withOpacity(0.07),
                      size: 250),
                ),
              ],
            ),
          ),

          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _fetchOverviewData,
              backgroundColor: const Color(0xFF1a1a3e),
              color: const Color(0xFF6366F1),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: _TopBar(greeting: _getGreeting()),
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

                  // Management row — 4 in one row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ManagementRow(),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
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

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
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
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: Colors.white.withOpacity(0.12), width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
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
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 1)
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
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
  const _TopBar({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFEC4899)]),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF080720),
            ),
            padding: const EdgeInsets.all(2),
            child: const CircleAvatar(
              radius: 23,
              backgroundImage:
              NetworkImage('https://i.pravatar.cc/150?img=11'),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500)),
              const Text(
                'Super Admin',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5),
              ),
            ],
          ),
        ),
        _GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 18,
          shadows: [
            BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4))
          ],
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_active_outlined,
                  color: Colors.white, size: 24),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                          const Color(0xFFEC4899).withOpacity(0.6),
                          blurRadius: 6)
                    ],
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
      radius: 22,
      shadows: [
        BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6)),
        BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 1)
              ],
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
                      color: Colors.white.withOpacity(0.08),
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
                      shadows: [
                        Shadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 8)
                      ],
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (fullWidth)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: color, size: 7),
                  const SizedBox(width: 5),
                  Text('Active',
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Management row — 4 buttons in one row ──────────────────────────────────

class _ManagementRow extends StatelessWidget {
  _ManagementRow();

  final _items = const [
    _MgmtItem(
        label: 'Members',
        icon: Icons.people_alt_rounded,
        color: Color(0xFF6366F1),
        sub: 'Roster'),
    _MgmtItem(
        label: 'Teams',
        icon: Icons.hub_rounded,
        color: Color(0xFF10B981),
        sub: 'Squads'),
    _MgmtItem(
        label: 'Matches',
        icon: Icons.sports_esports_rounded,
        color: Color(0xFFF59E0B),
        sub: 'Games'),
    _MgmtItem(
        label: 'Contents',
        icon: Icons.auto_awesome_motion_rounded,
        color: Color(0xFFEC4899),
        sub: 'Media'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _items
          .map((item) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
              right: _items.last == item ? 0 : 10),
          child: _ManagementButton(item: item),
        ),
      ))
          .toList(),
    );
  }
}

class _MgmtItem {
  final String label, sub;
  final IconData icon;
  final Color color;
  const _MgmtItem(
      {required this.label,
        required this.icon,
        required this.color,
        required this.sub});
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
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: item.color.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6)),
              BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 18, horizontal: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.color.withOpacity(0.18),
                      item.color.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: item.color.withOpacity(0.35), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: item.color.withOpacity(0.35),
                              blurRadius: 14,
                              spreadRadius: 1)
                        ],
                      ),
                      child: Icon(item.icon, color: item.color, size: 22),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.sub,
                      style: TextStyle(
                          fontSize: 10,
                          color: item.color.withOpacity(0.7),
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      child: _GlassCard(
        padding: EdgeInsets.zero,
        radius: 32,
        tint: Colors.white.withOpacity(0.07),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavIcon(
                icon: Icons.grid_view_rounded,
                active: selectedIndex == 0,
                onTap: () => onTap(0)),
            _NavIcon(
                icon: Icons.analytics_outlined,
                active: selectedIndex == 1,
                onTap: () => onTap(1)),
            _NavIcon(
                icon: Icons.person_outline_rounded,
                active: selectedIndex == 2,
                onTap: () => onTap(2)),
            _NavIcon(
                icon: Icons.settings_rounded,
                active: selectedIndex == 3,
                onTap: () => onTap(3)),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon(
      {required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
        const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6366F1).withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: active
              ? [
            BoxShadow(
                color:
                const Color(0xFF6366F1).withOpacity(0.35),
                blurRadius: 14,
                spreadRadius: 1)
          ]
              : null,
        ),
        child: Icon(
          icon,
          color: active
              ? const Color(0xFF818CF8)
              : Colors.white.withOpacity(0.3),
          size: 26,
        ),
      ),
    );
  }
}