import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/subscription.dart';
import '../services/database_service.dart';
import '../utils/subscription_schedule.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({
    DatabaseService? dbService,
    bool watchDatabase = true,
    Future<void> Function(List<Subscription>)? onSubscriptionsChanged,
  }) : _dbService = dbService ?? DatabaseService.instance,
       _onSubscriptionsChanged = onSubscriptionsChanged {
    if (watchDatabase) {
      _changeSubscription = _dbService.onDatabaseChanged.listen((_) {
        if (_isDisposed) return;
        _reloadTimer?.cancel();
        _reloadTimer = Timer(
          const Duration(milliseconds: 150),
          () => unawaited(reload()),
        );
      });
    }
  }

  final DatabaseService _dbService;
  final Future<void> Function(List<Subscription>)? _onSubscriptionsChanged;

  StreamSubscription<String>? _changeSubscription;
  Timer? _reloadTimer;
  Future<void>? _reloadFuture;
  Future<void> _reminderQueue = Future<void>.value();
  bool _reloadQueued = false;
  bool _isDisposed = false;
  bool _isLoading = true;

  List<Subscription> _subscriptions = const [];
  List<Subscription> _activeSubscriptions = const [];
  List<Subscription> _upcomingSubscriptions = const [];
  List<Subscription> _overdueSubscriptions = const [];
  List<Subscription> _pausedSubscriptions = const [];
  final Map<String, Subscription> _subscriptionById = {};

  bool get isLoading => _isLoading;
  List<Subscription> get subscriptions => _subscriptions;
  List<Subscription> get activeSubscriptions => _activeSubscriptions;
  List<Subscription> get upcomingSubscriptions => _upcomingSubscriptions;
  List<Subscription> get overdueSubscriptions => _overdueSubscriptions;
  List<Subscription> get pausedSubscriptions => _pausedSubscriptions;
  int get activeCount => _activeSubscriptions.length;
  Subscription? get nextSubscription =>
      _activeSubscriptions.isEmpty ? null : _activeSubscriptions.first;

  Subscription? subscriptionById(String? id) =>
      id == null ? null : _subscriptionById[id];

  Future<void> load() async {
    _reloadTimer?.cancel();
    await reload();
  }

  Future<void> reload() async {
    if (_isDisposed) return;
    if (_reloadFuture != null) {
      _reloadQueued = true;
      return _reloadFuture;
    }

    final future = _performLoad();
    _reloadFuture = future;
    try {
      await future;
    } finally {
      _reloadFuture = null;
      if (_reloadQueued && !_isDisposed) {
        _reloadQueued = false;
        await reload();
      }
    }
  }

  Future<void> _performLoad() async {
    final subscriptions = await _dbService.getSubscriptions();
    if (_isDisposed) return;

    subscriptions.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    _subscriptions = subscriptions;
    _subscriptionById
      ..clear()
      ..addEntries(subscriptions.map((item) => MapEntry(item.id, item)));

    final active = <Subscription>[];
    final upcoming = <Subscription>[];
    final overdue = <Subscription>[];
    final paused = <Subscription>[];
    final now = DateTime.now();

    for (final subscription in subscriptions) {
      if (!subscription.isActive) {
        paused.add(subscription);
        continue;
      }
      active.add(subscription);
      if (SubscriptionSchedule.isOverdue(subscription.nextDueDate, now: now)) {
        overdue.add(subscription);
      } else {
        upcoming.add(subscription);
      }
    }

    _activeSubscriptions = active;
    _upcomingSubscriptions = upcoming;
    _overdueSubscriptions = overdue;
    _pausedSubscriptions = paused;
    _isLoading = false;
    notifyListeners();
    _queueReminderSync();
  }

  void _queueReminderSync() {
    _reminderQueue = _reminderQueue.then((_) => _syncReminders());
    unawaited(_reminderQueue);
  }

  Future<void> _syncReminders() async {
    final callback = _onSubscriptionsChanged;
    if (callback == null) return;
    try {
      await callback(_subscriptions);
    } catch (_) {
      return;
    }
  }

  Future<Subscription> addSubscription(Subscription subscription) async {
    await _dbService.addSubscription(subscription);
    await reload();
    return subscription;
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await _dbService.updateSubscription(subscription);
    await reload();
  }

  Future<void> setActive(String id, bool isActive) async {
    final subscription = _subscriptionById[id];
    if (subscription == null) return;
    await updateSubscription(subscription.copyWith(isActive: isActive));
  }

  Future<void> deleteSubscription(String id) async {
    await _dbService.deleteSubscription(id);
    await reload();
  }

  Future<Subscription?> markPaid(Subscription subscription) async {
    final updated = await _dbService.markSubscriptionPaid(
      subscription.id,
      expectedDueDate: subscription.nextDueDate,
    );
    if (updated != null) {
      await reload();
    }
    return updated;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reloadTimer?.cancel();
    _changeSubscription?.cancel();
    super.dispose();
  }
}
