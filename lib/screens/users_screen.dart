import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = SupabaseService.client
          .from('profiles')
          .select('id,full_name,email,role,banned_at,created_at');
      if (_search.isNotEmpty) {
        q = q.or('email.ilike.%$_search%,full_name.ilike.%$_search%');
      }
      final res = await q.order('created_at', ascending: false).limit(1000);
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

  Future<void> _setBan(Map<String, dynamic> row, bool banned) async {
    final name = row['full_name']?.toString().isNotEmpty == true ? row['full_name'].toString() : (row['email']?.toString() ?? 'user');
    if (!await confirmDialog(context, banned ? 'Ban user' : 'Unban user',
        '${banned ? 'Ban' : 'Unban'} $name?')) {
      return;
    }
    try {
      final val = banned ? DateTime.now().toUtc().toIso8601String() : null;
      await SupabaseService.client.from('profiles').update({'banned_at': val}).eq('id', row['id']);
      if (mounted) {
        snack(context, banned ? 'User banned' : 'User unbanned');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final name = row['full_name']?.toString().isNotEmpty == true ? row['full_name'].toString() : (row['email']?.toString() ?? 'user');
    if (!await confirmDialog(context, 'Delete user',
        'Permanently delete $name and all their data? This cannot be undone.')) {
      return;
    }
    try {
      final uri = Uri.parse('${AppConfig.adminApiBase}/api/admin-users.php');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseService.accessToken}',
        },
        body: jsonEncode({'action': 'delete_user', 'user_id': row['id']}),
      ).timeout(const Duration(seconds: 30));
      Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }
      if (resp.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          snack(context, 'User deleted');
          _load();
        }
      } else {
        if (mounted) {
          snack(context, 'Delete failed: ${data['error'] ?? 'HTTP ${resp.statusCode} (endpoint not deployed?)'}',
              error: true);
        }
      }
    } catch (e) {
      if (mounted) snack(context, 'Delete failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Users',
            subtitle: 'All registered accounts',
            actions: [
              RefreshButton(onPressed: _load, enabled: !_loading),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(labelText: 'Search email / name', prefixIcon: Icon(Icons.search)),
                  onSubmitted: (_) {
                    _search = _searchCtrl.text.trim();
                    _load();
                  },
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  _search = _searchCtrl.text.trim();
                  _load();
                },
                child: const Text('Search'),
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
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _rows.map((r) {
                final name = r['full_name']?.toString().isNotEmpty == true
                    ? r['full_name'].toString()
                    : (r['email']?.toString() ?? '—');
                final banned = r['banned_at'] != null;
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 240, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(badge(r['role']?.toString() ?? 'user',
                        r['role'] == 'admin' ? AppColors.gold : AppColors.blue)),
                    DataCell(Text(fmtDate(r['created_at']?.toString()))),
                    DataCell(badge(banned ? 'banned' : 'active', banned ? AppColors.red : AppColors.green)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: banned ? 'Unban' : 'Ban',
                          icon: Icon(banned ? Icons.lock_open : Icons.block,
                              size: 18, color: banned ? AppColors.green : AppColors.red),
                          onPressed: () => _setBan(r, !banned),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete, size: 18, color: AppColors.red),
                          onPressed: () => _delete(r),
                        ),
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
