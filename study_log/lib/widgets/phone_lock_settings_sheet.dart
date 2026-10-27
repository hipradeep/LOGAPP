import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';
import '../widgets/sheet_action_widgets.dart';

/// Configuration model for Timed Phone Lock during focus sessions.
class PhoneLockConfig {
  final bool isLockModeEnabled;
  final int gracePeriodSeconds;
  final bool keepScreenAwake;
  final bool showEmergencyBypass;
  final bool playAlarmOnComplete;
  final bool enableScreenPinning;

  const PhoneLockConfig({
    this.isLockModeEnabled = false,
    this.gracePeriodSeconds = 10,
    this.keepScreenAwake = true,
    this.showEmergencyBypass = true,
    this.playAlarmOnComplete = true,
    this.enableScreenPinning = true,
  });

  PhoneLockConfig copyWith({
    bool? isLockModeEnabled,
    int? gracePeriodSeconds,
    bool? keepScreenAwake,
    bool? showEmergencyBypass,
    bool? playAlarmOnComplete,
    bool? enableScreenPinning,
  }) {
    return PhoneLockConfig(
      isLockModeEnabled: isLockModeEnabled ?? this.isLockModeEnabled,
      gracePeriodSeconds: gracePeriodSeconds ?? this.gracePeriodSeconds,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      showEmergencyBypass: showEmergencyBypass ?? this.showEmergencyBypass,
      playAlarmOnComplete: playAlarmOnComplete ?? this.playAlarmOnComplete,
      enableScreenPinning: enableScreenPinning ?? this.enableScreenPinning,
    );
  }
}

/// Dedicated bottom sheet modal to configure Lock Mode & Timed Lock settings.
class PhoneLockSettingsSheet extends StatefulWidget {
  final PhoneLockConfig initialConfig;
  final ValueChanged<PhoneLockConfig> onSave;

  const PhoneLockSettingsSheet({
    super.key,
    required this.initialConfig,
    required this.onSave,
  });

  static Future<PhoneLockConfig?> show(
    BuildContext context, {
    required PhoneLockConfig initialConfig,
  }) {
    return showModalBottomSheet<PhoneLockConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PhoneLockSettingsSheet(
        initialConfig: initialConfig,
        onSave: (cfg) => Navigator.of(ctx).pop(cfg),
      ),
    );
  }

  @override
  State<PhoneLockSettingsSheet> createState() => _PhoneLockSettingsSheetState();
}

class _PhoneLockSettingsSheetState extends State<PhoneLockSettingsSheet> {
  late bool _enabled;
  late int _gracePeriod;
  late bool _keepScreenAwake;
  late bool _showEmergencyBypass;
  late bool _playAlarmOnComplete;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialConfig.isLockModeEnabled;
    _gracePeriod = widget.initialConfig.gracePeriodSeconds;
    _keepScreenAwake = widget.initialConfig.keepScreenAwake;
    _showEmergencyBypass = widget.initialConfig.showEmergencyBypass;
    _playAlarmOnComplete = widget.initialConfig.playAlarmOnComplete;
  }

  void _save() {
    final updated = PhoneLockConfig(
      isLockModeEnabled: _enabled,
      gracePeriodSeconds: _gracePeriod,
      keepScreenAwake: _keepScreenAwake,
      showEmergencyBypass: _showEmergencyBypass,
      playAlarmOnComplete: _playAlarmOnComplete,
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    return SheetContainer(
      children: [
        const SheetHandleBar(),
        const VGapMd(),
        SheetHeader(
          badge: SheetHeaderBadge(
            backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.12),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFDC2626),
              size: 24,
            ),
          ),
          title: 'Lock Mode Settings',
          subtitle: 'Timed phone lock inspired by Lock My Phone (Zen Mode)',
        ),
        const VGapMd(),

        // Master Lock Mode Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _enabled
                ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                : AppTheme.surfaceVariant(context).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _enabled
                  ? const Color(0xFFDC2626).withValues(alpha: 0.35)
                  : AppTheme.borderColor(context),
              width: _enabled ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _enabled
                      ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                      : AppTheme.surfaceVariant(context),
                ),
                child: Icon(
                  Icons.screen_lock_portrait_rounded,
                  size: 20,
                  color: _enabled
                      ? const Color(0xFFDC2626)
                      : AppTheme.textSecondaryColor(context),
                ),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Lock Mode',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    const VGapXs(),
                    Text(
                      'Engage full-screen immersive Zen lock during session',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                activeTrackColor: const Color(0xFFDC2626),
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  setState(() => _enabled = val);
                },
              ),
            ],
          ),
        ),

        const VGapMd(),

        // Sub-options (Only active when enabled)
        Opacity(
          opacity: _enabled ? 1.0 : 0.45,
          child: IgnorePointer(
            ignoring: !_enabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOCK RULES & BEHAVIOR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
                const VGapSm(),

                // Grace Period Selector
                _buildGracePeriodSelector(context),
                const VGapSm(),

                // Keep screen on
                _buildToggleItem(
                  context: context,
                  icon: Icons.brightness_medium_rounded,
                  title: 'Keep screen awake',
                  subtitle: 'Prevents display from going to sleep while locked',
                  value: _keepScreenAwake,
                  onChanged: (v) => setState(() => _keepScreenAwake = v),
                ),
                const VGapSm(),

                // Emergency Call / ICE Bypass
                _buildToggleItem(
                  context: context,
                  icon: Icons.emergency_rounded,
                  title: 'Emergency bypass button',
                  subtitle: 'Allows quick access to system emergency dialer',
                  value: _showEmergencyBypass,
                  onChanged: (v) => setState(() => _showEmergencyBypass = v),
                ),
                const VGapSm(),

                // Sound/Alarm on complete
                _buildToggleItem(
                  context: context,
                  icon: Icons.notifications_active_rounded,
                  title: 'Play completion alert',
                  subtitle: 'Vibrate & chime when timed lock expires',
                  value: _playAlarmOnComplete,
                  onChanged: (v) => setState(() => _playAlarmOnComplete = v),
                ),
              ],
            ),
          ),
        ),

        const VGapLg(),

        // Save Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _enabled ? const Color(0xFFDC2626) : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _enabled ? 'Apply Lock Mode' : 'Save Settings',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGracePeriodSelector(BuildContext context) {
    final periods = [0, 5, 10, 15, 30];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              const HGapSm(),
              Expanded(
                child: Text(
                  'Cancellation grace period',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                _gracePeriod == 0 ? 'No grace' : '${_gracePeriod}s window',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const VGapXs(),
          Text(
            'Allows aborting session within this window before strict lockdown',
            style: TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
          const VGapSm(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: periods.map((secs) {
              final isSelected = _gracePeriod == secs;
              return GestureDetector(
                onTap: () => setState(() => _gracePeriod = secs),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFDC2626)
                        : AppTheme.surfaceVariant(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    secs == 0 ? 'Off' : '${secs}s',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: value ? const Color(0xFFDC2626) : AppTheme.textSecondaryColor(context),
            ),
            const HGapSm(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: const Color(0xFFDC2626),
              checkColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
