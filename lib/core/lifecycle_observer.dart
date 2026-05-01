import 'package:flutter/widgets.dart';

import '../services/analytics_service.dart';

/// Hooks into the Flutter binding to log an `app_open` event each
/// time the app returns to the foreground.
///
/// Install once at app start, after Firebase + auth are ready:
///
///   final observer = LifecycleObserver(analytics);
///   WidgetsBinding.instance.addObserver(observer);
///   observer.logInitialOpen(); // count the cold start too
class LifecycleObserver with WidgetsBindingObserver {
  LifecycleObserver(this._analytics);

  final AnalyticsService _analytics;
  AppLifecycleState? _last;

  /// Call once after the binding is initialized so cold starts count.
  Future<void> logInitialOpen() => _analytics.logAppOpen();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBackgrounded = _last == AppLifecycleState.paused ||
        _last == AppLifecycleState.hidden ||
        _last == AppLifecycleState.inactive;
    if (state == AppLifecycleState.resumed && wasBackgrounded) {
      _analytics.logAppOpen();
    }
    _last = state;
  }
}