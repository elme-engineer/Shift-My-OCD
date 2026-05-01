import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../models/tracked_object.dart';
import '../../services/analytics_service.dart';
import 'object_qr_screen.dart';

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key});

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  final _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tagged objects')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add object'),
      ),
      body: StreamBuilder<List<TrackedObject>>(
        stream: _analytics.watchObjects(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text("Couldn't load objects.\n${snap.error}"),
              ),
            );
          }
          final items = snap.data ?? const <TrackedObject>[];
          if (items.isEmpty) return _EmptyState(onAdd: _openAddSheet);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.xl * 3, // clear the FAB
            ),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _ObjectCard(
              object: items[i],
              onTap: () => _openQr(items[i]),
              onDelete: () => _confirmDelete(items[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddObjectSheet(analytics: _analytics),
    );
  }

  Future<void> _openQr(TrackedObject obj) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ObjectQrScreen(object: obj)),
    );
  }

  Future<void> _confirmDelete(TrackedObject obj) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${obj.name}"?'),
        content: const Text(
          'Past scan history stays in your event log. '
          'Only this tag is removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await _analytics.deleteObject(obj.id);
  }
}

// --- card ------------------------------------------------------------

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({
    required this.object,
    required this.onTap,
    required this.onDelete,
  });
  final TrackedObject object;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDesc = object.description.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconFor(object.iconKey),
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      object.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Description shown only when user provided one.
                    if (hasDesc) ...[
                      const SizedBox(height: 2),
                      Text(
                        object.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      _lastCheckedLabel(object.lastCheckedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _openMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('Show QR'),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _lastCheckedLabel(DateTime? when) {
    if (when == null) return 'Never checked';
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'Checked just now';
    if (diff.inMinutes < 60) return 'Checked ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Checked ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Checked ${diff.inDays}d ago';
    return 'Checked ${DateFormat.yMMMd().format(when)}';
  }
}

// --- empty state -----------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text('No objects yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tag the things you check most — front door, stove, '
              'iron — then scan them when you check.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first object'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- add sheet -------------------------------------------------------

class _AddObjectSheet extends StatefulWidget {
  const _AddObjectSheet({required this.analytics});
  final AnalyticsService analytics;

  @override
  State<_AddObjectSheet> createState() => _AddObjectSheetState();
}

class _AddObjectSheetState extends State<_AddObjectSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _iconKey = kIconCatalog.keys.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // lift above the keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add an object', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Front Door',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Give it a name';
                  if (t.length > 40) return 'Keep it under 40 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. "Main lock + deadbolt — both must be turned"',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) {
                  // Optional field — only validate length.
                  if ((v?.length ?? 0) > 200) return 'Keep it under 200 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Icon', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final e in kIconCatalog.entries)
                    ChoiceChip(
                      avatar: Icon(e.value, size: 20),
                      label: Text(e.key),
                      selected: e.key == _iconKey,
                      onSelected: (_) => setState(() => _iconKey = e.key),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Save object'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.analytics.createObject(
        name: _nameCtrl.text,
        description: _descCtrl.text, // service trims it
        iconKey: _iconKey,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't save: $e")),
        );
      }
    }
  }
}