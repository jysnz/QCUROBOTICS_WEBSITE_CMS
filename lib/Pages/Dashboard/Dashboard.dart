import 'package:flutter/material.dart';
import 'dart:ui';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF0D0B26),
      body: Stack(
        children: [
          // Dynamic Animated Background Blobs
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (20 * _bgController.value),
                    right: -50 - (30 * _bgController.value),
                    child: _BlurBlob(color: const Color(0xFF6366F1).withOpacity(0.15), size: 350),
                  ),
                  Positioned(
                    bottom: 150 - (40 * _bgController.value),
                    left: -120 + (50 * _bgController.value),
                    child: _BlurBlob(color: const Color(0xFFEC4899).withOpacity(0.1), size: 450),
                  ),
                  Positioned(
                    top: 300 + (60 * _bgController.value),
                    left: 100 - (20 * _bgController.value),
                    child: _BlurBlob(color: const Color(0xFF10B981).withOpacity(0.05), size: 300),
                  ),
                ],
              );
            },
          ),
          
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // --- Top Profile & Header ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                    child: _EnhancedTopBar(greeting: _getGreeting()),
                  ),
                ),

                // --- Management Section Header ---
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 25, 24, 15),
                    child: Row(
                      children: [
                        _SectionIndicator(),
                        SizedBox(width: 10),
                        Text(
                          'Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Management Grid ---
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: _ManagementGrid(),
                ),

                // --- Recent Activity Header ---
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 35, 24, 15),
                    child: Row(
                      children: [
                        _SectionIndicator(color: Color(0xFFEC4899)),
                        SizedBox(width: 10),
                        Text(
                          'Recent Activity',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Activity List ---
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: _EnhancedActivityList(),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 140),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ModernBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _SectionIndicator extends StatelessWidget {
  final Color color;
  const _SectionIndicator({this.color = const Color(0xFF6366F1)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─── Refined Glass Helper ──────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool border;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tint,
    this.border = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? Colors.white.withOpacity(.06),
            borderRadius: BorderRadius.circular(radius),
            border: border ? Border.all(color: Colors.white.withOpacity(.12), width: 1) : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.04),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Header Section ────────────────────────────────────────────────────────

class _EnhancedTopBar extends StatelessWidget {
  final String greeting;
  const _EnhancedTopBar({required this.greeting});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                ),
              ),
              child: const CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=32'),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0D0B26), width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(fontSize: 13, color: Colors.white54, fontWeight: FontWeight.w500),
              ),
              const Text(
                'Admin Dashboard',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        _GlassCard(
          padding: const EdgeInsets.all(12),
          radius: 18,
          child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 24),
        ),
      ],
    );
  }
}

// ─── Management Grid ───────────────────────────────────────────────────────

class _ManagementGrid extends StatelessWidget {
  const _ManagementGrid();

  static const _items = [
    (label: 'Members', icon: Icons.people_alt_rounded, color: Color(0xFF6366F1), sub: '48 Active'),
    (label: 'Teams', icon: Icons.hub_rounded, color: Color(0xFF10B981), sub: '12 Squads'),
    (label: 'Matches', icon: Icons.sports_esports_rounded, color: Color(0xFFF59E0B), sub: '8 Today'),
    (label: 'Contents', icon: Icons.auto_awesome_motion_rounded, color: Color(0xFFEC4899), sub: '124 Items'),
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
          return _InteractiveNavCard(item: item);
        },
        childCount: _items.length,
      ),
    );
  }
}

class _InteractiveNavCard extends StatefulWidget {
  final dynamic item;
  const _InteractiveNavCard({required this.item});

  @override
  State<_InteractiveNavCard> createState() => _InteractiveNavCardState();
}

class _InteractiveNavCardState extends State<_InteractiveNavCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: _GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.item.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.item.color.withOpacity(.3)),
                  boxShadow: [
                    BoxShadow(color: widget.item.color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Icon(widget.item.icon, color: widget.item.color, size: 28),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.label,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.sub,
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(.4), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recent Activity Section ───────────────────────────────────────────────

class _EnhancedActivityList extends StatelessWidget {
  const _EnhancedActivityList();

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _EnhancedActivityTile(index: index),
          );
        },
        childCount: 4,
      ),
    );
  }
}

class _EnhancedActivityTile extends StatelessWidget {
  final int index;
  const _EnhancedActivityTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final activities = [
      (title: 'New Member', desc: 'Satoshi Nakamoto joined Robotics Team', time: '12m ago', icon: Icons.person_add_rounded, color: Color(0xFF6366F1)),
      (title: 'Match Result', desc: 'Team Phoenix won against CyberDragons', time: '45m ago', icon: Icons.military_tech_rounded, color: Color(0xFFF59E0B)),
      (title: 'New Post', desc: 'Admin published "Season 5 Updates"', time: '2h ago', icon: Icons.edit_note_rounded, color: Color(0xFFEC4899)),
      (title: 'System Alert', desc: 'Database backup completed successfully', time: '5h ago', icon: Icons.verified_user_rounded, color: Color(0xFF10B981)),
    ];

    final act = activities[index % activities.length];

    return _GlassCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [act.color.withOpacity(0.2), act.color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(act.icon, color: act.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(act.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(
                  act.desc,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(act.time, style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Modern Bottom Navigation ──────────────────────────────────────────────

class _ModernBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const _ModernBottomNav({required this.selectedIndex, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 80,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.5),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: _GlassCard(
        padding: EdgeInsets.zero,
        radius: 30,
        tint: Colors.white.withOpacity(.08),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ModernNavIcon(icon: Icons.grid_view_rounded, active: selectedIndex == 0, onTap: () => onItemTapped(0)),
            _ModernNavIcon(icon: Icons.analytics_outlined, active: selectedIndex == 1, onTap: () => onItemTapped(1)),
            _ModernNavIcon(icon: Icons.person_outline_rounded, active: selectedIndex == 2, onTap: () => onItemTapped(2)),
            _ModernNavIcon(icon: Icons.settings_rounded, active: selectedIndex == 3, onTap: () => onItemTapped(3)),
          ],
        ),
      ),
    );
  }
}

class _ModernNavIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModernNavIcon({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF818CF8) : Colors.white.withOpacity(.3),
              size: 28,
            ),
            if (active) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Color(0xFF818CF8), shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
