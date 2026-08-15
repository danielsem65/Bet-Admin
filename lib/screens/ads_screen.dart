import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Edits the two homepage ad cards stored in the single `site_settings`
/// row (id = 1), matching the columns the website's ad_slots_html() reads.
class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _title1 = TextEditingController();
  final _text1 = TextEditingController();
  final _details1 = TextEditingController();
  final _image1 = TextEditingController();
  final _link1 = TextEditingController();
  final _title2 = TextEditingController();
  final _text2 = TextEditingController();
  final _details2 = TextEditingController();
  final _image2 = TextEditingController();
  final _link2 = TextEditingController();

  late final List<TextEditingController> _controllers = [
    _title1, _text1, _details1, _image1, _link1,
    _title2, _text2, _details2, _image2, _link2,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.client
          .from('site_settings')
          .select(
            'ad_title_1,ad_text_1,ad_details_1,ad_image_1,ad_link_1,'
            'ad_title_2,ad_text_2,ad_details_2,ad_image_2,ad_link_2',
          )
          .eq('id', 1)
          .maybeSingle();
      if (res != null) {
        _title1.text = res['ad_title_1']?.toString() ?? '';
        _text1.text = res['ad_text_1']?.toString() ?? '';
        _details1.text = res['ad_details_1']?.toString() ?? '';
        _image1.text = res['ad_image_1']?.toString() ?? '';
        _link1.text = res['ad_link_1']?.toString() ?? '';
        _title2.text = res['ad_title_2']?.toString() ?? '';
        _text2.text = res['ad_text_2']?.toString() ?? '';
        _details2.text = res['ad_details_2']?.toString() ?? '';
        _image2.text = res['ad_image_2']?.toString() ?? '';
        _link2.text = res['ad_link_2']?.toString() ?? '';
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseService.client.from('site_settings').update({
        'ad_title_1': _title1.text.trim(),
        'ad_text_1': _text1.text.trim(),
        'ad_details_1': _details1.text.trim(),
        'ad_image_1': _image1.text.trim(),
        'ad_link_1': _link1.text.trim(),
        'ad_title_2': _title2.text.trim(),
        'ad_text_2': _text2.text.trim(),
        'ad_details_2': _details2.text.trim(),
        'ad_image_2': _image2.text.trim(),
        'ad_link_2': _link2.text.trim(),
      }).eq('id', 1);
      if (mounted) snack(context, 'Ads saved');
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = '${e.message} (${e.code})');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      maxWidth: 880,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Ads',
            subtitle: 'Homepage ad cards (site_settings row id = 1)',
            actions: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reload'),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save, size: 18),
                label: const Text('Save ads'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingBox()
          else if (_error != null && _title1.text.isEmpty && _title2.text.isEmpty)
            errorCard(_error!, _load)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final card1 = _AdCardEditor(
                  index: 1,
                  title: _title1,
                  text: _text1,
                  details: _details1,
                  image: _image1,
                  link: _link1,
                );
                final card2 = _AdCardEditor(
                  index: 2,
                  title: _title2,
                  text: _text2,
                  details: _details2,
                  image: _image2,
                  link: _link2,
                );
                if (constraints.maxWidth >= 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: card1),
                      const SizedBox(width: 16),
                      Expanded(child: card2),
                    ],
                  );
                }
                return Column(
                  children: [
                    card1,
                    const SizedBox(height: 16),
                    card2,
                  ],
                );
              },
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _AdCardEditor extends StatelessWidget {
  final int index;
  final TextEditingController title;
  final TextEditingController text;
  final TextEditingController details;
  final TextEditingController image;
  final TextEditingController link;

  const _AdCardEditor({
    required this.index,
    required this.title,
    required this.text,
    required this.details,
    required this.image,
    required this.link,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ad card $index',
            style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          formField(title, 'Title (empty shows "Sponsored")'),
          const SizedBox(height: 10),
          formField(text, 'Text line'),
          const SizedBox(height: 10),
          ImageUrlField(controller: image, label: 'Image URL'),
          const SizedBox(height: 10),
          formField(link, 'Link URL (whole card becomes a link)', hint: 'https://...'),
          const SizedBox(height: 10),
          formField(details, 'Details (below the card)', multiline: true),
          const SizedBox(height: 14),
          Center(child: _AdCardPreview(title: title, text: text, image: image, details: details)),
        ],
      ),
    );
  }
}

/// Live preview of how the ad card renders on the homepage.
class _AdCardPreview extends StatefulWidget {
  final TextEditingController title;
  final TextEditingController text;
  final TextEditingController image;
  final TextEditingController details;

  const _AdCardPreview({
    required this.title,
    required this.text,
    required this.image,
    required this.details,
  });

  @override
  State<_AdCardPreview> createState() => _AdCardPreviewState();
}

class _AdCardPreviewState extends State<_AdCardPreview> {
  @override
  void initState() {
    super.initState();
    for (final c in [widget.title, widget.text, widget.image, widget.details]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [widget.title, widget.text, widget.image, widget.details]) {
      c.removeListener(_onChanged);
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String? get _imageUrl {
    final url = widget.image.text.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final sep = url.startsWith('/') ? '' : '/';
    return '${AppConfig.adminApiBase}$sep$url';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title.text.trim();
    final text = widget.text.text.trim();
    final details = widget.details.text.trim();
    final imageUrl = _imageUrl;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: imageUrl == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A2542), Color(0xFF0B1220)],
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.campaign_outlined, color: AppColors.muted, size: 28),
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (context, error, stack) => Container(
                          height: 140,
                          color: const Color(0xFF1A2542),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, color: AppColors.red, size: 28),
                          ),
                        ),
                      ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                    ),
                  ),
                ),
              ),
              const Positioned(left: 8, top: 8, child: _AdTag()),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Sponsored' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                      ),
                    ),
                    if (text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFDDE3EE),
                          fontSize: 12,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Learn more', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(details, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

class _AdTag extends StatelessWidget {
  const _AdTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text('Ad', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
