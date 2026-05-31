import 'package:flutter/material.dart';
import 'dart:ui';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0C29),
              Color(0xFF1a1a3e),
              Color(0xFF24243e),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: _TopBar(),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Text(
                    'Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: _MainNavigationGrid(),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Text(
                    'Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _StatsHorizontalScroll(),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 30, 20, 15),
                  child: Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                sliver: _RecentActivityList(),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ─── Glass Helper ──────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color tint;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = 15,
    this.tint = const Color(0x1AFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(.12), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Top Bar ───────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text('AD',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back,',
                style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              ),
              Text(
                'Admin User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        _GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 16,
          child: const Icon(Icons.notifications_outlined,
              color: Colors.white, size: 24),
        ),
      ],
    );
  }
}

// ─── Main Navigation Grid ──────────────────────────────────────────────────

class _MainNavigationGrid extends StatelessWidget {
  const _MainNavigationGrid();

  static const _items = [
    (
      label: 'Members',
      icon: Icons.group_rounded,
      color: Color(0xFF6366F1),
      count: '48 Active',
    ),
    (
      label: 'Teams',
      icon: Icons.hub_rounded,
      color: Color(0xFF10B981),
      count: '6 Registered',
    ),
    (
      label: 'Matches',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFFF59E0B),
      count: '12 Upcoming',
    ),
    (
      label: 'Contents',
      icon: Icons.article_rounded,
      color: Color(0xFFEC4899),
      count: '89 Posts',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = _items[index];
          return _NavCard(
            label: item.label,
            icon: item.icon,
            color: item.color,
            count: item.count,
          );
        },
        childCount: _items.length,
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String label, count;
  final IconData icon;
  final Color color;

  const _NavCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(.3)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats Horizontal Scroll ──────────────────────────────────────────────

class _StatsHorizontalScroll extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _StatMiniCard(
            label: 'Total Wins',
            value: '124',
            icon: Icons.emoji_events_rounded,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 15),
          _StatMiniCard(
            label: 'Events',
            value: '32',
            icon: Icons.calendar_today_rounded,
            color: Colors.lightBlueAccent,
          ),
          const SizedBox(width: 15),
          _StatMiniCard(
            label: 'Awards',
            value: '15',
            icon: Icons.military_tech_rounded,
            color: Colors.purpleAccent,
          ),
        ],
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      radius: 20,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                label,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activity List ──────────────────────────────────────────────────

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ActivityTile(index: index),
          );
        },
        childCount: 5,
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final int index;
  const _ActivityTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final titles = [
      'New member added',
      'Match results updated',
      'New content published',
      'Team Alpha created',
      'Settings updated'
    ];
    final times = [
      '2 mins ago',
      '1 hour ago',
      '3 hours ago',
      'Yesterday',
      '2 days ago'
    ];
    final colors = [
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.blueAccent,
      Colors.pinkAccent,
      Colors.grey
    ];

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors[index % colors.length],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[index % titles.length],
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
                Text(
                  times[index % times.length],
                  style: TextStyle(
                      color: Colors.white.withOpacity(.4), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(.3)),
        ],
      ),
    );
  }
}

// ─── Bottom Navigation ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _BottomNav({required this.selectedIndex, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 30),
      height: 75,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _GlassCard(
        padding: EdgeInsets.zero,
        radius: 28,
        tint: Colors.white.withOpacity(.08),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.grid_view_rounded,
              active: selectedIndex == 0,
              onTap: () => onItemTapped(0),
            ),
            _NavButton(
              icon: Icons.analytics_outlined,
              active: selectedIndex == 1,
              onTap: () => onItemTapped(1),
            ),
            _NavButton(
              icon: Icons.person_outline_rounded,
              active: selectedIndex == 2,
              onTap: () => onItemTapped(2),
            ),
            _NavButton(
              icon: Icons.settings_outlined,
              active: selectedIndex == 3,
              onTap: () => onItemTapped(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
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
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFF818CF8) : Colors.white.withOpacity(.4),
          size: 26,
        ),
      ),
    );
  }
}
