import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qcurobotics_management_app/Widgets/design_system.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not Authorized')));

    final fullName = user.userMetadata?['full_name'] ?? 'Admin';
    final photoUrl = user.userMetadata?['avatar_url'];

    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const TechnicalGridBackground(),
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(kPadding),
                  child: Row(
                    children: [
                      _IconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Avatar
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kAccent.withValues(alpha: 0.3)),
                          ),
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: kSurface,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null ? const Icon(Icons.person_outline, size: 40, color: Colors.white24) : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          fullName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? 'No Email',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 48),

                        const TechnicalSectionHeader(label: 'Account Information', color: kAccent, topPadding: 0),
                        
                        TechnicalCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProfileInfoItem(
                                label: 'Full Name',
                                value: fullName,
                                icon: Icons.badge_outlined,
                              ),
                              const Divider(height: 32, color: Colors.white10),
                              _ProfileInfoItem(
                                label: 'Email',
                                value: user.email ?? 'N/A',
                                icon: Icons.alternate_email_rounded,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 48),

                        TechnicalButton(
                          label: 'Logout',
                          color: const Color(0xFFF87171),
                          onTap: () async {
                            try {
                              await GoogleSignIn().signOut();
                            } catch (e) {
                              debugPrint('Google sign out error: $e');
                            }
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          icon: Icons.power_settings_new_rounded,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
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

class _ProfileInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kBackground.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kAccent.withValues(alpha: 0.7), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.3),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
