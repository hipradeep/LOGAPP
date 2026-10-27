import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notification_service.dart';
import '../services/service_locator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/custom_app_bar.dart';
import 'subscription_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool? _enabled;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (!getIt.isRegistered<NotificationService>()) return;
    final enabled = await getIt<NotificationService>().notificationsEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _requestPermission() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    final granted = await getIt<NotificationService>().requestPermission();
    if (!mounted) return;
    setState(() => _isRequesting = false);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Notifications enabled'
                : 'Notifications are still off. Enable them in system settings.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = _enabled;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: SafeArea(
        child: Column(
          children: [
            const CustomAppBar(
              title: 'Notifications',
              subtitle: 'Bill reminders and permission status.',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingMd,
                  AppTheme.spacingSm,
                  AppTheme.spacingMd,
                  AppTheme.spacingXl,
                ),
                children: [
                  const _SectionLabel('PERMISSION'),
                  const VGapSm(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: enabled == true
                                      ? AppTheme.pastelGreen(context)
                                      : AppTheme.pastelOrange(context),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.iconBoxRadius,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  enabled == true
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_off_outlined,
                                  color: enabled == true
                                      ? AppTheme.pastelGreenText(context)
                                      : AppTheme.pastelOrangeText(context),
                                  size: 20,
                                ),
                              ),
                              const HGapSm(),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      enabled == true
                                          ? 'Notifications are on'
                                          : enabled == false
                                          ? 'Notifications are off'
                                          : 'Checking permission…',
                                      style: textTheme.titleMedium,
                                    ),
                                    const VGapXs(),
                                    Text(
                                      enabled == true
                                          ? 'Bill reminders can reach this device.'
                                          : 'Enable notifications so bill reminders can be delivered.',
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (enabled == false) ...[
                            const VGapMd(),
                            SizedBox(
                              width: double.infinity,
                              height: AppTheme.buttonHeight,
                              child: FilledButton.icon(
                                onPressed: _isRequesting
                                    ? null
                                    : _requestPermission,
                                icon: _isRequesting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.notifications_outlined,
                                        size: 18,
                                      ),
                                label: const Text('Enable notifications'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const VGapLg(),
                  const _SectionLabel('BILL REMINDERS'),
                  const VGapSm(),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingMd),
                          child: Text(
                            'Subscription reminders are scheduled for 9:00 AM '
                            'three days before, one day before, and on the due '
                            'date.',
                            style: textTheme.bodyMedium,
                          ),
                        ),
                        Divider(
                          color: AppTheme.borderColor(context),
                          height: 1,
                        ),
                        ListTile(
                          leading: const Icon(Icons.autorenew_rounded),
                          title: const Text('Manage subscriptions'),
                          subtitle: const Text(
                            'Add, pause or update recurring bills.',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SubscriptionScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
