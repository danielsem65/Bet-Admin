import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
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
          .from('news')
          .select('id,title,published,created_at')
          .order('created_at', ascending: false)
          .limit(300);
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
      builder: (_) => NewsForm(existing: row),
    );
    if (result != null) _load();
  }

  Future<void> _togglePublish(Map<String, dynamic> row) async {
    final now = row['published'] == true ? false : true;
    try {
      await SupabaseService.client.from('news').update({'published': now}).eq('id', row['id']);
      if (mounted) {
        snack(context, now ? 'Article published' : 'Article unpublished');
        _load();
      }
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmDialog(context, 'Delete article', 'Delete "${row['title']}"?')) return;
    try {
      await SupabaseService.client.from('news').delete().eq('id', row['id']);
      if (mounted) {
        snack(context, 'Article deleted');
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
            title: 'News & Tips',
            subtitle: 'Articles shown on the site',
            actions: [
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New article'),
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
                DataColumn(label: Text('Title')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Published')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _rows.map((r) {
                return DataRow(
                  cells: [
                    DataCell(SizedBox(width: 420, child: Text(r['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(fmtDate(r['created_at']?.toString()))),
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
        ],
      ),
    );
  }
}

class NewsForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const NewsForm({super.key, this.existing});

  @override
  State<NewsForm> createState() => _NewsFormState();
}

class _NewsFormState extends State<NewsForm> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _img1 = TextEditingController();
  final _img2 = TextEditingController();
  final _img3 = TextEditingController();
  bool _published = true;
  bool _busy = false;
  String? _error;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    if (r != null) {
      _title.text = r['title']?.toString() ?? '';
      _body.text = r['body']?.toString() ?? '';
      _img1.text = r['image_1']?.toString() ?? '';
      _img2.text = r['image_2']?.toString() ?? '';
      _img3.text = r['image_3']?.toString() ?? '';
      _published = r['published'] != false;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _img1.dispose();
    _img2.dispose();
    _img3.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        if (_img1.text.trim().isNotEmpty) 'image_1': _img1.text.trim(),
        if (_img2.text.trim().isNotEmpty) 'image_2': _img2.text.trim(),
        if (_img3.text.trim().isNotEmpty) 'image_3': _img3.text.trim(),
        'published': _published,
      };
      if (_isEdit) {
        await SupabaseService.client.from('news').update(data).eq('id', widget.existing!['id']);
      } else {
        data['created_by'] = SupabaseService.user?.id;
        await SupabaseService.client.from('news').insert(data);
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
      title: Text(_isEdit ? 'Edit article' : 'New article'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              formField(_title, 'Title *'),
              const SizedBox(height: 12),
              formField(_body, 'Body', multiline: true),
              const SizedBox(height: 12),
              formField(_img1, 'Image URL 1', hint: 'https://...'),
              const SizedBox(height: 10),
              formField(_img2, 'Image URL 2', hint: 'https://...'),
              const SizedBox(height: 10),
              formField(_img3, 'Image URL 3', hint: 'https://...'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _published,
                onChanged: (v) => setState(() => _published = v ?? true),
                title: const Text('Published'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
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
