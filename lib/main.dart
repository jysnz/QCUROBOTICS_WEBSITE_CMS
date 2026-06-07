import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:qcurobotics_management_app/Pages/Auth/login_page.dart';
import 'package:qcurobotics_management_app/Pages/Auth/register_page.dart';
import 'package:qcurobotics_management_app/Pages/Auth/welcome_page.dart';
import 'package:qcurobotics_management_app/Pages/Dashboard/dashboard.dart';
import 'package:qcurobotics_management_app/Widgets/loading_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    await dotenv.load(fileName: ".env").catchError((e) {
      debugPrint("Warning: Could not load .env file: $e");
    });

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception("SUPABASE_URL or SUPABASE_ANON_KEY missing in .env");
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    runApp(const MyApp());
  } catch (e) {
    debugPrint("CRITICAL INITIALIZATION ERROR: $e");
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Initialization Error:\n$e",
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QCU Robotics CMS',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617), // kBackground
        canvasColor: const Color(0xFF020617),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22C55E), // kAccent
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B), // kSurface
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(letterSpacing: -1.0, fontWeight: FontWeight.w900),
          headlineMedium: TextStyle(letterSpacing: 1.0, fontWeight: FontWeight.w800),
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
            backgroundColor: Color(0xFF020617),
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
