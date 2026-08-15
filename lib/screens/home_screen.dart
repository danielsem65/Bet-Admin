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
      body: Column(
        children: [
          const _DragStrip(),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset('assets/logo.png', width: 22, height: 22, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _titles[_index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
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
                  _Sidebar(
                    selectedIndex: _index,
                    onSelect: (i) => setState(() => _index = i),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _DragStrip extends StatelessWidget {
  const _DragStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: double.infinity,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.selectedIndex, required this.onSelect});

  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.sports_soccer_outlined, Icons.sports_soccer, 'Predictions'),
    (Icons.emoji_events_outlined, Icons.emoji_events, 'Results'),
    (Icons.article_outlined, Icons.article, 'News & Tips'),
    (Icons.workspace_premium_outlined, Icons.workspace_premium, 'Plans'),
    (Icons.groups_outlined, Icons.groups, 'Teams'),
    (Icons.verified_user_outlined, Icons.verified_user, 'Subscriptions'),
    (Icons.payments_outlined, Icons.payments, 'Payments'),
    (Icons.people_outline, Icons.people, 'Users'),
    (Icons.notifications_outlined, Icons.notifications, 'Notifications'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 208,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < _items.length; i++)
            _SidebarItem(
              icon: _items[i].$1,
              selectedIcon: _items[i].$2,
              label: _items[i].$3,
              selected: i == selectedIndex,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x22FBBF24) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(selected ? selectedIcon : icon, size: 20, color: selected ? AppColors.gold : AppColors.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.gold : AppColors.text,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
