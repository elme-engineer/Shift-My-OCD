import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../models/tracked_object.dart';
import '../../services/qr_service.dart';
import '../export/qr_export_service.dart';

class ObjectQrScreen extends StatefulWidget {
  const ObjectQrScreen({super.key, required this.object});

  final TrackedObject object;

  @override
  State<ObjectQrScreen> createState() => _ObjectQrScreenState();
}

class _ObjectQrScreenState extends State<ObjectQrScreen> {
  final _qr = QrService();
  final _qrExport = QrExportService();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final object = widget.object;
    final payload = _qr.encode(object.id);
    final hasDesc = object.description.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(object.name),
        actions: [
          IconButton(
            tooltip: _exporting ? 'Exporting…' : 'Export QR to PDF',
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            onPressed: _exporting ? null : _onExport,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(iconFor(object.iconKey), size: 28),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      object.name,
                      style: theme.textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Description sits between the title and the QR code.
              if (hasDesc) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    object.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              // QR card holds the code on a white background so it
              // scans reliably even on a dark theme.
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: QrImageView(
                          data: payload,
                          version: QrVersions.auto,
                          gapless: true,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Print or screenshot this code and stick it on the '
                "${object.name.toLowerCase()}. Scan it whenever you "
                'physically check.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hands the current object to QrExportService for a single-page
  /// PDF (centered, large QR, name + description). 
  Future<void> _onExport() async {
    setState(() => _exporting = true);
    try {
      await _qrExport.exportSingle(widget.object);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Export failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}