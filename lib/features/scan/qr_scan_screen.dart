import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../models/tracked_object.dart';
import '../../services/analytics_service.dart';
import '../../services/qr_service.dart';

/// Camera-based QR scanner using `mobile_scanner`.
///
/// Flow:
///   1. Detect a code
///   2. Decode via QrService — bail if it's not our payload
///   3. Look up the object by id
///   4. Log a tag_scan + show success
///
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  final _analytics = AnalyticsService();
  final _qr = QrService();

  // Guard so we don't process the same frame twice while the
  // success snackbar is animating in.
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        actions: [
          IconButton(
            tooltip: 'Toggle torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Visual reticle so users know where to aim.
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: const Text(
                'Aim at the QR code on the object you just checked.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || capture.barcodes.isEmpty) return;
    final raw = capture.barcodes.first.rawValue;
    final objectId = _qr.decode(raw);
    if (objectId == null) {
      _bumpInvalid();
      return;
    }

    _handling = true;
    await _controller.stop();

    try {
      final obj = await _analytics.findByTagId(objectId);
      if (obj == null) {
        _showError("That tag isn't registered to any object.");
        await _controller.start();
        _handling = false;
        return;
      }
      await _analytics.logTagScan(objectId: obj.id, source: 'qr');
      _haptic();
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(_successSnack(obj));
    } catch (e) {
      _showError("Couldn't save scan: $e");
      await _controller.start();
      _handling = false;
    }
  }

  // mobile_scanner fires onDetect very rapidly — debounce the
  // "not our QR" snackbar so we don't spam the user.
  DateTime _lastInvalidWarn = DateTime.fromMillisecondsSinceEpoch(0);
  void _bumpInvalid() {
    final now = DateTime.now();
    if (now.difference(_lastInvalidWarn).inSeconds < 2) return;
    _lastInvalidWarn = now;
    _showError('That QR code isn\'t a Shift My OCD tag.');
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _haptic() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 80);
    }
  }

  SnackBar _successSnack(TrackedObject obj) => SnackBar(
        content: Row(
          children: [
            Icon(iconFor(obj.iconKey), color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('${obj.name} checked ✓')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      );
}