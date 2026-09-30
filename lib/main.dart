import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';
import 'core/connectivity_service.dart';
import 'core/supabase_service.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await _initWindow();
  }
  await SupabaseService.init();
  runApp(const BetAdminApp());
}

/// Configures the frameless window. Dragging and the custom minimize /
/// maximize / close buttons are handled through window_manager
/// (the same approach used by SemFlix TV), which talks to the top-level
/// window directly so drags move the whole window.
Future<void> _initWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 720),
    center: true,
    title: 'Positive Elijoe Bet',
    backgroundColor: AppColors.bg,
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: false,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

class BetAdminApp extends StatelessWidget {
  const BetAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const StartupScreen(),
      routes: {
        '/': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

/// Where startup ended up: a screen to show, or "no connection" so the session
/// is left untouched and startup can be retried.
class _Startup {
  const _Startup.screen(this.screen) : offline = false;
  const _Startup.noConnection() : screen = null, offline = true;

  final Widget? screen;
  final bool offline;
}

/// Decides the first screen based on a persisted Supabase session, so the app
/// does not log the admin out every time it is reopened.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<_Startup> _target = _resolve();
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    // Resume automatically once the machine is back online, so an admin who
    // opened the app on a plane does not have to press anything.
    _connectivity = ConnectivityService.onChange.listen((results) {
      final back = results.any((r) => r != ConnectivityResult.none);
      if (back && _offline && mounted) _retry();
    });
  }

  @override
  void dispose() {
    _connectivity?.cancel();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _target = _resolve();
    });
  }

  Future<_Startup> _resolve() async {
    if (!AppConfig.isConfigured) {
      _offline = false;
      return const _Startup.screen(LoginScreen());
    }
    if (Supabase.instance.client.auth.currentSession == null) {
      _offline = false;
      return const _Startup.screen(LoginScreen());
    }

    // Check the link before the role query so a disconnected start never
    // reaches the sign-out branch at all.
    if (!await ConnectivityService.isOnline()) {
      _offline = true;
      return const _Startup.noConnection();
    }

    switch (await SupabaseService.adminStatus()) {
      case AdminStatus.admin:
        _offline = false;
        return const _Startup.screen(HomeScreen());
      case AdminStatus.offline:
        _offline = true;
        return const _Startup.noConnection();
      case AdminStatus.notAdmin:
        // Only a real "not an admin" verdict ends the session.
        await SupabaseService.signOut();
        _offline = false;
        return const _Startup.screen(LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Startup>(
      future: _target,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // The raw exception can contain internal endpoints and the
            // Supabase project URL, so keep it out of the UI.
            debugPrint('Startup failed: ${snapshot.error}');
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: errorCard(
                    'Could not start the app.\n\n'
                    'Check your internet connection and try again.',
                    _retry,
                  ),
                ),
              ),
            );
          }
          final result = snapshot.data;
          if (result != null) {
            if (result.offline) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: errorCard(
                      'No internet connection.\n\n'
                      'The app will start automatically once you are back online.',
                      _retry,
                    ),
                  ),
                ),
              );
            }
            return result.screen!;
          }
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
