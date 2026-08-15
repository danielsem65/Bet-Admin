import 'package:flutter/material.dart';

import 'theme.dart';

String money(num n, {String symbol = 'GHS'}) => '$symbol ${n.toStringAsFixed(2)}';

String _pad(int n) => n.toString().padLeft(2, '0');

String fmtDate(String? iso, {bool time = false}) {
  if (iso == null || iso.isEmpty) return '—';
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return '—';
  final d = '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  if (!time) return d;
  return '$d ${_pad(dt.hour)}:${_pad(dt.minute)}';
}

Widget badge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
    ),
  );
}

Widget categoryBadge(String c) {
  final color = switch (c.toUpperCase()) {
    'FREE' => AppColors.green,
    'VIP' => AppColors.gold,
    'VVIP' => AppColors.purple,
    _ => AppColors.blue,
  };
  return badge(c, color);
}

Widget statusBadge(String s) {
  final color = switch (s.toLowerCase()) {
    'won' => AppColors.green,
    'lost' => AppColors.red,
    'void' => AppColors.blue,
    'pending' => AppColors.muted,
    _ => AppColors.muted,
  };
  return badge(s, color);
}

Widget payStatusBadge(String s) {
  final color = switch (s.toLowerCase()) {
    'success' => AppColors.green,
    'pending' => AppColors.gold,
    'abandoned' => AppColors.blue,
    'failed' => AppColors.red,
    _ => AppColors.muted,
  };
  return badge(s, color);
}
