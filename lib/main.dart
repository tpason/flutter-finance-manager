import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logarte/logarte.dart';

import 'package:flutter_frontend/src/core/config/app_theme.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_frontend/src/features/home/presentation/pages/home_page.dart';
import 'package:flutter_frontend/src/core/services/storage_service.dart';
import 'package:flutter_frontend/src/features/auth/data/auth_service.dart';
import 'package:flutter_frontend/src/core/services/master_data_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const RootApp());
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinancialApp();
  }
}

class FinancialApp extends StatelessWidget {
  const FinancialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Financial Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: logarteNavigatorKey,
      navigatorObservers: [
        LogarteNavigatorObserver(logarte),
      ],
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
  late final StorageService _storageService;
  late final AuthService _authService;
  late Future<_SessionResult> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _authService = AuthService();
    _sessionFuture = _checkSession();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attachLogarteOverlayIfNeeded(context: context);
    });
  }

  Future<_SessionResult> _checkSession() async {
    final token = await _storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return const _SessionResult(authenticated: false);
    }

    // Try current token
    final profile = await _authService.fetchCurrentUser();
    if (profile != null) {
      _kickoffMasterData();
      return _SessionResult(authenticated: true, profile: profile);
    }

    // Attempt refresh once
    final refresh = await _authService.refreshToken();
    if (refresh.success && refresh.token != null) {
      await _storageService.saveAuthData(
        accessToken: refresh.token!,
        tokenType: refresh.tokenType ?? 'Bearer',
        refreshToken: refresh.refreshToken,
      );

      final refreshedProfile = await _authService.fetchCurrentUser(
        refresh.token,
        refresh.tokenType,
      );
      if (refreshedProfile != null) {
        _kickoffMasterData();
        return _SessionResult(authenticated: true, profile: refreshedProfile);
      }
    }

    await _storageService.clearAuthData();
    return const _SessionResult(authenticated: false);
  }

  void _kickoffMasterData() {
    // Fire-and-forget preload of master data so screens have it ready.
    MasterDataService.instance.preloadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SessionResult>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final result = snapshot.data!;
        if (result.authenticated) {
          return HomePage(userData: result.profile);
        }

        return const LoginPage();
      },
    );
  }
}

class _SessionResult {
  final bool authenticated;
  final Map<String, dynamic>? profile;

  const _SessionResult({
    required this.authenticated,
    this.profile,
  });
}
