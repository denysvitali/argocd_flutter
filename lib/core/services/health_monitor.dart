import 'dart:async';

import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/health_event.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AppSnapshot {
  const _AppSnapshot({
    required this.healthStatus,
    required this.syncStatus,
    required this.operationPhase,
  });

  final String healthStatus;
  final String syncStatus;
  final String operationPhase;
}

class HealthMonitor extends ChangeNotifier {
  HealthMonitor({
    required Future<void> Function() onRefreshRequested,
    Duration pollInterval = const Duration(minutes: 2),
  }) : _onRefreshRequested = onRefreshRequested,
       _pollInterval = pollInterval;

  final Future<void> Function() _onRefreshRequested;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final Map<String, _AppSnapshot> _previousState = <String, _AppSnapshot>{};
  final List<HealthEvent> _events = <HealthEvent>[];
  Timer? _timer;
  bool _enabled = false;
  bool _initialized = false;
  bool _pollInFlight = false;
  Duration _pollInterval;
  final Set<String> _mutedApps = <String>{};

  // Callback fired when new negative events are detected (for in-app alerts).
  void Function(List<HealthEvent> newEvents)? onNewEvents;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<HealthEvent> get events => List<HealthEvent>.unmodifiable(_events);
  bool get enabled => _enabled;
  bool get hasUnreadEvents => _events.any((HealthEvent e) => e.isNegative);
  int get unreadCount => _events.where((HealthEvent e) => e.isNegative).length;
  Duration get pollInterval => _pollInterval;
  Set<String> get mutedApps => Set<String>.unmodifiable(_mutedApps);
  bool get isPolling => _timer?.isActive ?? false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) {
      resume();
      return;
    }
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabledKey) ?? false;
      final intervalMinutes = prefs.getInt(_kIntervalKey) ?? 2;
      _pollInterval = Duration(minutes: intervalMinutes);
      final mutedList = prefs.getStringList(_kMutedKey) ?? <String>[];
      _mutedApps.addAll(mutedList);
    } on Exception {
      // Graceful fallback if SharedPreferences unavailable (e.g. in tests).
    }

    if (_enabled) {
      _startTimer();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Core: process applications and detect transitions
  // ---------------------------------------------------------------------------

  void processApplications(List<ArgoApplication> applications) {
    if (!_enabled) {
      // Still seed the baseline so toggling on later doesn't fire stale events.
      _seedBaseline(applications);
      return;
    }

    // First call: seed baseline without generating events.
    if (_previousState.isEmpty) {
      _seedBaseline(applications);
      return;
    }

    final newEvents = <HealthEvent>[];
    final now = DateTime.now();

    for (final app in applications) {
      final prev = _previousState[app.name];
      if (prev == null) {
        // New application — seed it, no event.
        _previousState[app.name] = _AppSnapshot(
          healthStatus: app.healthStatus,
          syncStatus: app.syncStatus,
          operationPhase: app.operationPhase,
        );
        continue;
      }

      if (_mutedApps.contains(app.name)) {
        _previousState[app.name] = _AppSnapshot(
          healthStatus: app.healthStatus,
          syncStatus: app.syncStatus,
          operationPhase: app.operationPhase,
        );
        continue;
      }

      // Health transitions
      final prevHealth = prev.healthStatus.toLowerCase();
      final currHealth = app.healthStatus.toLowerCase();
      if (prevHealth != currHealth) {
        if (currHealth == 'degraded') {
          newEvents.add(
            HealthEvent(
              applicationName: app.name,
              kind: HealthEventKind.degraded,
              previousValue: prev.healthStatus,
              currentValue: app.healthStatus,
              detectedAt: now,
            ),
          );
        } else if (currHealth == 'healthy' && prevHealth == 'degraded') {
          newEvents.add(
            HealthEvent(
              applicationName: app.name,
              kind: HealthEventKind.recovered,
              previousValue: prev.healthStatus,
              currentValue: app.healthStatus,
              detectedAt: now,
            ),
          );
        }
      }

      // Sync transitions
      final prevSync = prev.syncStatus.toLowerCase();
      final currSync = app.syncStatus.toLowerCase();
      if (prevSync != currSync) {
        if (currSync != 'synced') {
          newEvents.add(
            HealthEvent(
              applicationName: app.name,
              kind: HealthEventKind.drifted,
              previousValue: prev.syncStatus,
              currentValue: app.syncStatus,
              detectedAt: now,
            ),
          );
        } else if (currSync == 'synced' && prevSync != 'synced') {
          newEvents.add(
            HealthEvent(
              applicationName: app.name,
              kind: HealthEventKind.synced,
              previousValue: prev.syncStatus,
              currentValue: app.syncStatus,
              detectedAt: now,
            ),
          );
        }
      }

      // Operation phase transitions
      final prevOp = prev.operationPhase.toLowerCase();
      final currOp = app.operationPhase.toLowerCase();
      if (prevOp != currOp && currOp == 'failed') {
        newEvents.add(
          HealthEvent(
            applicationName: app.name,
            kind: HealthEventKind.operationFailed,
            previousValue: prev.operationPhase,
            currentValue: app.operationPhase,
            detectedAt: now,
          ),
        );
      }

      _previousState[app.name] = _AppSnapshot(
        healthStatus: app.healthStatus,
        syncStatus: app.syncStatus,
        operationPhase: app.operationPhase,
      );
    }

    // Remove apps that no longer exist.
    final currentNames = applications
        .map((ArgoApplication a) => a.name)
        .toSet();
    _previousState.removeWhere((String key, _) => !currentNames.contains(key));

    if (newEvents.isNotEmpty) {
      _events.insertAll(0, newEvents);
      // Cap at 50 events to prevent unbounded growth.
      if (_events.length > 50) {
        _events.removeRange(50, _events.length);
      }
      notifyListeners();

      final negativeEvents = newEvents
          .where((HealthEvent e) => e.isNegative)
          .toList(growable: false);
      if (negativeEvents.isNotEmpty) {
        onNewEvents?.call(negativeEvents);
      }
    }
  }

  void _seedBaseline(List<ArgoApplication> applications) {
    for (final app in applications) {
      _previousState[app.name] = _AppSnapshot(
        healthStatus: app.healthStatus,
        syncStatus: app.syncStatus,
        operationPhase: app.operationPhase,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Event management
  // ---------------------------------------------------------------------------

  void acknowledgeEvent(int index) {
    if (index >= 0 && index < _events.length) {
      _events.removeAt(index);
      notifyListeners();
    }
  }

  void acknowledgeAll() {
    if (_events.isNotEmpty) {
      _events.clear();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) {
      return;
    }
    _enabled = value;
    if (value) {
      _startTimer();
    } else {
      _stopTimer();
    }
    notifyListeners();
    _savePref(_kEnabledKey, value);
  }

  Future<void> setPollInterval(Duration interval) async {
    if (_pollInterval == interval) {
      return;
    }
    _pollInterval = interval;
    if (_timer?.isActive ?? false) {
      _stopTimer();
      _startTimer();
    }
    notifyListeners();
    _savePref(_kIntervalKey, interval.inMinutes);
  }

  Future<void> muteApp(String name) async {
    if (_mutedApps.add(name)) {
      notifyListeners();
      _saveMutedApps();
    }
  }

  Future<void> unmuteApp(String name) async {
    if (_mutedApps.remove(name)) {
      notifyListeners();
      _saveMutedApps();
    }
  }

  bool isAppMuted(String name) => _mutedApps.contains(name);

  void resume() {
    if (_enabled && !isPolling) {
      _startTimer();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_pollInFlight) {
      return;
    }
    _pollInFlight = true;
    try {
      await _onRefreshRequested();
    } catch (_) {
      // Poll failures should not crash the app or create unhandled async errors.
    } finally {
      _pollInFlight = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void reset() {
    _previousState.clear();
    _events.clear();
    _stopTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  static const _kEnabledKey = 'argocd.monitor.enabled';
  static const _kIntervalKey = 'argocd.monitor.interval_minutes';
  static const _kMutedKey = 'argocd.monitor.muted_apps';

  Future<void> _savePref(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      }
    } on Exception {
      // Best-effort persistence.
    }
  }

  Future<void> _saveMutedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kMutedKey, _mutedApps.toList());
    } on Exception {
      // Best-effort persistence.
    }
  }
}
