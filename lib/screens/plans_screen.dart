import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
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
      final res = await SupabaseService.client.from('prediction_plans').select('*').order('price', ascending: true);
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
      builder: (_) => PlanForm(existing: row),
    );
    if (result != null) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Delete plan', 'Delete "${row['name']}"?')) return;
    try {
      await SupabaseService.client.from('prediction_plans').delete().eq('id', row['id']);
      if (mounted) {
        snack(context, 'Plan deleted');
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
            title: 'Plans',
            subtitle: 'Subscription packages',
            actions: [
              RefreshButton(onPressed: _load, enabled: !_loading),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New plan'),
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
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Duration (days)')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _rows.map((r) {
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 260, child: Text(r['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(money((r['price'] as num?)?.toDouble() ?? 0))),
                    DataCell(Text(r['duration_days']?.toString() ?? '—')),
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

class PlanForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const PlanForm({super.key, this.existing});

  @override
  State<PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<PlanForm> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _days = TextEditingController();
  final _desc = TextEditingController();
  bool _busy = false;
  String? _error;
  bool get _isEdit => widget.existing != null;

  String _slug(String name) {
    var s = name.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'-+'), '-');
    return s.replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _name.text = r['name']?.toString() ?? '';
      _price.text = r['price']?.toString() ?? '';
      _days.text = r['duration_days']?.toString() ?? '';
      _desc.text = r['description']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _days.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = double.tryParse(_price.text.trim());
    final days = int.tryParse(_days.text.trim());
    final name = _name.text.trim();
    if (name.isEmpty || price == null || days == null) {
      setState(() => _error = 'Name, a valid price and duration are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'name': name,
        'slug': _slug(name),
        'price': price,
        'duration_days': days,
        'description': _desc.text.trim(),
      };
      if (_isEdit) {
        await SupabaseService.client.from('prediction_plans').update(data).eq('id', widget.existing!['id']);
      } else {
        await SupabaseService.client.from('prediction_plans').insert(data);
      }
      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit plan' : 'New plan'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formField(_name, 'Name *'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: formField(_price, 'Price (GHS) *')),
                const SizedBox(width: 10),
                Expanded(child: formField(_days, 'Duration (days) *')),
              ]),
              const SizedBox(height: 12),
              formField(_desc, 'Description', multiline: true),
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
