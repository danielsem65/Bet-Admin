import 'package:flutter/material.dart';

import '../core/theme.dart';

class PageFrame extends StatelessWidget {
  final Widget child;
  const PageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

/// DataTable wrapped in a horizontal scrollbar so wide tables never get
/// squeezed (which is what makes text wrap vertically).
class AppTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  const AppTable({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(columns: columns, rows: rows),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  const ScreenHeader({super.key, required this.title, this.subtitle, this.actions});

  @override
  Widget build(BuildContext context) {
    final hasActions = actions != null && actions!.isNotEmpty;
    final titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ],
    );
    if (!hasActions) return titleCol;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final actionRow = Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: actions!);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleCol),
              const SizedBox(width: 16),
              actionRow,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleCol,
            const SizedBox(height: 12),
            actionRow,
          ],
        );
      },
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String message) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  return res ?? false;
}

void snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.red : AppColors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Widget formField(TextEditingController controller, String label, {bool multiline = false, String? hint}) {
  return TextField(
    controller: controller,
    maxLines: multiline ? 4 : 1,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

Widget errorCard(String message, VoidCallback onRetry) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
    ),
    child: Column(
      children: [
        const Icon(Icons.error_outline, color: AppColors.red, size: 32),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.red)),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: const Text('Retry')),
      ],
    ),
  );
}

class LoadingBox extends StatelessWidget {
  const LoadingBox({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
