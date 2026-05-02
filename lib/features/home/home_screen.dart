import 'package:flutter/material.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../models/event_log.dart';
import '../../models/tracked_object.dart';
import '../../services/analytics_service.dart';
import '../analytics/analytics_screen.dart';
import '../objects/objects_screen.dart';
import '../scan/qr_scan_screen.dart';
import '../scan/nfc_scan_screen.dart';

/// Root screen post-auth. Owns the bottom navigation (Dashboard /
/// Objects / Analytics) and renders the dashboard inline as the
/// first tab. Scan is launched as a full-screen route from buttons.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // IndexedStack so each tab keeps its state — Analytics in
  // particular shouldn't refetch + re-aggregate on every switch.
  static const _tabs = <Widget>[
    _DashboardTab(),
    ObjectsScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Objects',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
        ],
      ),
    );
  }
}

// --- Dashboard tab ---------------------------------------------------

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _analytics = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift My OCD')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GreetingCard(),
              const SizedBox(height: AppSpacing.md),
              _ScanCta(onTap: _openScanner),
              const SizedBox(height: AppSpacing.md),
              _NfcCta(onTap: _openNfcReader),
              const SizedBox(height: AppSpacing.md),
              _RecentActivity(analytics: _analytics),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
  }

  Future<void> _openNfcReader() async{
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const NfcScanScreen())
    );
  }

}

class _GreetingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'When the urge to check hits, scan the object instead.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NfcCta extends StatelessWidget{
    const _NfcCta({required this.onTap});
    final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              Icons.nfc_rounded,
              size: 36,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Put the phone close to check the tag',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Check a NFC tag.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }

}

class _ScanCta extends StatelessWidget {
  const _ScanCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 36,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan to check in',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Confirm a real check rather than re-opening the app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.analytics});
  final AnalyticsService analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                'Recent activity',
                style: theme.textTheme.titleMedium,
              ),
            ),
            // Outer stream: objects (small, rarely changes).
            // We index them by id so the inner builder can resolve
            // each tag_scan event to its real-world name + icon
            // without N round trips to Firestore.
            StreamBuilder<List<TrackedObject>>(
              stream: analytics.watchObjects(),
              builder: (context, objSnap) {
                final objectsById = {
                  for (final o in (objSnap.data ?? const <TrackedObject>[]))
                    o.id: o,
                };
                return StreamBuilder<List<EventLog>>(
                  stream: analytics.watchEvents(limit: 8),
                  builder: (context, evSnap) {
                    if (!evSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: LinearProgressIndicator(),
                      );
                    }
                    final events = evSnap.data!;
                    if (events.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Nothing logged yet. Add an object and scan it to start.',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final e in events)
                          _eventTile(e, objectsById[e.objectId]),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a tile for an event. For tag_scan events we look up the
  /// matching [TrackedObject] (may be null if it was deleted) so we
  /// can render the actual name + icon instead of generic copy.
  Widget _eventTile(EventLog e, TrackedObject? obj) {
    final isOpen = e.type == EventType.appOpen;

    final IconData icon;
    final String title;
    if (isOpen) {
      icon = Icons.phone_android;
      title = 'App opened';
    } else if (obj != null) {
      icon = iconFor(obj.iconKey);
      title = '${obj.name} checked';
    } else {
      // Object existed when scanned but has since been deleted.
      icon = Icons.task_alt;
      title = 'Object checked';
    }

    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(_relative(e.timestamp)),
    );
  }

  static String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}