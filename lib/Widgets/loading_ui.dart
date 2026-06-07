import 'package:flutter/material.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';

class Skeleton extends StatefulWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 4,
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
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.03, end: 0.08).animate(
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
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
    return TechnicalCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Skeleton(height: 40, width: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Skeleton(height: 12, width: 100),
                  const SizedBox(height: 6),
                  const Skeleton(height: 8, width: 60),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Skeleton(height: 10, width: double.infinity),
          const SizedBox(height: 8),
          const Skeleton(height: 10, width: 180),
        ],
      ),
    );
  }
}

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const TechnicalGridBackground(),
        SingleChildScrollView(
          padding: const EdgeInsets.all(kPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Skeleton(height: 44, width: 44, borderRadius: 22),
              const SizedBox(height: 24),
              const Skeleton(height: 24, width: 180),
              const SizedBox(height: 8),
              const Skeleton(height: 12, width: 120),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(child: _buildStatSkeleton()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatSkeleton()),
                ],
              ),
              const SizedBox(height: 12),
              const Skeleton(height: 100, width: double.infinity),
              const SizedBox(height: 40),
              const Skeleton(height: 16, width: 120),
              const SizedBox(height: 20),
              const SkeletonCard(),
              const SkeletonCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatSkeleton() {
    return Container(
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Skeleton(height: 14, width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 20, width: 40),
              SizedBox(height: 4),
              Skeleton(height: 8, width: 60),
            ],
          ),
        ],
      ),
    );
  }
}

class TeamsSkeleton extends StatelessWidget {
  const TeamsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MembersSkeleton();
  }
}

class CompetitionSkeleton extends StatelessWidget {
  const CompetitionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MembersSkeleton();
  }
}

class MembersSkeleton extends StatelessWidget {
  const MembersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const TechnicalGridBackground(),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: kPadding),
                child: Row(
                  children: [
                    Skeleton(height: 36, width: 36, borderRadius: 18),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(height: 10, width: 60),
                        SizedBox(height: 6),
                        Skeleton(height: 18, width: 100),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const TechnicalSectionHeader(label: 'LOADING SQUADS', color: kAccent),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: kPadding),
                child: Skeleton(height: 52, width: double.infinity),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kPadding),
                child: TechnicalCard(
                  child: Column(
                    children: List.generate(3, (index) => _buildMemberItem()),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const TechnicalSectionHeader(label: 'ARCHIVE', color: kAccent),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: kPadding),
                child: SkeletonCard(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Skeleton(height: 32, width: 32, borderRadius: 16),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 12, width: 100),
              SizedBox(height: 6),
              Skeleton(height: 8, width: 60),
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
    return Stack(
      children: [
        const TechnicalGridBackground(),
        SingleChildScrollView(
          padding: const EdgeInsets.all(kPadding),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Skeleton(height: 100, width: 100, borderRadius: 50),
              const SizedBox(height: 24),
              const Skeleton(height: 24, width: 160),
              const SizedBox(height: 8),
              const Skeleton(height: 12, width: 200),
              const SizedBox(height: 40),
              TechnicalCard(
                child: const Column(
                  children: [
                    _ProfileItemSkeleton(),
                    Divider(height: 32, color: Colors.white10),
                    _ProfileItemSkeleton(),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Skeleton(height: 52, width: double.infinity),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileItemSkeleton extends StatelessWidget {
  const _ProfileItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Skeleton(height: 36, width: 36, borderRadius: 8),
        SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 10, width: 50),
            SizedBox(height: 6),
            Skeleton(height: 12, width: 120),
          ],
        ),
      ],
    );
  }
}
