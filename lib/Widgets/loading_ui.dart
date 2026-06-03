import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.05, end: 0.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Skeleton(height: 50, width: 50, borderRadius: 25),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(height: 16, width: 120),
                  const SizedBox(height: 8),
                  const Skeleton(height: 12, width: 80),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Skeleton(height: 14, width: double.infinity),
          const SizedBox(height: 8),
          const Skeleton(height: 14, width: double.infinity),
          const SizedBox(height: 8),
          const Skeleton(height: 14, width: 200),
        ],
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) => const SkeletonCard(),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Skeleton(height: 32, width: 200),
          const SizedBox(height: 8),
          const Skeleton(height: 16, width: 150),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(child: _buildStatSkeleton()),
              const SizedBox(width: 16),
              Expanded(child: _buildStatSkeleton()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatSkeleton()),
              const SizedBox(width: 16),
              Expanded(child: _buildStatSkeleton()),
            ],
          ),
          const SizedBox(height: 40),
          const Skeleton(height: 24, width: 120),
          const SizedBox(height: 20),
          const SkeletonCard(),
          const SkeletonCard(),
          const SkeletonCard(),
        ],
      ),
    );
  }

  Widget _buildStatSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 24, width: 24, borderRadius: 8),
          SizedBox(height: 16),
          Skeleton(height: 28, width: 60),
          SizedBox(height: 8),
          Skeleton(height: 12, width: 80),
        ],
      ),
    );
  }
}

class MembersSkeleton extends StatelessWidget {
  const MembersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Skeleton(height: 44, width: 44, borderRadius: 16),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 12, width: 80),
                    SizedBox(height: 8),
                    Skeleton(height: 24, width: 120),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // Section header skeleton
          _buildSectionHeader(),
          
          // Season selector skeleton
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Skeleton(height: 60, width: double.infinity, borderRadius: 18),
          ),
          const SizedBox(height: 20),
          
          // Season panel skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Skeleton(height: 20, width: 20),
                      SizedBox(width: 12),
                      Skeleton(height: 20, width: 150),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildMemberItem(),
                  _buildMemberItem(),
                  _buildMemberItem(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          _buildSectionHeader(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonCard(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          Skeleton(height: 22, width: 4, borderRadius: 10),
          SizedBox(width: 12),
          Skeleton(height: 24, width: 140),
        ],
      ),
    );
  }

  Widget _buildMemberItem() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Skeleton(height: 42, width: 42, borderRadius: 21),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 14, width: 120),
              SizedBox(height: 8),
              Skeleton(height: 10, width: 80),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Skeleton(height: 120, width: 120, borderRadius: 60),
          const SizedBox(height: 24),
          const Skeleton(height: 28, width: 180),
          const SizedBox(height: 8),
          const Skeleton(height: 16, width: 220),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Column(
              children: [
                _ProfileItemSkeleton(),
                Divider(height: 32, color: Colors.white10),
                _ProfileItemSkeleton(),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Skeleton(height: 56, width: double.infinity, borderRadius: 16),
        ],
      ),
    );
  }
}

class _ProfileItemSkeleton extends StatelessWidget {
  const _ProfileItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Skeleton(height: 42, width: 42, borderRadius: 12),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 12, width: 60),
            SizedBox(height: 8),
            Skeleton(height: 14, width: 140),
          ],
        ),
      ],
    );
  }
}

class SkeletonHeader extends StatelessWidget {
  final double width;
  const SkeletonHeader({super.key, this.width = 150});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          const Skeleton(height: 22, width: 4, borderRadius: 10),
          const SizedBox(width: 12),
          Skeleton(height: 24, width: width),
        ],
      ),
    );
  }
}
