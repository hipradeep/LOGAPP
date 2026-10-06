import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/drive_sync_controller.dart';
import '../models/test_item.dart';
import '../theme/app_theme.dart';
import '../widgets/app_spacers.dart';

class HomeScreen extends StatefulWidget {
  final AuthController authController;
  final DriveSyncController driveSyncController;

  const HomeScreen({
    super.key,
    required this.authController,
    required this.driveSyncController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleAddTest() {
    final text = _textController.text;
    if (text.trim().isNotEmpty) {
      widget.driveSyncController.addTestItem(text);
      _textController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _HomeAppBar(authController: widget.authController),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: AppTheme.spacingMd,
            right: AppTheme.spacingMd,
            top: AppTheme.spacingSm,
            bottom: MediaQuery.of(context).padding.bottom + 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UserAccountCard(authController: widget.authController),
              const VGapMd(),
              _AddTestInputCard(
                controller: _textController,
                onAdd: _handleAddTest,
              ),
              const VGapMd(),
              _DriveSyncActionBar(
                driveSyncController: widget.driveSyncController,
              ),
              const VGapLg(),
              _TestItemsSection(
                driveSyncController: widget.driveSyncController,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AuthController authController;

  const _HomeAppBar({required this.authController});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Drive Sync Test', style: AppTheme.headingSmall),
      actions: [
        IconButton(
          tooltip: 'Sign Out',
          icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
          onPressed: authController.signOut,
        ),
      ],
    );
  }
}

class _UserAccountCard extends StatelessWidget {
  final AuthController authController;

  const _UserAccountCard({required this.authController});

  @override
  Widget build(BuildContext context) {
    final user = authController.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'Google User';
    final email = user?.email ?? 'No email provided';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, color: AppTheme.primaryLight)
                : null,
          ),
          const HGapMd(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTheme.headingSmall),
                const VGapXs(),
                Text(email, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSm,
              vertical: AppTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const HGapXs(),
                Text(
                  'Connected',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTestInputCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _AddTestInputCard({
    required this.controller,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Test Data', style: AppTheme.headingSmall),
          const VGapSm(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Enter test data to sync...',
                    hintStyle: AppTheme.bodyMedium,
                    filled: true,
                    fillColor: AppTheme.surfaceVariant.withValues(alpha: 0.3),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                      vertical: AppTheme.spacingSm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: BorderSide(
                        color: AppTheme.borderSubtle.withValues(alpha: 0.6),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: BorderSide(
                        color: AppTheme.borderSubtle.withValues(alpha: 0.6),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const HGapSm(),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMd,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    HGapXs(),
                    Text('Add', style: AppTheme.buttonText),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriveSyncActionBar extends StatelessWidget {
  final DriveSyncController driveSyncController;

  const _DriveSyncActionBar({required this.driveSyncController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: driveSyncController,
      builder: (context, _) {
        final isBusy = driveSyncController.isBusy;
        final status = driveSyncController.statusMessage;
        final error = driveSyncController.errorMessage;

        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: AppTheme.borderSubtle.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : driveSyncController.syncToDrive,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                      icon: driveSyncController.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 20),
                      label: Text(
                        driveSyncController.isSyncing ? 'Syncing...' : 'Sync to Drive',
                        style: AppTheme.buttonText,
                      ),
                    ),
                  ),
                  const HGapSm(),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : driveSyncController.restoreFromDrive,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentColor,
                        side: const BorderSide(color: AppTheme.accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                      icon: driveSyncController.isRestoring
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accentColor,
                              ),
                            )
                          : const Icon(Icons.cloud_download_outlined, size: 20),
                      label: Text(
                        driveSyncController.isRestoring ? 'Restoring...' : 'Restore',
                        style: AppTheme.buttonText.copyWith(color: AppTheme.accentColor),
                      ),
                    ),
                  ),
                ],
              ),
              if (status != null || error != null) ...[
                const VGapSm(),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSm),
                  decoration: BoxDecoration(
                    color: (error != null ? AppTheme.error : AppTheme.success)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        error != null ? Icons.error_outline : Icons.check_circle_outline,
                        size: 16,
                        color: error != null ? AppTheme.error : AppTheme.success,
                      ),
                      const HGapSm(),
                      Expanded(
                        child: Text(
                          error ?? status!,
                          style: AppTheme.bodySmall.copyWith(
                            color: error != null ? AppTheme.error : AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TestItemsSection extends StatelessWidget {
  final DriveSyncController driveSyncController;

  const _TestItemsSection({required this.driveSyncController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: driveSyncController,
      builder: (context, _) {
        final items = driveSyncController.items;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Synced Items', style: AppTheme.headingSmall),
                Text(
                  '${items.length} items',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
            const VGapSm(),
            if (items.isEmpty)
              const _EmptyItemsPlaceholder()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _TestItemCard(
                    key: ValueKey(item.id),
                    item: item,
                    onDelete: () => driveSyncController.removeTestItem(item.id),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _TestItemCard extends StatelessWidget {
  final TestItem item;
  final VoidCallback onDelete;

  const _TestItemCard({
    super.key,
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.content, style: AppTheme.bodyLarge),
                const VGapXs(),
                Row(
                  children: [
                    _SyncBadge(isSynced: item.isSynced),
                    const HGapSm(),
                    Text(
                      _formatDate(item.createdAt),
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _SyncBadge extends StatelessWidget {
  final bool isSynced;

  const _SyncBadge({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    final color = isSynced ? AppTheme.success : AppTheme.warning;
    final label = isSynced ? 'Drive Synced' : 'Local Only';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done : Icons.cloud_off,
            size: 12,
            color: color,
          ),
          const HGapXs(),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyItemsPlaceholder extends StatelessWidget {
  const _EmptyItemsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.borderSubtle.withValues(alpha: 0.3),
        ),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppTheme.textMuted),
          VGapSm(),
          Text('No test items yet', style: AppTheme.headingSmall),
          VGapXs(),
          Text(
            'Type a test note above and click "Add" to start.',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
