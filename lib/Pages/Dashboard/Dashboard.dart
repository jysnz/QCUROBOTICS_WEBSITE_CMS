import 'package:flutter/material.dart';
import 'package:qcurobotics_management_app/Pages/Members/members.dart';
import 'package:qcurobotics_management_app/Pages/Profile/profile_page.dart';
import 'package:qcurobotics_management_app/Pages/Teams/teams.dart';
import 'package:qcurobotics_management_app/Pages/Tournaments/tournaments.dart';
import 'package:qcurobotics_management_app/Services/cache_service.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
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

  Map<String, dynamic> toMap() {
    return {
      'totalMembers': totalMembers,
      'totalTournaments': totalTournaments,
      'totalAchievements': totalAchievements,
      'totalSponsors': totalSponsors,
      'totalTeams': totalTeams,
    };
  }

  factory _DashboardOverviewData.fromMap(Map<String, dynamic> map) {
    return _DashboardOverviewData(
      totalMembers: map['totalMembers'] ?? 0,
      totalTournaments: map['totalTournaments'] ?? 0,
      totalAchievements: map['totalAchievements'] ?? 0,
      totalSponsors: map['totalSponsors'] ?? 0,
      totalTeams: map['totalTeams'] ?? 0,
    );
  }
}

class _DashboardState extends State<Dashboard> {
  static const Duration _overviewCacheDuration = Duration(minutes: 30);
  static const String _overviewCacheKey = 'dashboard_overview_data';
  
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;
  final _cache = CacheService();

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

    final cachedMap = await _cache.getData(_overviewCacheKey);
    if (cachedMap != null) {
      final cachedData = _DashboardOverviewData.fromMap(cachedMap);
      if (mounted) {
        setState(() => _applyOverviewData(cachedData, loading: false));
      }
      
      final freshCachedMap = await _cache.getData(_overviewCacheKey, maxAge: _overviewCacheDuration);
      if (!forceRefresh && freshCachedMap != null) {
        return;
      }
    }

    await _fetchOverviewData();
  }

  Future<void> _fetchOverviewData() async {
    if (!mounted) return;
    
    try {
      final results = await Future.wait([
        _supabase.from('team_members').count(),
        _supabase.from('media_team').count(),
        _supabase.from('members').count(),
        _supabase.from('competitions').count(),
        _supabase.from('Achievements').count(),
        _supabase.from('sponsors').count(),
        _supabase.from('teams').count().eq('is_active', true),
      ]);

      if (mounted) {
        final overviewData = _DashboardOverviewData(
          totalMembers: results[0] + results[1] + results[2],
          totalTournaments: results[3],
          totalAchievements: results[4],
          totalSponsors: results[5],
          totalTeams: results[6],
        );

        await _cache.saveData(_overviewCacheKey, overviewData.toMap());

        setState(() {
          _applyOverviewData(overviewData, loading: false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const TechnicalGridBackground(),
          
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => _loadOverviewData(forceRefresh: true),
              backgroundColor: kSurface,
              color: kAccent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(kPadding),
                      child: _TopBar(
                        greeting: _getGreeting(),
                        userName: _supabase.auth.currentUser?.userMetadata?['full_name'],
                        photoUrl: _supabase.auth.currentUser?.userMetadata?['avatar_url'],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: TechnicalSectionHeader(
                      label: 'Overview',
                      color: kAccent,
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: kPadding),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.4,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final stats = [
                            _StatCardData(
                              title: 'TOTAL MEMBERS',
                              value: _totalMembers.toString(),
                              icon: Icons.people_outline,
                              color: const Color(0xFF6366F1),
                            ),
                            _StatCardData(
                              title: 'TOURNAMENTS',
                              value: _totalTournaments.toString(),
                              icon: Icons.emoji_events_outlined,
                              color: const Color(0xFFF59E0B),
                            ),
                            _StatCardData(
                              title: 'ACHIEVEMENTS',
                              value: _totalAchievements.toString(),
                              icon: Icons.military_tech_outlined,
                              color: const Color(0xFF10B981),
                            ),
                            _StatCardData(
                              title: 'SPONSORS',
                              value: _totalSponsors.toString(),
                              icon: Icons.business_outlined,
                              color: const Color(0xFFEC4899),
                            ),
                          ];
                          final data = stats[index];
                          return _StatCard(
                            title: data.title,
                            value: data.value,
                            icon: data.icon,
                            color: data.color,
                            isLoading: _isLoading,
                          );
                        },
                        childCount: 4,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(kPadding, 10, kPadding, 0),
                      child: SizedBox(
                        height: 100,
                        child: _StatCard(
                          title: 'ACTIVE TEAMS',
                          value: _totalTeams.toString(),
                          icon: Icons.hub_outlined,
                          color: const Color(0xFF06B6D4),
                          isLoading: _isLoading,
                          fullWidth: true,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: TechnicalSectionHeader(
                      label: 'Management',
                      color: kAccent,
                      topPadding: 24,
                    ),
                  ),

                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: kPadding),
                    sliver: _ManagementList(),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _FloatingGlassNav(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── Dashboard Sub-Widgets ───────────────────────────────────────────────────

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
    final firstName = (userName ?? 'ADMIN').split(' ').first.toUpperCase();

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kAccent.withValues(alpha: 0.3)),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: kSurface,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null ? const Icon(Icons.person_outline, color: Colors.white, size: 18) : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                firstName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        _IconButton(
          icon: Icons.notifications_none_outlined,
          onTap: () {},
          hasNotification: true,
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool hasNotification;

  const _IconButton({required this.icon, required this.onTap, this.hasNotification = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kSurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
            if (hasNotification)
              Positioned(
                top: -1,
                right: -1,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
    return TechnicalCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color.withValues(alpha: 0.8), size: 14),
              if (fullWidth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoading)
                const Skeleton(height: 20, width: 40)
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagementList extends StatelessWidget {
  const _ManagementList();

  final _items = const [
    _MgmtItem(label: 'MEMBERS', icon: Icons.people_outline, color: Color(0xFF6366F1), destination: Members()),
    _MgmtItem(label: 'TEAMS', icon: Icons.hub_outlined, color: Color(0xFF10B981), destination: Teams()),
    _MgmtItem(label: 'TOURNAMENTS', icon: Icons.sports_esports_outlined, color: Color(0xFFF59E0B), destination: Tournaments()),
    _MgmtItem(label: 'CONTENTS', icon: Icons.folder_open_outlined, color: Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ManagementButton(item: _items[index]),
          );
        },
        childCount: _items.length,
      ),
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
        if (item.destination != null) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.destination!));
        }
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _pressed ? kSurface.withValues(alpha: 0.6) : kSurface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.1), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingGlassNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _FloatingGlassNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      height: 64,
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(icon: Icons.grid_view_outlined, active: selectedIndex == 0, onTap: () => onTap(0)),
          _NavIcon(icon: Icons.bar_chart_outlined, active: selectedIndex == 1, onTap: () => onTap(1)),
          _NavIcon(icon: Icons.person_outline, active: selectedIndex == 2, onTap: () => onTap(2)),
          _NavIcon(icon: Icons.settings_outlined, active: selectedIndex == 3, onTap: () => onTap(3)),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavIcon({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? kAccent.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: active ? kAccent : Colors.white.withValues(alpha: 0.4),
              size: 22,
            ),
          ),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: kAccent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
