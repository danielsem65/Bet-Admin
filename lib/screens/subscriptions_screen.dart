import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _filter = '';

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
      final res = await SupabaseService.client
          .from('subscriptions')
          .select('id,start_date,end_date,status,user:profiles(email,full_name),plan:prediction_plans(name)')
          .order('created_at', ascending: false)
          .limit(500);
      setState(() {
        _rows = res.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _revoke(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Revoke subscription', 'Mark this subscription as cancelled?')) return;
    try {
      await SupabaseService.client.from('subscriptions').update({'status': 'cancelled'}).eq('id', row['id']);
      if (mounted) {
        snack(context, 'Subscription revoked');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Delete subscription', 'Permanently delete this subscription?')) return;
    try {
      await SupabaseService.client.from('subscriptions').delete().eq('id', row['id']);
      if (mounted) {
        snack(context, 'Subscription deleted');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Delete failed: $e', error: true);
    }
  }

  List<Map<String, dynamic>> get _filtered => _filter.isEmpty
      ? _rows
      : _rows.where((r) => (r['status']?.toString() ?? '') == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Subscriptions',
            subtitle: 'User plan subscriptions',
            actions: [
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: const InputDecoration(labelText: 'Filter'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'expired', child: Text('Expired')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) => setState(() => _filter = v ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingBox()
          else if (_error != null)
            errorCard(_error!, _load)
          else
            AppTable(
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Start')),
                DataColumn(label: Text('End')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filtered.map((r) {
                final u = r['user'] as Map<String, dynamic>?;
                final p = r['plan'] as Map<String, dynamic>?;
                final name = u?['full_name']?.toString().isNotEmpty == true
                    ? u!['full_name']!.toString()
                    : (u?['email']?.toString() ?? '—');
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 200, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(p?['name']?.toString() ?? '—')),
                    DataCell(Text(fmtDate(r['start_date']?.toString()))),
                    DataCell(Text(fmtDate(r['end_date']?.toString()))),
                    DataCell(statusBadge(r['status']?.toString() ?? '')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Revoke', icon: const Icon(Icons.block, size: 18), onPressed: () => _revoke(r)),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete, size: 18, color: AppColors.red), onPressed: () => _delete(r)),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
