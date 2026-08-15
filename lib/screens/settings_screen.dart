import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _siteName = TextEditingController();
  final _description = TextEditingController();
  final _currency = TextEditingController();
  final _supportContact = TextEditingController();
  final _telegramSupport = TextEditingController();
  final _telegramVip = TextEditingController();
  final _telegramVvip = TextEditingController();
  final _bookingLabel = TextEditingController();
  final _bookingCode = TextEditingController();
  final _bookingBookie = TextEditingController();
  final _bookingLink = TextEditingController();
  final _bookingNote = TextEditingController();
  final _bookingLabel2 = TextEditingController();
  final _bookingCode2 = TextEditingController();
  final _bookingBookie2 = TextEditingController();
  final _bookingLink2 = TextEditingController();
  final _bookingNote2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _siteName, _description, _currency, _supportContact, _telegramSupport, _telegramVip, _telegramVvip,
      _bookingLabel, _bookingCode, _bookingBookie, _bookingLink, _bookingNote,
      _bookingLabel2, _bookingCode2, _bookingBookie2, _bookingLink2, _bookingNote2,
    ]) {
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
      final res = await SupabaseService.client.from('site_settings').select('*').eq('id', 1).maybeSingle();
      if (res != null) {
        _siteName.text = res['site_name']?.toString() ?? '';
        _description.text = res['description']?.toString() ?? '';
        _currency.text = res['currency']?.toString() ?? 'GHS';
        _supportContact.text = res['support_contact']?.toString() ?? '';
        _telegramSupport.text = res['telegram_support_url']?.toString() ?? '';
        _telegramVip.text = res['telegram_vip_url']?.toString() ?? '';
        _telegramVvip.text = res['telegram_vvip_url']?.toString() ?? '';
        _bookingLabel.text = res['booking_label']?.toString() ?? '';
        _bookingCode.text = res['booking_code']?.toString() ?? '';
        _bookingBookie.text = res['booking_bookie']?.toString() ?? '';
        _bookingLink.text = res['booking_link']?.toString() ?? '';
        _bookingNote.text = res['booking_note']?.toString() ?? '';
        _bookingLabel2.text = res['booking_label_2']?.toString() ?? '';
        _bookingCode2.text = res['booking_code_2']?.toString() ?? '';
        _bookingBookie2.text = res['booking_bookie_2']?.toString() ?? '';
        _bookingLink2.text = res['booking_link_2']?.toString() ?? '';
        _bookingNote2.text = res['booking_note_2']?.toString() ?? '';
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
    if (_siteName.text.trim().isEmpty) {
      setState(() => _error = 'Site name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseService.client.from('site_settings').update({
        'site_name': _siteName.text.trim(),
        'description': _description.text.trim(),
        'currency': _currency.text.trim().isEmpty ? 'GHS' : _currency.text.trim(),
        'support_contact': _supportContact.text.trim(),
        'telegram_support_url': _telegramSupport.text.trim(),
        'telegram_vip_url': _telegramVip.text.trim(),
        'telegram_vvip_url': _telegramVvip.text.trim(),
        'booking_label': _bookingLabel.text.trim(),
        'booking_code': _bookingCode.text.trim(),
        'booking_bookie': _bookingBookie.text.trim(),
        'booking_link': _bookingLink.text.trim(),
        'booking_note': _bookingNote.text.trim(),
        'booking_label_2': _bookingLabel2.text.trim(),
        'booking_code_2': _bookingCode2.text.trim(),
        'booking_bookie_2': _bookingBookie2.text.trim(),
        'booking_link_2': _bookingLink2.text.trim(),
        'booking_note_2': _bookingNote2.text.trim(),
      }).eq('id', 1);
      if (mounted) snack(context, 'Settings saved');
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Settings',
            subtitle: 'Site-wide settings (row id = 1)',
            actions: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reload'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingBox()
          else if (_error != null && _siteName.text.isEmpty)
            errorCard(_error!, _load)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('General'),
                _row2(formField(_siteName, 'Site name *'), formField(_currency, 'Currency')),
                const SizedBox(height: 12),
                formField(_description, 'Description', multiline: true),
                const SizedBox(height: 12),
                formField(_supportContact, 'Support contact'),
                const SizedBox(height: 20),
                _sectionTitle('Telegram'),
                formField(_telegramSupport, 'Support group URL', hint: 'https://t.me/...'),
                const SizedBox(height: 12),
                formField(_telegramVip, 'VIP channel URL', hint: 'https://t.me/...'),
                const SizedBox(height: 12),
                formField(_telegramVvip, 'VVIP channel URL', hint: 'https://t.me/...'),
                const SizedBox(height: 20),
                _sectionTitle('Booking card 1'),
                _row2(formField(_bookingLabel, 'Label'), formField(_bookingBookie, 'Bookie')),
                const SizedBox(height: 12),
                _row2(formField(_bookingCode, 'Booking code'), formField(_bookingLink, 'Link')),
                const SizedBox(height: 12),
                formField(_bookingNote, 'Note', multiline: true),
                const SizedBox(height: 20),
                _sectionTitle('Booking card 2'),
                _row2(formField(_bookingLabel2, 'Label'), formField(_bookingBookie2, 'Bookie')),
                const SizedBox(height: 12),
                _row2(formField(_bookingCode2, 'Booking code'), formField(_bookingLink2, 'Link')),
                const SizedBox(height: 12),
                formField(_bookingNote2, 'Note', multiline: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save, size: 18),
                  label: const Text('Save settings'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(t, style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ]);
  }
}
