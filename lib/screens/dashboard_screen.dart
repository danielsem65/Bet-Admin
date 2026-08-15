import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  int users = 0;
  int activeSubs = 0;
  int totalPayments = 0;
  int free = 0;
  int vip = 0;
  int vvip = 0;
  double revenue = 0;
  List<Map<String, dynamic>> recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sb = SupabaseService.client;
      final now = DateTime.now().toUtc().toIso8601String();

      final usersRes = await sb.from('profiles').select('id');
      final subsRes = await sb
          .from('subscriptions')
          .select('id')
          .eq('status', 'active')
          .gte('end_date', now);
      final payRes = await sb.from('payments').select('amount,status');
      final freeRes = await sb.from('predictions').select('id').eq('published', true).eq('category', 'FREE');
      final vipRes = await sb.from('predictions').select('id').eq('published', true).eq('category', 'VIP');
      final vvipRes = await sb.from('predictions').select('id').eq('published', true).eq('category', 'VVIP');
      final recentRes = await sb
          .from('payments')
          .select(
            'created_at,amount,currency,status,reference,user:profiles(email,full_name),plan:prediction_plans(name)',
          )
          .order('created_at', ascending: false)
          .limit(10);

      double rev = 0;
      for (final r in payRes) {
        totalPayments++;
        if (r['status'] == 'success') rev += (r['amount'] as num?)?.toDouble() ?? 0;
      }

      setState(() {
        users = usersRes.length;
        activeSubs = subsRes.length;
        revenue = rev;
        free = freeRes.length;
        vip = vipRes.length;
        vvip = vvipRes.length;
        recent = recentRes.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _error = '${e.message} (${e.code})';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Dashboard',
            subtitle: 'Platform overview',
            actions: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingBox()
          else if (_error != null)
            errorCard(_error!, _load)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    StatCard(label: 'Total Users', value: '$users', icon: Icons.people, color: AppColors.blue),
                    StatCard(label: 'Active Subscriptions', value: '$activeSubs', icon: Icons.verified_user, color: AppColors.green),
                    StatCard(label: 'Revenue', value: money(revenue), icon: Icons.payments, color: AppColors.gold),
                    StatCard(label: 'Total Payments', value: '$totalPayments', icon: Icons.receipt_long, color: AppColors.purple),
                    StatCard(label: 'Free Predictions', value: '$free', icon: Icons.sports_soccer, color: AppColors.green),
                    StatCard(label: 'VIP Predictions', value: '$vip', icon: Icons.workspace_premium, color: AppColors.gold),
                    StatCard(label: 'VVIP Predictions', value: '$vvip', icon: Icons.star, color: AppColors.purple),
                  ],
                ),
                const SizedBox(height: 28),
                const Text('Recent transactions', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                AppTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Plan')),
                    DataColumn(label: Text('Reference')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: recent.map((p) {
                    final user = p['user'] as Map<String, dynamic>?;
                    final plan = p['plan'] as Map<String, dynamic>?;
                    return DataRow(
                      cells: [
                        DataCell(Text(fmtDate(p['created_at']?.toString(), time: true))),
                        DataCell(Text(user?['full_name']?.toString().isNotEmpty == true
                            ? user!['full_name']!.toString()
                            : (user?['email']?.toString() ?? '—'))),
                        DataCell(Text(plan?['name']?.toString() ?? '—')),
                        DataCell(Text(p['reference']?.toString() ?? '—')),
                        DataCell(Text(money((p['amount'] as num?)?.toDouble() ?? 0))),
                        DataCell(payStatusBadge(p['status']?.toString() ?? '')),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
