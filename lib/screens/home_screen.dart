import 'package:flutter/material.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'news_screen.dart';
import 'notifications_screen.dart';
import 'payments_screen.dart';
import 'plans_screen.dart';
import 'predictions_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';
import 'teams_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _titles = [
    'Dashboard',
    'Predictions',
    'Results',
    'News & Tips',
    'Plans',
    'Teams',
    'Subscriptions',
    'Payments',
    'Users',
    'Notifications',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.user?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset('assets/logo.png', width: 22, height: 22, fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Text(_titles[_index], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(email, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (await confirmDialog(context, 'Sign out', 'Sign out of the admin console?')) {
                await SupabaseService.signOut();
                if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            minWidth: 92,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.sports_soccer_outlined), selectedIcon: Icon(Icons.sports_soccer), label: Text('Predictions')),
              NavigationRailDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: Text('Results')),
              NavigationRailDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: Text('News')),
              NavigationRailDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium), label: Text('Plans')),
              NavigationRailDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: Text('Teams')),
              NavigationRailDestination(icon: Icon(Icons.verified_user_outlined), selectedIcon: Icon(Icons.verified_user), label: Text('Subs')),
              NavigationRailDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments), label: Text('Payments')),
              NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Users')),
              NavigationRailDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: Text('Alerts')),
              NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: switch (_index) {
              0 => const DashboardScreen(),
              1 => const PredictionsScreen(),
              2 => const ResultsScreen(),
              3 => const NewsScreen(),
              4 => const PlansScreen(),
              5 => const TeamsScreen(),
              6 => const SubscriptionsScreen(),
              7 => const PaymentsScreen(),
              8 => const UsersScreen(),
              9 => const NotificationsScreen(),
              _ => const SettingsScreen(),
            },
          ),
        ],
      ),
    );
  }
}
