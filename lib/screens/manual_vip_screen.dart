import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

/// Temporary console for the manual / Telegram payment flow.
///
/// While Site Settings -> Payments is on "Manual via Telegram", the site logs a
/// pending row here instead of calling Paystack. The admin confirms the money
/// arrived out-of-band, then approves, which writes the same payment +
/// subscription pair the Paystack webhook would have written.
class ManualVipScreen extends StatefulWidget {
  const ManualVipScreen({super.key});

  @override
  State<ManualVipScreen> createState() => _ManualVipScreenState();
}

class _ManualVipScreenState extends State<ManualVipScreen> {
  bool _loading = true;
  bool _directBusy = false;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  Map<String, Map<String, dynamic>> _profiles = {};
  Map<String, Map<String, dynamic>> _plans = {};
  final Set<String> _busy = {};
  bool _manualMode = false;
  bool _modeSaving = false;
  String _waNumber = '';

  /// Which automatic gateway to hand back to when manual mode is switched off.
  /// Without this the switch would silently reset a SikaPay selection back to
  /// Paystack, because both live in the payments_manual_mode column.
  String _payMethod = 'paystack';

  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _ref() {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final tail = Random().nextInt(0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
    return 'MANUAL_${stamp}_$tail';
  }

  Map<String, dynamic>? _planFor(dynamic planId) => _plans[planId.toString()];

  Map<String, dynamic>? _profileFor(dynamic userId) => _profiles[userId.toString()];

  /// Reads a field as text, tolerating a missing row or a null column.
  static String _s(Map<String, dynamic>? row, String key) {
    if (row == null) return '';
    return row[key]?.toString() ?? '';
  }

  /// Best available label for a user: full name, else email, else the id.
  static String _label(Map<String, dynamic>? profile, String fallbackId) {
    final name = _s(profile, 'full_name');
    if (name.isNotEmpty) return name;
    final mail = _s(profile, 'email');
    return mail.isNotEmpty ? mail : fallbackId;
  }

  /// Only VIP is grantable for now; VVIP has no plan row in the database.
  Map<String, dynamic>? get _vipPlan {
    for (final p in _plans.values) {
      if ((p['slug']?.toString().toLowerCase() ?? '') == 'vip') return p;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reqs = await SupabaseService.client
          .from('vip_requests')
          .select('*')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(300);

      final profiles = await SupabaseService.client.from('profiles').select('id,full_name,email');
      final plans = await SupabaseService.client
          .from('prediction_plans')
          .select('id,name,slug,price,currency,duration_days,is_active');

      final settings = await SupabaseService.client
          .from('site_settings')
          .select('payments_manual_mode,whatsapp_payment_number')
          .eq('id', 1)
          .maybeSingle();

      final pMap = <String, Map<String, dynamic>>{};
      for (final r in profiles.cast<Map<String, dynamic>>()) {
        pMap[r['id'].toString()] = r;
      }
      final planMap = <String, Map<String, dynamic>>{};
      for (final p in plans.cast<Map<String, dynamic>>()) {
        planMap[p['id'].toString()] = p;
      }

      setState(() {
        _requests = reqs.cast<Map<String, dynamic>>();
        _profiles = pMap;
        _plans = planMap;
        if (settings != null) {
          final v = (settings['payments_manual_mode']?.toString() ?? 'off').trim().toLowerCase();
          _manualMode = v == 'on';
          _payMethod = v == 'sikapay' ? 'sikapay' : 'paystack';
          _waNumber = settings['whatsapp_payment_number']?.toString() ?? '';
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

  /// Flips the site-wide manual payment switch. Writes the same
  /// site_settings row as the website's Settings page and the app's Settings
  /// screen, so all three stay in agreement.
  ///
  /// Switching back off restores whichever automatic gateway was previously
  /// selected rather than hardcoding Paystack.
  Future<void> _setManualMode(bool value) async {
    if (value && _waNumber.trim().isEmpty) {
      if (mounted) snack(context, 'Add a Telegram chat first (Settings > Payments)');
      return;
    }
    setState(() => _modeSaving = true);
    try {
      await SupabaseService.client.from('site_settings').update({
        'payments_manual_mode': value ? 'on' : _payMethod,
      }).eq('id', 1);
      if (mounted) {
        setState(() => _manualMode = value);
        final gateway = _payMethod == 'sikapay' ? 'SikaPay (Moolre)' : 'Paystack';
        snack(context, value
            ? 'Manual mode ON — site collects payment via Telegram'
            : 'Manual mode OFF — site uses $gateway');
      }
    } catch (e) {
      if (mounted) snack(context, 'Could not change mode: $e');
    } finally {
      if (mounted) setState(() => _modeSaving = false);
    }
  }

  /// Writes the payment + subscription pair, mirroring
  /// activate_subscription_from_reference() on the site: entitlement first,
  /// keyed on the payment reference so a retry cannot double-grant.
  Future<String> _activate({
    required String userId,
    required Map<String, dynamic> plan,
    String? requestReference,
  }) async {
    final days = _num(plan['duration_days']).round();
    final start = DateTime.now().toUtc();
    final end = start.add(Duration(days: days <= 0 ? 1 : days));
    final reference = _ref();

    // The payment is written as 'pending' first and only flipped to 'success'
    // once the subscription exists. Marking it paid up front leaves a payment
    // that claims money was taken while granting no access if the subscription
    // insert fails, which corrupts revenue reporting.
    await SupabaseService.client.from('payments').insert({
      'user_id': userId,
      'plan_id': plan['id'],
      'amount': _num(plan['price']),
      'currency': plan['currency']?.toString() ?? 'GHS',
      'reference': reference,
      'status': 'pending',
      'gateway': 'manual',
      'paid_at': start.toIso8601String(),
      'metadata': {
        'method': 'manual_whatsapp',
        'request_reference': requestReference ?? '',
        'activated_by': SupabaseService.user?.id ?? '',
      },
    });

    final sub = await SupabaseService.client.from('subscriptions').insert({
      'user_id': userId,
      'plan_id': plan['id'],
      'status': 'active',
      'start_date': start.toIso8601String(),
      'end_date': end.toIso8601String(),
      'payment_reference': reference,
    }).select('id').single();

    // Entitlement exists, so the payment can now be treated as settled.
    await SupabaseService.client
        .from('payments')
        .update({'status': 'success'})
        .eq('reference', reference);

    final subId = sub['id'];

    // Keep one live subscription per user, matching the Paystack path.
    await SupabaseService.client
        .from('subscriptions')
        .update({'status': 'expired'})
        .eq('user_id', userId)
        .eq('status', 'active')
        .neq('id', subId);

    return end.toIso8601String();
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    final id = req['id'].toString();
    final ref = req['reference']?.toString() ?? '';
    final plan = _planFor(req['plan_id']);
    final profile = _profileFor(req['user_id']);
    final email = _label(profile, req['user_id'].toString());
    final days = plan == null ? 0 : _num(plan['duration_days']).round();

    if (plan == null) {
      snack(context, 'The plan for this request no longer exists.', error: true);
      return;
    }
    if (!await confirmDialog(
      context,
      'Confirm payment received',
      'Only approve after the money has actually arrived on your side.\n\n'
      'User: $email\n'
      'Plan: ${plan['name']} ($days day(s))\n'
      'Request: $ref\n\n'
      'This records a manual payment and activates VIP until '
      '${fmtDate(DateTime.now().toUtc().add(Duration(days: days <= 0 ? 1 : days)).toIso8601String())}.',
    )) {
      return;
    }

    setState(() => _busy.add(id));
    try {
      // Optimistic claim: only one admin can take a pending row.
      final claimed = await SupabaseService.client
          .from('vip_requests')
          .update({'status': 'approved', 'resolved_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('status', 'pending')
          .select('id');
      if (claimed.isEmpty) {
        if (mounted) snack(context, 'That request was already handled.', error: true);
        return;
      }

      try {
        final end = await _activate(
          userId: req['user_id'].toString(),
          plan: plan,
          requestReference: ref,
        );

        await SupabaseService.client.from('vip_requests').update({'resolved_by': SupabaseService.user?.id}).eq('id', id);

        // Best effort: never let a failed notice undo a real activation.
        try {
          await SupabaseService.client.from('notifications').insert({
            'user_id': req['user_id'],
            'audience': 'all',
            'message': 'Your ${plan['name']} subscription is active. Thanks for your payment!',
            'link': '/profile.php',
          });
        } catch (_) {}

        if (mounted) {
          snack(context, 'VIP activated for $email until ${fmtDate(end)}');
        }
      } catch (e) {
        // Put the request back in the queue so it is not silently lost.
        await SupabaseService.client
            .from('vip_requests')
            .update({'status': 'pending', 'resolved_at': null})
            .eq('id', id);
        if (mounted) snack(context, 'Activation failed: $e', error: true);
      }
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy.remove(id));
        _load();
      }
    }
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final id = req['id'].toString();
    final email = _label(_profileFor(req['user_id']), 'this user');
    if (!await confirmDialog(context, 'Reject request', 'Reject the request from $email?')) return;

    setState(() => _busy.add(id));
    try {
      await SupabaseService.client.from('vip_requests').update({
        'status': 'rejected',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'resolved_by': SupabaseService.user?.id,
      }).eq('id', id);
      if (mounted) snack(context, 'Request rejected');
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) {
        setState(() => _busy.remove(id));
        _load();
      }
    }
  }

  Future<void> _directGrant() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    final plan = _vipPlan;
    if (plan == null) {
      snack(context, 'No VIP plan found.', error: true);
      return;
    }

    setState(() => _directBusy = true);
    try {
      final found = await SupabaseService.client.from('profiles').select('id,full_name,email').ilike('email', email).limit(1);
      if (found.isEmpty) {
        if (mounted) snack(context, 'No account with that email.', error: true);
        return;
      }
      final profile = found.first;

      final days = _num(plan['duration_days']).round();
      if (!await confirmDialog(
        context,
        'Grant VIP directly',
        'Grant ${plan['name']} to ${profile['email']} with no payment request on file.\n\n'
        'Only use this for payments taken outside the site.\n\n'
        'Duration: $days day(s), from the plan settings.',
      )) {
        return;
      }

      final end = await _activate(userId: profile['id'].toString(), plan: plan);
      if (mounted) {
        snack(context, 'VIP granted to ${profile['email']} until ${fmtDate(end)}');
        _emailCtrl.clear();
      }
    } catch (e) {
      if (mounted) snack(context, 'Grant failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _directBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _vipPlan;
    final days = plan == null ? 0 : _num(plan['duration_days']).round();

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Manual VIP',
            subtitle: 'Confirm Telegram / offline payments and activate VIP by hand',
            actions: [
              RefreshButton(onPressed: _load, enabled: !_loading),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _manualMode ? AppColors.gold.withValues(alpha: 0.12) : AppColors.surface,
              border: Border.all(
                color: _manualMode ? AppColors.gold : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _manualMode,
              onChanged: _modeSaving ? null : _setManualMode,
              title: Text(
                _manualMode ? 'Manual mode is ON' : 'Manual mode is OFF',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _manualMode ? AppColors.gold : null,
                ),
              ),
              subtitle: Text(
                _manualMode
                    ? 'The site is collecting payment over Telegram. Requests land below.'
                    : 'The site is taking automatic payments. Turn this on to accept Telegram payments.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
              ),
            ),
          ),
          if (_manualMode && _waNumber.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'No Telegram chat set — add one in Settings > Payments.',
                style: const TextStyle(color: AppColors.red, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Grants follow the VIP plan duration (currently $days day(s), change it in Plans). '
                    'Only approve after the payment has actually cleared on your side.',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LoadingBox()
          else if (_error != null)
            errorCard(_error!, _load)
          else if (_requests.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 34),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 30, color: AppColors.muted),
                  SizedBox(height: 10),
                  Text('No pending requests.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  SizedBox(height: 4),
                  Text('Requests from the site appear here as soon as a customer starts checkout.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            )
          else
            AppTable(
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Plan')),
                DataColumn(label: Text('Reference')),
                DataColumn(label: Text('Requested')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _requests.map((r) {
                      final profile = _profileFor(r['user_id']);
                      final name = _label(profile, r['user_id'].toString());
                      final email = _s(profile, 'email');
                      final rPlan = _planFor(r['plan_id']);
                      final planName = _s(rPlan, 'name');
                      final busy = _busy.contains(r['id'].toString());
                      return DataRow(
                        cells: [
                          DataCell(SizedBox(
                            width: 240,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(email.isEmpty ? '—' : email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          )),
                          DataCell(Text(planName.isEmpty ? 'Unknown plan' : planName)),
                          DataCell(Text(r['reference']?.toString() ?? '—',
                              style: const TextStyle(fontSize: 12))),
                          DataCell(Text(fmtDate(r['created_at']?.toString(), time: true))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: SizedBox(
                                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              else ...[
                                IconButton(
                                  tooltip: 'Payment received — activate VIP',
                                  icon: const Icon(Icons.check_circle_outline, size: 19, color: AppColors.green),
                                  onPressed: () => _approve(r),
                                ),
                                IconButton(
                                  tooltip: 'Reject',
                                  icon: const Icon(Icons.cancel_outlined, size: 19, color: AppColors.red),
                                  onPressed: () => _reject(r),
                                ),
                              ],
                            ],
                          )),
                        ],
                      );
                    }).toList(),
            ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Grant without a request',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'For payments taken outside the site (no request logged).',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 320,
                        child: TextField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'User email', prefixIcon: Icon(Icons.alternate_email)),
                          onSubmitted: (_) => _directGrant(),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _directBusy ? null : _directGrant,
                        icon: _directBusy
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.workspace_premium_outlined, size: 18),
                        label: Text('Grant VIP ($days day${days == 1 ? '' : 's'})'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
