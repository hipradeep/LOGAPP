import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/finance_controller.dart';
import '../controllers/sms_inbox_controller.dart';
import '../controllers/subscription_controller.dart';
import '../models/sms_record.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_navigation.dart';
import 'budget_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'sms_inbox_screen.dart';
import 'transaction_log_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  StreamSubscription<SmsValidationTarget>? _smsTargetSubscription;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2).toInt();
    WidgetsBinding.instance.addObserver(this);
    if (getIt.isRegistered<SmsInboxController>()) {
      final smsController = getIt<SmsInboxController>();
      unawaited(smsController.initialize());
      _smsTargetSubscription = smsController.validationTargets.listen(
        _openSmsTarget,
        onError: (_) {},
      );
    }
  }

  @override
  void dispose() {
    _smsTargetSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (getIt.isRegistered<SubscriptionController>()) {
      unawaited(getIt<SubscriptionController>().reload());
    }
    if (getIt.isRegistered<FinanceController>()) {
      unawaited(getIt<FinanceController>().reload());
    }
    if (getIt.isRegistered<SmsInboxController>()) {
      unawaited(getIt<SmsInboxController>().drainBackground());
    }
  }

  void _openSmsTarget(SmsValidationTarget target) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SmsInboxScreen(
          initialValidationId: target.id,
          initialValidationKind: target.kind,
          initialValidationAction: target.action,
        ),
      ),
    );
  }

  void _select(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  void _openTransactionLog() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TransactionLogScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onNavigateToLog: _openTransactionLog,
            onNavigateToBudget: () => _select(1),
          ),
          const BudgetScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
