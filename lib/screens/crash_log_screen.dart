import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../services/crash_reporting_service.dart';

class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  String _logContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final content = await CrashReportingService.readCrashLog();
    if (mounted) {
      setState(() {
        _logContent = content;
        _isLoading = false;
      });
    }
  }

  void _handleRefresh() {
    _loadLogs();
  }

  Future<void> _handleClear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Crash Logs?',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will permanently delete all saved local crash logs on this device.',
          style: TextStyle(
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleCancelClear,
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ),
          TextButton(
            onPressed: _handleConfirmClear,
            child: const Text('Clear', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await CrashReportingService.clearCrashLog();
      await _loadLogs();
    }
  }

  void _handleCancelClear() {
    Navigator.pop(context, false);
  }

  void _handleConfirmClear() {
    Navigator.pop(context, true);
  }

  void _triggerSyncError() {
    throw StateError('Simulated StateError (Synchronous)');
  }

  void _triggerAsyncError() {
    Future.microtask(() {
      throw ArgumentError('Simulated ArgumentError (Asynchronous)');
    });
  }

  void _triggerFlutterError() {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: Exception('Simulated FlutterError (Framework)'),
        library: 'LOG Testing',
        context: ErrorDescription('while executing test button'),
      ),
    );
  }

  Widget _buildTestSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'TRIGGER TEST CRASHES',
            style: TextStyle(
              color: AppTheme.textSecondaryColor(context).withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor(context),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _TestCrashButton(
                title: 'Sync Exception (Dart)',
                subtitle: 'Simulates a standard synchronous Dart error',
                color: AppTheme.primaryColor,
                onPressed: _triggerSyncError,
              ),
              Divider(height: 16, color: AppTheme.borderColor(context)),
              _TestCrashButton(
                title: 'Async Exception (Future)',
                subtitle: 'Simulates an asynchronous background error',
                color: AppTheme.secondaryColor,
                onPressed: _triggerAsyncError,
              ),
              Divider(height: 16, color: AppTheme.borderColor(context)),
              _TestCrashButton(
                title: 'Framework Exception (Flutter)',
                subtitle: 'Simulates a widget tree or layout build error',
                color: AppTheme.errorColor,
                onPressed: _triggerFlutterError,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'Local Crash Logs',
      showBackButton: true,
      isScrollable: true,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimaryColor(context)),
          onPressed: _handleRefresh,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorColor),
          onPressed: _handleClear,
        ),
      ],
      children: [
        const VGapMd(),
        _buildTestSection(context),
        const VGapLg(),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _LogContentWidget(content: _logContent),
        const VGapXxl(),
      ],
    );
  }
}

class _LogContentWidget extends StatelessWidget {
  final String content;

  const _LogContentWidget({required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderColor(context),
          width: 1,
        ),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.0,
          color: AppTheme.textPrimaryColor(context),
          height: 1.4,
        ),
      ),
    );
  }
}

class _TestCrashButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;

  const _TestCrashButton({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            Icon(Icons.bug_report_outlined, color: color),
            const HGapMd(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const VGapXs(),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}

