import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qcurobotics_management_app/Pages/Auth/login_page.dart';
import 'package:qcurobotics_management_app/Pages/Dashboard/Dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Pages/Auth/register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        canvasColor: const Color(0xFF0B1020),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Key _futureKey = UniqueKey();

  void _refreshProfile() {
    setState(() {
      _futureKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          debugPrint('🔑 AuthGate: Session detected for ${session.user.email}');
          return FutureBuilder(
            key: _futureKey,
            future: Supabase.instance.client
                .from('user_accounts')
                .select()
                .eq('id', session.user.id)
                .maybeSingle(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final profile = profileSnapshot.data;
              debugPrint('👤 AuthGate: Profile data: $profile');

              // If profile is missing or position is null, go to RegisterPage
              if (profile == null || profile['position'] == null) {
                debugPrint('⚠️ AuthGate: Profile incomplete, showing RegisterPage');
                return RegisterPage(
                  initialEmail: session.user.email,
                  initialName: session.user.userMetadata?['full_name'],
                  initialImageUrl: session.user.userMetadata?['avatar_url'],
                  isGoogleSignUp: true,
                  onProfileComplete: _refreshProfile,
                );
              }

              debugPrint('✅ AuthGate: Profile complete, showing Dashboard');
              return const Dashboard();
            },
          );
        }

        debugPrint('🚪 AuthGate: No session, showing LoginPage');
        return const LoginPage();
      },
    );
  }
}