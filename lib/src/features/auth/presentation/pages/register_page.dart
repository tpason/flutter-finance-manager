import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:flutter_frontend/src/core/config/app_colors.dart';
import 'package:flutter_frontend/src/features/auth/data/auth_service.dart';
import 'package:flutter_frontend/src/features/auth/presentation/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _limitAmountController = TextEditingController(text: '2000000');
  final _authService = AuthService();
  final NumberFormat _vndNumberFormat = NumberFormat.decimalPattern('vi_VN');

  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
    _limitAmountController.addListener(_onLimitAmountChanged);
    _onLimitAmountChanged();
  }

  void _onLimitAmountChanged() {
    final raw = _limitAmountController.text;
    final digits = _digitsOnly(raw);
    final formatted = digits.isEmpty ? '' : _vndNumberFormat.format(int.parse(digits));

    if (raw != formatted) {
      _limitAmountController
        ..removeListener(_onLimitAmountChanged)
        ..text = formatted
        ..selection = TextSelection.collapsed(offset: formatted.length)
        ..addListener(_onLimitAmountChanged);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _limitAmountController
      ..removeListener(_onLimitAmountChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final limitAmount = int.tryParse(_digitsOnly(_limitAmountController.text));
    if (limitAmount == null || limitAmount <= 0) {
      _showToast('Limit amount must be a positive number', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await _authService.register(
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      password: _passwordController.text,
      limitAmount: limitAmount,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (response.success) {
      _showToast(response.message, Colors.green);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      _showToast(response.message, Colors.red);
    }
  }

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: color,
      textColor: Colors.white,
      gravity: ToastGravity.BOTTOM,
    );
  }

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.bgWarm,
                  AppColors.primaryDark,
                ],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.person_add_alt_1,
            size: 46,
            color: Colors.white,
          ),
        )
            .animate()
            .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut)
            .fadeIn(delay: 200.ms, duration: 500.ms),
        const SizedBox(height: 16),
        const Text(
          'Create Account',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Register to start managing your finance',
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              delay: 200,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Enter your username',
              icon: Icons.account_circle_outlined,
              delay: 300,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _fullNameController,
              label: 'Full name',
              hint: 'Enter your full name',
              icon: Icons.badge_outlined,
              delay: 400,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Create a password',
              icon: Icons.lock_outline,
              obscureText: true,
              delay: 500,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _limitAmountController,
              label: 'Limit amount',
              hint: 'Monthly limit amount',
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
              inputFormatters: const [],
              trailing: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: AppColors.accentBlue,
                ),
              ),
              delay: 600,
            ),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text('Already have an account? Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int delay,
    Widget? trailing,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        )
            .animate()
            .fadeIn(delay: delay.ms, duration: 300.ms)
            .slideX(begin: -0.2, end: 0, delay: delay.ms, duration: 300.ms),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            if (label == 'Email' && !value.contains('@')) {
              return 'Please enter a valid email';
            }
            if (label == 'Password' && value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            if (label == 'Limit amount') {
              final amount = int.tryParse(_digitsOnly(value));
              if (amount == null || amount <= 0) {
                return 'Limit amount must be a positive number';
              }
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
            prefixIcon: Icon(icon, color: AppColors.accentBlue),
            suffixIcon: trailing,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.accentBlue,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
        ),
        onPressed: _isLoading ? null : _handleRegister,
        child: const Text(
          'Create Account',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 550.ms, duration: 400.ms);
  }

  Widget _buildLoadingOverlay() {
    return AnimatedOpacity(
      opacity: _isLoading ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.25),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SpinKitChasingDots(
                  color: AppColors.accentBlue,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Creating account...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
