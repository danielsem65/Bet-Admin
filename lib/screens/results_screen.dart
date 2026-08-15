import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final Map<Object?, String> _statusDrafts = {};
  String _filter = 'Pending';

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
          .from('predictions')
          .select('id,title,home_team,away_team,league,category,match_date,status,odds')
          .order('match_date', ascending: false)
          .limit(500);
      setState(() {
        _rows = res.cast<Map<String, dynamic>>();
        _statusDrafts.clear();
        for (final r in _rows) {
          _statusDrafts[r['id']] = r['status']?.toString() ?? 'Pending';
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveResult(Map<String, dynamic> row) async {
    final status = _statusDrafts[row['id']];
    try {
      await SupabaseService.client.from('predictions').update({'status': status}).eq('id', row['id']);
      if (mounted) snack(context, '${row['title']} → $status');
    } catch (e) {
      if (mounted) snack(context, 'Save failed: $e', error: true);
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
            title: 'Results',
            subtitle: 'Mark predictions Won, Lost or Void',
            actions: [
              DropdownButtonFormField<String>(
                initialValue: _filter,
                decoration: const InputDecoration(labelText: 'Filter'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Won', child: Text('Won')),
                  DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                  DropdownMenuItem(value: 'Void', child: Text('Void')),
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
                DataColumn(label: Text('Match')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Result')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _filtered.map((r) {
                final home = r['home_team']?.toString() ?? '';
                final away = r['away_team']?.toString() ?? '';
                final matchName = home.isEmpty ? (r['title']?.toString() ?? '—') : '$home vs $away';
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 260, child: Text(matchName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(categoryBadge(r['category']?.toString() ?? '')),
                    DataCell(Text(fmtDate(r['match_date']?.toString()))),
                    DataCell(DropdownButton<String>(
                      value: _statusDrafts[r['id']] ?? 'Pending',
                      items: const [
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Won', child: Text('Won')),
                        DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                        DropdownMenuItem(value: 'Void', child: Text('Void')),
                      ],
                      onChanged: (v) => setState(() => _statusDrafts[r['id']] = v ?? 'Pending'),
                    )),
                    DataCell(OutlinedButton(
                      onPressed: () => _saveResult(r),
                      child: const Text('Save'),
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
