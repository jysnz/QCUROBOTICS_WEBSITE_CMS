import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qcurobotics_management_app/Pages/Auth/login_page.dart';
import 'package:qcurobotics_management_app/Pages/Auth/register_page.dart';
import 'package:qcurobotics_management_app/Pages/Auth/welcome_page.dart';
import 'package:qcurobotics_management_app/Pages/Dashboard/Dashboard.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
  bool _showWelcome = false;
  bool _showRegisterForm = false;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {});
    });
  }

  void _refresh() {
    setState(() {
      _futureKey = UniqueKey();
    });
  }

  void _onRegistrationComplete() {
    _showWelcome = true;
    _showRegisterForm = false;
    _refresh();
  }

  void _dismissWelcome() {
    setState(() {
      _showWelcome = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (_showRegisterForm) {
        return RegisterPage(
          onRegistrationSuccess: _onRegistrationComplete,
        );
      }
      return LoginPage(
        onRegister: () {
          _showRegisterForm = true;
          setState(() {});
        },
      );
    }

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
            backgroundColor: Color(0xFF0B1020),
            body: DashboardSkeleton(),
          );
        }

        final profile = profileSnapshot.data;

        if (profile == null || profile['position'] == null) {
          return RegisterPage(
            initialEmail: session.user.email,
            initialName: session.user.userMetadata?['full_name'],
            initialImageUrl: session.user.userMetadata?['avatar_url'],
            isGoogleSignUp: true,
            onProfileComplete: _onRegistrationComplete,
          );
        }

        if (_showWelcome) {
          return WelcomePage(onGoToDashboard: _dismissWelcome);
        }

        return const Dashboard();
      },
    );
  }
}
