import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  String _filter = '';
  int _minutes = 30;
  bool _purging = false;

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
          .from('payments')
          .select('id,created_at,amount,currency,status,reference,gateway,user:profiles(email,full_name),plan:prediction_plans(name)')
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

  Future<void> _purgeStale() async {
    final cut = DateTime.now().toUtc().subtract(Duration(minutes: _minutes)).toIso8601String();
    if (!await confirmDialog(
      context,
      'Purge stale payments',
      'Delete payments older than $_minutes minutes with status pending or abandoned?',
    )) {
      return;
    }
    setState(() => _purging = true);
    try {
      final res = await SupabaseService.client
          .from('payments')
          .delete()
          .lt('created_at', cut)
          .or('status.eq.pending,status.eq.abandoned')
          .select();
      final n = res.length;
      if (mounted) {
        snack(context, 'Purged $n stale payment(s)');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Purge failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _purging = false);
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
            title: 'Payments',
            subtitle: 'Payment transactions',
            actions: [
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: const InputDecoration(labelText: 'Filter'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'success', child: Text('Success')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  DropdownMenuItem(value: 'abandoned', child: Text('Abandoned')),
                ],
                onChanged: (v) => setState(() => _filter = v ?? ''),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DropdownButton<int>(
                value: _minutes,
                items: [15, 30, 45, 60, 90, 120]
                    .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                    .toList(),
                onChanged: (v) => setState(() => _minutes = v ?? 30),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _purging ? null : _purgeStale,
                icon: _purging
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_sweep, size: 18),
                label: const Text('Purge stale pending payments'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingBox()
          else if (_error != null)
            errorCard(_error!, _load)
          else
            DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Reference')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
              ],
              rows: _filtered.map((r) {
                final u = r['user'] as Map<String, dynamic>?;
                final p = r['plan'] as Map<String, dynamic>?;
                final name = u?['full_name']?.toString().isNotEmpty == true
                    ? u!['full_name']!.toString()
                    : (u?['email']?.toString() ?? '—');
                return DataRow(
                  cells: [
                    DataCell(Text(fmtDate(r['created_at']?.toString(), time: true))),
                    DataCell(SizedBox(width: 180, child: Text(name, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(p?['name']?.toString() ?? '—')),
                    DataCell(SizedBox(width: 160, child: Text(r['reference']?.toString() ?? '', overflow: TextOverflow.ellipsis))),
                    DataCell(Text(money((r['amount'] as num?)?.toDouble() ?? 0))),
                    DataCell(payStatusBadge(r['status']?.toString() ?? '')),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
