import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/team_logo.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  int _offset = 0;
  bool _hasMore = true;
  String _search = '';
  final _searchCtrl = TextEditingController();
  static const _limit = 100;

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
      var q = SupabaseService.client.from('predictions').select(
        'id,title,sport,league,home_team,away_team,match_date,prediction,booking_code,odds,category,analysis,confidence,status,published,created_at',
      );
      if (_search.isNotEmpty) {
        q = q.or('title.ilike.%$_search%,league.ilike.%$_search%,home_team.ilike.%$_search%,away_team.ilike.%$_search%');
      }
      final res = await q.order('match_date', ascending: false).range(_offset, _offset + _limit - 1);
      setState(() {
        _rows = res.cast<Map<String, dynamic>>();
        _hasMore = res.length == _limit;
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

  Future<void> _openForm([Map<String, dynamic>? row]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => PredictionForm(existing: row),
    );
    if (result != null) _load();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Delete prediction', 'Delete "${row['title']}"? This cannot be undone.')) return;
    try {
      await SupabaseService.client.from('predictions').delete().eq('id', row['id']);
      if (mounted) {
        snack(context, 'Prediction deleted');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Delete failed: $e', error: true);
    }
  }

  Future<void> _togglePublish(Map<String, dynamic> row) async {
    final now = row['published'] == true ? false : true;
    try {
      await SupabaseService.client.from('predictions').update({'published': now}).eq('id', row['id']);
      if (mounted) {
        snack(context, now ? 'Published' : 'Unpublished');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Predictions',
            subtitle: 'Manage tips for FREE, VIP and VVIP users',
            actions: [
              RefreshButton(onPressed: _load, enabled: !_loading),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New prediction'),
              ),
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
                  decoration: const InputDecoration(
                    labelText: 'Search title / league / teams',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: Icon(Icons.filter_list, size: 18),
                  ),
                  onSubmitted: (_) {
                    _offset = 0;
                    _load();
                  },
                ),
              ),
              OutlinedButton(onPressed: () { _offset = 0; _load(); }, child: const Text('Search')),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingBox()
          else if (_error != null)
            errorCard(_error!, _load)
          else ...[
            AppTable(
              columns: const [
                DataColumn(label: Text('Match')),
                DataColumn(label: Text('Tip')),
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Odds')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Published')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _rows.map((r) {
                final home = r['home_team']?.toString() ?? '';
                final away = r['away_team']?.toString() ?? '';
                final matchName = home.isEmpty && away.isEmpty
                    ? (r['title']?.toString() ?? '—')
                    : (r['league']?.toString().isNotEmpty == true ? '${r['league']} • $home vs $away' : '$home vs $away');
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 220, child: Text(matchName, maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(SizedBox(width: 180, child: Text(r['prediction']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(fmtDate(r['match_date']?.toString(), time: true))),
                    DataCell(categoryBadge(r['category']?.toString() ?? '')),
                    DataCell(Text(r['odds']?.toString() ?? '—')),
                    DataCell(statusBadge(r['status']?.toString() ?? '')),
                    DataCell(Icon(r['published'] == true ? Icons.visibility : Icons.visibility_off,
                        color: r['published'] == true ? AppColors.green : AppColors.muted, size: 18)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Publish/Unpublish', icon: const Icon(Icons.publish, size: 18), onPressed: () => _togglePublish(r)),
                        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit, size: 18), onPressed: () => _openForm(r)),
                        IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete, size: 18, color: AppColors.red), onPressed: () => _delete(r)),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: _offset > 0 ? () { _offset -= _limit; _load(); } : null,
                  child: const Text('Previous'),
                ),
                OutlinedButton(
                  onPressed: _hasMore ? () { _offset += _limit; _load(); } : null,
                  child: const Text('Next'),
                ),
                Text('Page ${(_offset ~/ _limit) + 1} — ${_rows.length} shown',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

DateTime? parseDate(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final dt = DateTime.tryParse(t);
  if (dt != null) return dt.toUtc();
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})$').firstMatch(t);
  if (m != null) {
    return DateTime(
      int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!),
      int.parse(m[4]!), int.parse(m[5]!),
    ).toUtc();
  }
  final m2 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(t);
  if (m2 != null) {
    return DateTime(int.parse(m2[1]!), int.parse(m2[2]!), int.parse(m2[3]!), 18, 0).toUtc();
  }
  return null;
}

String fmtEditableDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '';
  return '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)} ${_pad2(dt.hour)}:${_pad2(dt.minute)}';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

class PredictionForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const PredictionForm({super.key, this.existing});

  @override
  State<PredictionForm> createState() => _PredictionFormState();
}

class _PredictionFormState extends State<PredictionForm> {
  final _title = TextEditingController();
  final _sport = TextEditingController();
  final _league = TextEditingController();
  final _home = TextEditingController();
  final _away = TextEditingController();
  final _date = TextEditingController();
  final _tip = TextEditingController();
  final _code = TextEditingController();
  final _odds = TextEditingController();
  final _confidence = TextEditingController();
  final _analysis = TextEditingController();
  String _category = 'FREE';
  String _status = 'Pending';
  bool _published = false;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _title.text = r['title']?.toString() ?? '';
      _sport.text = r['sport']?.toString() ?? '';
      _league.text = r['league']?.toString() ?? '';
      _home.text = r['home_team']?.toString() ?? '';
      _away.text = r['away_team']?.toString() ?? '';
      _date.text = fmtEditableDate(r['match_date']?.toString());
      _tip.text = r['prediction']?.toString() ?? '';
      _code.text = r['booking_code']?.toString() ?? '';
      _odds.text = r['odds']?.toString() ?? '';
      _confidence.text = r['confidence']?.toString() ?? '';
      _analysis.text = r['analysis']?.toString() ?? '';
      _category = r['category']?.toString() ?? 'FREE';
      _status = r['status']?.toString() ?? 'Pending';
      _published = r['published'] == true;
    } else {
      _sport.text = 'Football';
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _sport, _league, _home, _away, _date, _tip, _code, _odds, _confidence, _analysis]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = parseDate(_date.text) ?? DateTime(now.year, now.month, now.day, 18, 0);
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null || !mounted) return;
    setState(() {
      _date.text = '${d.year}-${_pad2(d.month)}-${_pad2(d.day)} ${_pad2(t.hour)}:${_pad2(t.minute)}';
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    final date = parseDate(_date.text);
    if (date == null) {
      setState(() => _error = 'Match date is required. Use YYYY-MM-DD HH:MM.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'title': title,
        'sport': _sport.text.trim(),
        'league': _league.text.trim(),
        'home_team': _home.text.trim(),
        'away_team': _away.text.trim(),
        'match_date': date.toIso8601String(),
        'prediction': _tip.text.trim(),
        'booking_code': _code.text.trim(),
        if (_num(_odds.text) != null) 'odds': _num(_odds.text),
        'category': _category,
        'analysis': _analysis.text.trim(),
        if (int.tryParse(_confidence.text.trim()) != null) 'confidence': int.tryParse(_confidence.text.trim()),
        'status': _status,
        'published': _published,
      };

      if (_isEdit) {
        await SupabaseService.client.from('predictions').update(data).eq('id', widget.existing!['id']);
      } else {
        data['created_by'] = SupabaseService.user?.id;
        await SupabaseService.client.from('predictions').insert(data);
      }
      if (mounted) {
        Navigator.pop(context, data);
        // Mirror the website: auto-save team crests so icons show on the site.
        unawaited(ensureTeamLogos([_home.text.trim(), _away.text.trim()]));
      }
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = '${e.message} (${e.code})');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit prediction' : 'New prediction'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formField(_title, 'Title *'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: formField(_sport, 'Sport')),
                const SizedBox(width: 10),
                Expanded(child: formField(_league, 'League')),
              ]),
              const SizedBox(height: 12),
              _TeamCrestField(controller: _home, label: 'Home team'),
              const SizedBox(height: 12),
              _TeamCrestField(controller: _away, label: 'Away team'),
              const SizedBox(height: 12),
              TextField(
                controller: _date,
                decoration: InputDecoration(
                  labelText: 'Match date *',
                  hintText: 'YYYY-MM-DD HH:MM',
                  suffixIcon: IconButton(
                    tooltip: 'Pick date and time',
                    icon: const Icon(Icons.calendar_month),
                    onPressed: _pickDateTime,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              formField(_tip, 'Prediction / tip *'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: formField(_code, 'Booking code')),
                const SizedBox(width: 10),
                Expanded(child: formField(_odds, 'Odds')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'FREE', child: Text('FREE')),
                      DropdownMenuItem(value: 'VIP', child: Text('VIP')),
                      DropdownMenuItem(value: 'VVIP', child: Text('VVIP')),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'FREE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: formField(_confidence, 'Confidence %')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'Won', child: Text('Won')),
                      DropdownMenuItem(value: 'Lost', child: Text('Lost')),
                      DropdownMenuItem(value: 'Void', child: Text('Void')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'Pending'),
                  ),
                ),
                const SizedBox(width: 10),
                CheckboxListTile(
                  value: _published,
                  onChanged: (v) => setState(() => _published = v ?? false),
                  title: const Text('Published'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ]),
              const SizedBox(height: 12),
              formField(_analysis, 'Analysis', multiline: true),
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

/// Home/Away team input with a live crest preview and a pull button that
/// fetches + saves the crest (into the `teams` table) from the web.
class _TeamCrestField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _TeamCrestField({required this.controller, required this.label});

  @override
  State<_TeamCrestField> createState() => _TeamCrestFieldState();
}

class _TeamCrestFieldState extends State<_TeamCrestField> {
  String? _logoUrl;
  bool _pulling = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _lookup();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _lookup);
  }

  Future<void> _lookup() async {
    final name = widget.controller.text.trim();
    if (!mounted) return;
    if (name.isEmpty) {
      setState(() => _logoUrl = null);
      return;
    }
    try {
      final res = await SupabaseService.client
          .from('teams')
          .select('logo_url')
          .eq('name', name)
          .maybeSingle();
      if (!mounted) return;
      final url = res?['logo_url']?.toString() ?? '';
      setState(() => _logoUrl = url.isEmpty ? null : url);
    } catch (_) {}
  }

  Future<void> _pull() async {
    if (_pulling) return;
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      snack(context, 'Enter a team name first.', error: true);
      return;
    }
    setState(() => _pulling = true);
    try {
      final url = await ensureTeamLogo(name);
      if (!mounted) return;
      setState(() => _logoUrl = (url == null || url.isEmpty) ? null : url);
      if (url == null) {
        snack(context, 'No crest found. Try the official team name.', error: true);
      } else {
        snack(context, 'Crest saved for $name');
      }
    } catch (e) {
      if (mounted) snack(context, 'Pull failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          height: 48,
          child: Center(
            child: CrestAvatar(name: widget.controller.text.trim(), url: _logoUrl),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: formField(widget.controller, widget.label)),
        const SizedBox(width: 4),
        SizedBox(
          width: 36,
          height: 48,
          child: IconButton(
            tooltip: 'Pull crest from web',
            padding: EdgeInsets.zero,
            onPressed: _pulling ? null : _pull,
            icon: _pulling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_download_outlined, size: 18, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
