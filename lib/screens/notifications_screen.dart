import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

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
          .from('notifications')
          .select('id,audience,message,link,user_id,created_at')
          .order('created_at', ascending: false)
          .limit(200);
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

  Future<void> _openForm() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const NotificationForm(),
    );
    if (result != null) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Delete notification', 'Delete this notification?')) return;
    try {
      await SupabaseService.client.from('notifications').delete().eq('id', row['id']);
      if (mounted) {
        snack(context, 'Notification deleted');
        _load();
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
            title: 'Notifications',
            subtitle: 'Broadcast messages to all users or by plan',
            actions: [
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New notification'),
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
                DataColumn(label: Text('Audience')),
                DataColumn(label: Text('Message')),
                DataColumn(label: Text('Link')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _rows.map((r) {
                return DataRow(
                  cells: [
                    DataCell(Text(fmtDate(r['created_at']?.toString(), time: true))),
                    DataCell(badge(r['audience']?.toString() ?? '', r['user_id'] != null ? AppColors.blue : AppColors.gold)),
                    DataCell(SizedBox(width: 380, child: Text(r['message']?.toString() ?? '', overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(
                      width: 180,
                      child: Text(r['link']?.toString().isNotEmpty == true ? r['link'].toString() : '—', overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete, size: 18, color: AppColors.red),
                      onPressed: () => _delete(r),
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

class NotificationForm extends StatefulWidget {
  const NotificationForm({super.key});

  @override
  State<NotificationForm> createState() => _NotificationFormState();
}

class _NotificationFormState extends State<NotificationForm> {
  final _message = TextEditingController();
  final _link = TextEditingController();
  String _audience = 'all';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _error = 'Message is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.client.from('notifications').insert({
        'message': message,
        'audience': _audience,
        'link': _link.text.trim(),
        'user_id': null,
      });
      if (mounted) Navigator.pop(context, {'message': message});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New notification'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formField(_message, 'Message *', multiline: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All users')),
                  DropdownMenuItem(value: 'vip', child: Text('VIP only')),
                  DropdownMenuItem(value: 'vvip', child: Text('VVIP only')),
                ],
                onChanged: (v) => setState(() => _audience = v ?? 'all'),
              ),
              const SizedBox(height: 12),
              formField(_link, 'Link (optional)', hint: 'https://...'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send'),
        ),
      ],
    );
  }
}
