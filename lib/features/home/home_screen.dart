import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../models/tracked_object.dart';
import '../../services/analytics_service.dart';
import '../analytics/analytics_screen.dart';
import '../objects/objects_screen.dart';
import '../scan/nfc_scan_screen.dart';
import '../scan/qr_scan_screen.dart';

/// Root screen post-auth. Owns the bottom navigation (Home / Tags /
/// Profile) and renders the dashboard inline as the first tab.
/// Scan is launched as a full-screen route from the dashboard CTAs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

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
            icon: Icon(Icons.crop_free_outlined),
            selectedIcon: Icon(Icons.crop_free_rounded),
            label: 'Tags',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_sharp),
            label: 'Profile',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GreetingCard(),
              const SizedBox(height: AppSpacing.md),
              _ScanCta(onTap: _openScanner),
              const SizedBox(height: AppSpacing.md),
              _NfcCta(onTap: _openNfcReader),
              const SizedBox(height: AppSpacing.md),
              _LastChecked(analytics: _analytics),
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

  Future<void> _openNfcReader() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NfcScanScreen()),
    );
  }
}

// --- greeting + logo -------------------------------------------------

class _GreetingCard extends StatelessWidget {
  const _GreetingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning User'
        : hour < 18
            ? 'Good afternoon User'
            : 'Good evening User';

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Scan the objects to complete the tasks.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const _AppLogo(),
        ],
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Image.asset(
        'assets/images/DomoLogo.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

// --- CTAs ------------------------------------------------------------

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

class _NfcCta extends StatelessWidget {
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

// --- last checked ----------------------------------------------------
class _LastChecked extends StatelessWidget {
  const _LastChecked({required this.analytics});
  final AnalyticsService analytics;

  static const _maxItems = 5;

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
                'Last checked',
                style: theme.textTheme.titleMedium,
              ),
            ),
            StreamBuilder<List<TrackedObject>>(
              stream: analytics.watchObjects(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: LinearProgressIndicator(),
                  );
                }

                // Filter to objects with a check timestamp, sort by
                // most recent first, take top N.
                final checked = snap.data!
                    .where((o) => o.lastCheckedAt != null)
                    .toList()
                  ..sort((a, b) =>
                      b.lastCheckedAt!.compareTo(a.lastCheckedAt!));
                final top = checked.take(_maxItems).toList();

                if (top.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Nothing checked yet. Scan an object to start.',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }

                return Column(
                  children: [for (final o in top) _objectTile(o)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _objectTile(TrackedObject obj) {
    return ListTile(
      dense: true,
      leading: Icon(iconFor(obj.iconKey)),
      title: Text(obj.name),
      subtitle: Text(_relative(obj.lastCheckedAt!)),
    );
  }

  static String _relative(DateTime? t) {
    if (t == null) return 'Never checked';
    return 'Checked ${DateFormat.yMMMd().add_jm().format(t)}';
  }

}