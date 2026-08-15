import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/config.dart';
import '../core/image_upload.dart';
import '../core/theme.dart';

class PageFrame extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  const PageFrame({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: maxWidth == null
                ? child
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth!),
                      child: child,
                    ),
                  ),
          ),
        );
      },
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

/// Icon-only refresh button used in page headers so the admin can reload
/// data manually when a connection drops and content fails to load.
class RefreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool enabled;
  const RefreshButton({super.key, required this.onPressed, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Refresh',
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.refresh, size: 20),
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

/// Image URL field with a live thumbnail preview so the admin can see the
/// image before posting. Relative paths are resolved against the admin API
/// base URL.
///
/// An optional [onPull] callback renders an extra "pull" button (next to the
/// pick-file button) that fetches an image URL from the web (e.g. a team
/// crest from TheSportsDB) and fills the field with it.
class ImageUrlField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final Future<String?> Function()? onPull;

  const ImageUrlField({super.key, required this.controller, required this.label, this.onPull});

  @override
  State<ImageUrlField> createState() => _ImageUrlFieldState();
}

class _ImageUrlFieldState extends State<ImageUrlField> {
  late String _url;
  bool _busy = false;
  bool _pulling = false;

  @override
  void initState() {
    super.initState();
    _url = widget.controller.text.trim();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final url = widget.controller.text.trim();
    if (url != _url) setState(() => _url = url);
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await ImageUpload.pickAndUpload();
      if (url != null && mounted) {
        widget.controller.text = url;
        _onChanged();
      }
    } catch (e) {
      if (mounted) snack(context, 'Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pull() async {
    if (_pulling || widget.onPull == null) return;
    setState(() => _pulling = true);
    try {
      final url = await widget.onPull!();
      if (url != null && url.isNotEmpty && mounted) {
        widget.controller.text = url;
        _onChanged();
      } else if (mounted) {
        snack(context, 'No crest found. Try the official team name.', error: true);
      }
    } catch (e) {
      if (mounted) snack(context, 'Pull failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  String? get _previewUrl {
    final url = _url;
    if (url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    final sep = url.startsWith('/') ? '' : '/';
    return '${AppConfig.adminApiBase}$sep$url';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: formField(widget.controller, widget.label, hint: 'https://...')),
        if (widget.onPull != null) ...[
          const SizedBox(width: 4),
          SizedBox(
            width: 36,
            height: 48,
            child: IconButton(
              tooltip: 'Pull image from web',
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
        const SizedBox(width: 4),
        SizedBox(
          width: 36,
          height: 48,
          child: IconButton(
            tooltip: 'Pick image file',
            padding: EdgeInsets.zero,
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open, size: 18, color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(width: 96, height: 48, child: _ImageThumb(url: _previewUrl)),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String? url;

  const _ImageThumb({this.url});

  @override
  Widget build(BuildContext context) {
    final u = url;
    return Container(
      width: 96,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: u == null
          ? const Icon(Icons.image_outlined, color: AppColors.muted, size: 18)
          : Image.network(
              u,
              width: 96,
              height: 48,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stack) => const Icon(
                Icons.broken_image_outlined,
                color: AppColors.red,
                size: 18,
              ),
            ),
    );
  }
}

/// Circular team crest thumbnail used in tables and forms. Resolves relative
/// URLs against the admin API base; falls back to the team's initials when
/// there is no URL or the image fails to load.
class CrestAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const CrestAvatar({super.key, required this.name, this.url, this.size = 32});

  String? get _resolved {
    final u = url;
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http')) return u;
    final sep = u.startsWith('/') ? '' : '/';
    return '${AppConfig.adminApiBase}$sep$u';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    return Tooltip(
      message: name,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: resolved == null
              ? _CrestInitials(name: name)
              : Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.surface2,
                      child: const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) => _CrestInitials(name: name),
                ),
        ),
      ),
    );
  }
}

class _CrestInitials extends StatelessWidget {
  final String name;
  const _CrestInitials({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
    return Container(
      color: AppColors.surface2,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
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

/// Custom minimize / maximize / close buttons for the frameless
/// window, driven through window_manager (same approach as SemFlix TV).
class WindowControls extends StatefulWidget {
  const WindowControls({super.key});

  @override
  State<WindowControls> createState() => _WindowControlsState();
}

class _WindowControlsState extends State<WindowControls> {
  bool _maximized = false;
  late final WindowListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = _WindowControlsListener(this);
    windowManager.addListener(_listener);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowControlButton(
          icon: Icons.remove_rounded,
          tooltip: 'Minimize',
          onTap: windowManager.minimize,
        ),
        _WindowControlButton(
          icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          tooltip: _maximized ? 'Restore' : 'Maximize',
          onTap: () {
            if (_maximized) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _WindowControlButton(
          icon: Icons.close_rounded,
          tooltip: 'Close',
          close: true,
          onTap: windowManager.close,
        ),
      ],
    );
  }
}

class _WindowControlsListener extends WindowListener {
  _WindowControlsListener(this.state);

  final _WindowControlsState state;

  @override
  void onWindowMaximize() {
    if (state.mounted) state.setState(() => state._maximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (state.mounted) state.setState(() => state._maximized = false);
  }
}

class _WindowControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool close;
  final VoidCallback onTap;

  const _WindowControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.close = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          icon: Icon(icon, size: 17, color: AppColors.muted),
          hoverColor: close ? const Color(0xFFD63A3A) : AppColors.surface2,
          onPressed: onTap,
        ),
      ),
    );
  }
}
