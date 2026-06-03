import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qcurobotics_management_app/Pages/Auth/auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialName;
  final String? initialImageUrl;
  final bool isGoogleSignUp;
  final VoidCallback? onProfileComplete;
  final VoidCallback? onRegistrationSuccess;

  const RegisterPage({
    super.key,
    this.initialEmail,
    this.initialName,
    this.initialImageUrl,
    this.isGoogleSignUp = false,
    this.onProfileComplete,
    this.onRegistrationSuccess,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _nameController;
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  String _selectedPosition = 'Media';
  final List<String> _positions = ['Media', 'Member', 'Team Player'];
  
  int? _selectedTeamId;
  List<Map<String, dynamic>> _teams = [];
  bool _isLoadingTeams = false;
  bool _isRegistering = false;

  // Password validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _nameController = TextEditingController(text: widget.initialName);
    
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
    _fetchTeams();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid =>
      _hasMinLength && _hasUppercase && _hasNumber && _hasSpecialChar;

  void _validateConfirmPassword() {
    setState(() {
      _passwordsMatch = _confirmPasswordController.text == _passwordController.text;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
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

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Registration Successful!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account has been created. Welcome to the QCU Robotics team!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showErrorDialog(String message) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Registration Error', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _register() async {
    debugPrint('🚀 Starting registration process...');
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      debugPrint('❌ Validation failed: Missing fields');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    if (!_isPasswordValid) {
      debugPrint('❌ Validation failed: Weak password');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please meet all password requirements')));
      return;
    }

    if (!_passwordsMatch) {
      debugPrint('❌ Validation failed: Passwords do not match');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    if (_selectedPosition == 'Team Player' && _selectedTeamId == null) {
      debugPrint('❌ Validation failed: Team Player selected but no team_id');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a team')));
      return;
    }

    setState(() => _isRegistering = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null || widget.isGoogleSignUp) {
        debugPrint('🔄 Mode: Complete Profile / Google User');
        final targetUser = user ?? supabase.auth.currentUser;
        
        if (targetUser != null) {
          debugPrint('👤 Target User ID: ${targetUser.id}');
          
          if (_passwordController.text.isNotEmpty) {
            debugPrint('🔑 Updating password...');
            await supabase.auth.updateUser(
              UserAttributes(password: _passwordController.text.trim()),
            );
            debugPrint('✅ Password updated');
          }

          debugPrint('💾 Upserting to user_accounts...');
          await supabase.from('user_accounts').upsert({
            'id': targetUser.id,
            'email': _emailController.text.trim(),
            'full_name': _nameController.text.trim(),
            'position': _selectedPosition,
            'team_id': _selectedTeamId,
          });
          debugPrint('✅ user_accounts upsert successful');
        } else {
          debugPrint('❌ Error: No authenticated user found during profile completion');
          throw 'No authenticated user found. Please try logging in again.';
        }
      } else {
        debugPrint('🆕 Mode: Initial Email/Password Sign Up');
        debugPrint('📧 Email: ${_emailController.text.trim()}');
        
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'full_name': _nameController.text.trim(),
            'position': _selectedPosition,
            if (_selectedPosition == 'Team Player' && _selectedTeamId != null)
              'team_id': _selectedTeamId,
          }
        );

        debugPrint('✅ Auth signUp call complete');
        if (response.session == null) {
          debugPrint('ℹ️ Session is null (Email confirmation likely required)');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created! Please confirm your email.')),
            );
            Navigator.of(context).pop();
            return;
          }
        } else {
          debugPrint('✅ Session established immediately');
        }
      }
      
      if (mounted) {
        debugPrint('🎉 Registration/Profile Save Finished Successfully');
        setState(() => _isRegistering = false);
        await _showSuccessDialog();
        if (!mounted) return;
        if (widget.isGoogleSignUp) {
          widget.onProfileComplete?.call();
        } else {
          widget.onRegistrationSuccess?.call();
        }
      }
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message} (Status: ${e.statusCode})');
      if (mounted) {
        setState(() => _isRegistering = false);
        _showErrorDialog('Authentication error: ${e.message}');
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgrestException: ${e.message} (Code: ${e.code})');
      if (mounted) {
        setState(() => _isRegistering = false);
        _showErrorDialog('Database error: ${e.message}');
      }
    } catch (e) {
      debugPrint('❌ Unexpected Error: $e');
      if (mounted) {
        setState(() => _isRegistering = false);
        _showErrorDialog('An unexpected error occurred: $e');
      }
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
        leading: widget.isGoogleSignUp 
          ? IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
              onPressed: () async {
                try {
                  await GoogleSignIn().signOut();
                } catch (e) {
                  debugPrint('Google sign out error: $e');
                }
                await Supabase.instance.client.auth.signOut();
              },
              tooltip: 'Logout',
            )
          : IconButton(
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
                    Text(
                      widget.isGoogleSignUp ? 'Complete Profile' : 'Create Account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isGoogleSignUp 
                        ? 'Finish setting up your account' 
                        : 'Join the QCU Robotics team',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Profile Image Placeholder
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF1F2937),
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!)
                                    : (widget.initialImageUrl != null
                                        ? NetworkImage(widget.initialImageUrl!)
                                        : null),
                                child: (_imageFile == null && widget.initialImageUrl == null)
                                    ? const Icon(Icons.person_rounded, size: 50, color: Colors.white24)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6366F1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AuthGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !widget.isGoogleSignUp,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 16),
                          AuthTextField(
                            controller: _passwordController,
                            label: widget.isGoogleSignUp ? 'Set Password' : 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          
                          // Password Requirements Checklist
                          _PasswordRequirement(
                            label: 'At least 8 characters',
                            isValid: _hasMinLength,
                          ),
                          _PasswordRequirement(
                            label: 'One uppercase letter',
                            isValid: _hasUppercase,
                          ),
                          _PasswordRequirement(
                            label: 'One number',
                            isValid: _hasNumber,
                          ),
                          _PasswordRequirement(
                            label: 'One special character',
                            isValid: _hasSpecialChar,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Confirm Password TextField
                          AuthTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                          if (_confirmPasswordController.text.isNotEmpty && !_passwordsMatch)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 14, color: Colors.red.withValues(alpha: 0.8)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Passwords do not match',
                                    style: TextStyle(
                                      color: Colors.red.withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Position Header
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Position',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
                            // Team Header
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Select Team',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
                            label: widget.isGoogleSignUp ? 'Save Profile' : 'Register',
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

class _PasswordRequirement extends StatelessWidget {
  final String label;
  final bool isValid;

  const _PasswordRequirement({
    required this.label,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 14,
            color: isValid ? const Color(0xFF10B981) : Colors.white24,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.white70 : Colors.white38,
              fontWeight: isValid ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
