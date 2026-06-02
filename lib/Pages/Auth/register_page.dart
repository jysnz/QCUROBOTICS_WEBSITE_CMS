import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qcurobotics_management_app/Pages/Auth/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  String _selectedPosition = 'Media';
  final List<String> _positions = ['Media', 'Member', 'Team Player'];
  
  int? _selectedTeamId;
  List<Map<String, dynamic>> _teams = [];
  bool _isLoadingTeams = false;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    setState(() => _isLoadingTeams = true);
    try {
      final data = await Supabase.instance.client.from('teams').select('id, team_name');
      setState(() {
        _teams = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching teams: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    if (_selectedPosition == 'Team Player' && _selectedTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a team')));
      return;
    }

    setState(() => _isRegistering = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'position': _selectedPosition,
          if (_selectedPosition == 'Team Player' && _selectedTeamId != null)
            'team_id': _selectedTeamId,
        }
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please check your email or login.')),
        );
        Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unexpected error occurred')));
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join the QCU Robotics team',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AuthGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          
                          // Position Dropdown
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: ButtonTheme(
                                alignedDropdown: true,
                                child: DropdownButton<String>(
                                  value: _selectedPosition,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF111827),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6366F1)),
                                  style: const TextStyle(color: Colors.white, fontSize: 15),
                                  items: _positions.map((String position) {
                                    return DropdownMenuItem<String>(
                                      value: position,
                                      child: Text(position),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedPosition = newValue;
                                        if (_selectedPosition != 'Team Player') {
                                          _selectedTeamId = null;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          
                          if (_selectedPosition == 'Team Player') ...[
                            const SizedBox(height: 16),
                            if (_isLoadingTeams)
                              const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: ButtonTheme(
                                    alignedDropdown: true,
                                    child: DropdownButton<int>(
                                      value: _selectedTeamId,
                                      isExpanded: true,
                                      hint: Text('Select Team', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                                      dropdownColor: const Color(0xFF111827),
                                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6366F1)),
                                      style: const TextStyle(color: Colors.white, fontSize: 15),
                                      items: _teams.map((team) {
                                        return DropdownMenuItem<int>(
                                          value: team['id'] as int,
                                          child: Text(team['team_name'] as String),
                                        );
                                      }).toList(),
                                      onChanged: (int? newValue) {
                                        setState(() {
                                          _selectedTeamId = newValue;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 32),
                          AuthButton(
                            label: 'Register',
                            onPressed: _register,
                            isLoading: _isRegistering,
                            color: const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
