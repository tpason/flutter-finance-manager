import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:flutter_frontend/src/core/config/app_colors.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/core/services/storage_service.dart';
import 'package:flutter_frontend/src/features/auth/data/auth_service.dart';
import 'package:flutter_frontend/src/features/home/presentation/pages/home_page.dart';
import 'package:flutter_frontend/src/features/auth/presentation/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _storageService = StorageService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attachLogarteOverlayIfNeeded(context: context);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final response = await _authService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (response.success && response.token != null) {
      await _storageService.saveAuthData(
        accessToken: response.token!,
        tokenType: response.tokenType ?? 'Bearer',
        refreshToken: response.refreshToken,
      );

      Map<String, dynamic>? profile = response.user;
      final fetchedProfile =
          await _authService.fetchCurrentUser(response.token!, response.tokenType);
      if (fetchedProfile != null) {
        profile = fetchedProfile;
      } else {
        logarte.log('fetchCurrentUser returned null; using login response user=${response.user}');
      }

      if (profile != null) {
        await _storageService.saveUserProfile(profile);
      } else {
        logarte.log('No user profile available after login');
      }

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      _showToast(response.message, Colors.green);

      Navigator.of(context).pushReplacement(_buildHomeRoute(profile));
    } else {
      setState(() {
        _isLoading = false;
      });
      _showToast(response.message, Colors.red);
    }
  }

  PageRouteBuilder<dynamic> _buildHomeRoute(Map<String, dynamic>? profile) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 700),
      pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: HomePage(userData: profile),
        ),
      ),
    );
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
                  'Signing you in...',
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

  void _showToast(String message, Color color) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: color,
      textColor: Colors.white,
      gravity: ToastGravity.BOTTOM,
    );
  }

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
                  child: Column(
                    children: [
                      _buildAnimatedHeader(),
                      Expanded(
                        child: _buildAnimatedCard(),
                      ),
                    ],
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

  Widget _buildAnimatedHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Animated Logo/Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              size: 50,
              color: Colors.white,
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(delay: 200.ms, duration: 600.ms),
          
          const SizedBox(height: 24),
          
          // Animated Title
          AnimatedTextKit(
            animatedTexts: [
              TypewriterAnimatedText(
                'Welcome Back',
                textStyle: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
                speed: const Duration(milliseconds: 100),
              ),
            ],
            totalRepeatCount: 1,
          ),
          
          const SizedBox(height: 8),
          
          // Animated Subtitle
          Text(
            'Sign in to manage your finances',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w300,
            ),
          )
              .animate()
              .fadeIn(delay: 800.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, delay: 800.ms, duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40),
          topRight: Radius.circular(40),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email Field with Animation
              _buildAnimatedTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                delay: 200,
              ),
              
              const SizedBox(height: 20),
              
              // Password Field with Animation
              _buildAnimatedTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                delay: 400,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Forgot Password
              // Align(
              //   alignment: Alignment.centerRight,
              //   child: TextButton(
              //     onPressed: () {
              //       // TODO: Navigate to reset password page
              //     },
              //     child: Text(
              //       'Forgot Password?',
              //       style: TextStyle(
              //         color: AppColors.accentBlue,
              //         fontWeight: FontWeight.w500,
              //       ),
              //     ),
              //   ),
              // )
              //     .animate()
              //     .fadeIn(delay: 600.ms, duration: 400.ms),
              
              const SizedBox(height: 32),
              
              // Login Button with Animation
              _buildAnimatedButton(
                delay: 800,
              ),
              
              const SizedBox(height: 24),
              
              // Divider
              // Row(
              //   children: [
              //     Expanded(
              //       child: Divider(
              //         color: AppColors.textSecondary.withOpacity(0.3),
              //       ),
              //     ),
              //     Padding(
              //       padding: const EdgeInsets.symmetric(horizontal: 16),
              //       child: Text(
              //         'OR',
              //         style: TextStyle(
              //           color: AppColors.textSecondary,
              //           fontSize: 12,
              //         ),
              //       ),
              //     ),
              //     Expanded(
              //       child: Divider(
              //         color: AppColors.textSecondary.withOpacity(0.3),
              //       ),
              //     ),
              //   ],
              // )
              //     .animate()
              //     .fadeIn(delay: 1000.ms, duration: 400.ms),
              
              // const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 1200.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    )
        .animate()
        .slideY(
          begin: 0.3,
          end: 0,
          delay: 400.ms,
          duration: 800.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(
          delay: 400.ms,
          duration: 800.ms,
        );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int delay,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        )
            .animate()
            .fadeIn(delay: delay.ms, duration: 400.ms)
            .slideX(begin: -0.2, end: 0, delay: delay.ms, duration: 400.ms),
        
        const SizedBox(height: 8),
        
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            if (label == 'Email' && !value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.6),
            ),
            prefixIcon: Icon(icon, color: AppColors.accentBlue),
            suffixIcon: suffixIcon,
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
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        )
            .animate()
            .fadeIn(delay: (delay + 100).ms, duration: 500.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              delay: (delay + 100).ms,
              duration: 500.ms,
              curve: Curves.easeOut,
            ),
      ],
    );
  }

  Widget _buildAnimatedButton({required int delay}) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          disabledBackgroundColor: AppColors.accentBlue.withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
      ),
    )
        .animate()
        .fadeIn(delay: delay.ms, duration: 500.ms)
        .slideY(
          begin: 0.3,
          end: 0,
          delay: delay.ms,
          duration: 500.ms,
          curve: Curves.easeOut,
        )
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          delay: delay.ms,
          duration: 500.ms,
          curve: Curves.easeOut,
        );
  }
}
