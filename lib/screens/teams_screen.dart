import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/team_logo.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
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
      final res = await SupabaseService.client.from('teams').select('*').order('name', ascending: true);
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

  Future<void> _openForm([Map<String, dynamic>? row]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => TeamForm(existing: row),
    );
    if (result != null) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Delete team', 'Delete "${row['name']}"?')) return;
    try {
      await SupabaseService.client.from('teams').delete().eq('id', row['id']);
      if (mounted) {
        snack(context, 'Team deleted');
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
            title: 'Teams',
            subtitle: 'Team avatars used on prediction cards',
            actions: [
              RefreshButton(onPressed: _load, enabled: !_loading),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New team'),
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
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Sport')),
                DataColumn(label: Text('Logo')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _rows.map((r) {
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 220, child: Text(r['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(r['sport']?.toString() ?? '—')),
                    DataCell(r['logo_url']?.toString().isNotEmpty == true
                        ? CrestAvatar(url: r['logo_url'].toString(), name: r['name']?.toString() ?? '')
                        : const Text('—')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit, size: 18), onPressed: () => _openForm(r)),
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

class TeamForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const TeamForm({super.key, this.existing});

  @override
  State<TeamForm> createState() => _TeamFormState();
}

class _TeamFormState extends State<TeamForm> {
  final _name = TextEditingController();
  final _sport = TextEditingController();
  final _logo = TextEditingController();
  bool _busy = false;
  String? _error;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _name.text = r['name']?.toString() ?? '';
      _sport.text = r['sport']?.toString() ?? '';
      _logo.text = r['logo_url']?.toString() ?? '';
    } else {
      _sport.text = 'Football';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _sport.dispose();
    _logo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Team name is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        if (_sport.text.trim().isNotEmpty) 'sport': _sport.text.trim(),
        if (_logo.text.trim().isNotEmpty) 'logo_url': _logo.text.trim(),
      };
      if (_isEdit) {
        await SupabaseService.client.from('teams').update(data).eq('id', widget.existing!['id']);
      } else {
        await SupabaseService.client.from('teams').insert(data);
      }
      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Pulls the team crest from the web using the entered team name so
  /// the admin can save it alongside (or instead of) a picked image.
  Future<String?> _pullCrest() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      snack(context, 'Enter a team name first.', error: true);
      return null;
    }
    return fetchTeamLogoFromWeb(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit team' : 'New team'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formField(_name, 'Name *'),
              const SizedBox(height: 12),
              formField(_sport, 'Sport'),
              const SizedBox(height: 12),
              ImageUrlField(controller: _logo, label: 'Logo URL', onPull: _pullCrest),
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
              : Text(_isEdit ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}
