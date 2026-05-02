import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../models/tracked_object.dart';
import '../../services/analytics_service.dart';
import '../../services/nfc_service.dart';

class NfcScanScreen extends StatefulWidget {
  const NfcScanScreen({super.key});

  @override
  State<NfcScanScreen> createState() => _NfcScanScreenState();
}

class _NfcScanScreenState extends State<NfcScanScreen> {
  final _nfc = NfcService();
  final _analytics = AnalyticsService();

  bool _available = false;
  bool _checking = true;
  String _status = 'Hold an NFC tag near the back of your phone.';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _nfc.stop();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await _nfc.isAvailable();
    if (!mounted) return;
    setState(() {
      _available = ok;
      _checking = false;
      _status = ok
          ? 'Hold an NFC tag near the back of your phone.'
          : 'NFC is unavailable on this device.';
    });
    if (!ok) return;
    await _nfc.startSession(
      onTagId: _handleTag,
      onError: (e) {
        if (!mounted) return;
        setState(() => _status = 'NFC error: $e');
      },
    );
  }

  Future<void> _handleTag(String tagId) async {
    final obj = await _analytics.findByTagId(tagId);
    if (obj != null) {
      await _analytics.logTagScan(objectId: obj.id, source: 'nfc');
      await _haptic();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${obj.name} checked ✓')),
      );
      return;
    }
    // Unknown tag — let the user pin it to one of their objects.
    if (!mounted) return;
    final picked = await showModalBottomSheet<TrackedObject>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickObjectSheet(stream: _analytics.watchObjects()),
    );
    if (picked != null) {
      await _analytics.attachNfcTag(objectId: picked.id, nfcTagId: tagId);
      await _analytics.logTagScan(objectId: picked.id, source: 'nfc');
      await _haptic();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.name} linked + checked ✓')),
      );
    } else {
      // User dismissed — restart the session for another try.
      await _nfc.startSession(onTagId: _handleTag);
    }
  }

  Future<void> _haptic() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 80);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NFC scan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_checking)
                const CircularProgressIndicator()
              else
                Icon(
                  _available ? Icons.nfc : Icons.signal_wifi_off,
                  size: 96,
                  color: _available
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(_status, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickObjectSheet extends StatelessWidget {
  const _PickObjectSheet({required this.stream});
  final Stream<List<TrackedObject>> stream;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<TrackedObject>>(
        stream: stream,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final items = snap.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Which object is this tag for?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('Add an object first, then come back.'),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final obj in items)
                        ListTile(
                          leading: Icon(iconFor(obj.iconKey)),
                          title: Text(obj.name),
                          onTap: () => Navigator.of(context).pop(obj),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}