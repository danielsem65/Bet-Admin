import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';
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

/// Decides the first screen based on a persisted Supabase session, so the app
/// does not log the admin out every time it is reopened.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<Widget> _target = _resolve();

  void _retry() {
    setState(() {
      _target = _resolve();
    });
  }

  Future<Widget> _resolve() async {
    if (!AppConfig.isConfigured) return const LoginScreen();
    if (Supabase.instance.client.auth.currentSession == null) {
      return const LoginScreen();
    }
    if (await SupabaseService.isAdmin()) {
      return const HomeScreen();
    }
    await SupabaseService.signOut();
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _target,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) return snapshot.data!;
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
