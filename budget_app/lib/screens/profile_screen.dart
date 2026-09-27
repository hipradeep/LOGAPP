import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/preferences_service.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/app_spacers.dart';
import '../widgets/glow_blob.dart';
import 'manage_budget_screen.dart';
import 'manage_budget1_screen.dart';
import 'manage_budget2_screen.dart';
import 'expense_category_screen.dart';
import 'payment_mode_screen.dart';
import 'theme_selection_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PreferencesService _prefs = PreferencesService();
  String _userName = 'Budget User';
  String _userAvatar = '💰';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await _prefs.getUserName();
    final avatar = await _prefs.getUserAvatar();
    if (mounted) {
      setState(() {
        _userName = name;
        _userAvatar = avatar;
      });
    }
  }

  void _editProfile() {
    final nameController = TextEditingController(text: _userName);
    final avatarList = ['💰', '💳', '🦁', '🚀', '⭐', '💎', '🔥', '⚡', '💼', '🎯'];
    String chosenAvatar = _userAvatar;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Profile', style: AppTheme.headingSmall),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const VGapMd(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: avatarList.map((a) {
                  final isSelected = chosenAvatar == a;
                  return GestureDetector(
                    onTap: () => setDlgState(() => chosenAvatar = a),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.3) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(a, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryColor(context))),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  await _prefs.saveUserName(name);
                  await _prefs.saveUserAvatar(chosenAvatar);
                  setState(() {
                    _userName = name;
                    _userAvatar = chosenAvatar;
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      showScaffold: false,
      isScrollable: true,
      title: 'Profile & Settings',
      padding: AppTheme.defaultScreenPadding,
      backgroundWidgets: [
        GlowBlob(
          top: -40,
          left: -40,
          size: 220,
          color: AppTheme.primaryColor,
          opacity: 0.12,
        ),
        GlowBlob(
          bottom: -50,
          right: -50,
          size: 260,
          color: AppTheme.secondaryColor,
          opacity: 0.08,
        ),
      ],
      children: [
        const VGapSm(),
        // Profile Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius * 1.2),
            border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(_userAvatar, style: const TextStyle(fontSize: 32)),
              ),
              const HGapMd(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const VGapXs(),
                    Text(
                      'Budget Master • INR Tracker',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: _editProfile,
              ),
            ],
          ),
        ),
        const VGapLg(),
        Text(
          'BUDGET & PREFERENCES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const VGapSm(),
        _buildMenuCard(
          context,
          items: [
            _MenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Manage Budgets',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageBudgetScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Manage Budget 1',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageBudget1Screen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.add_chart_rounded,
              title: 'Manage Budget 2',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ManageBudget2Screen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.category_outlined,
              title: 'Expense Categories',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExpenseCategoryScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.payment_outlined,
              title: 'Payment Modes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentModeScreen()),
                );
              },
            ),
          ],
        ),
        const VGapLg(),
        Text(
          'APPEARANCE & SYSTEM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: AppTheme.textSecondaryColor(context),
          ),
        ),
        const VGapSm(),
        _buildMenuCard(
          context,
          items: [
            _MenuItem(
              icon: Icons.palette_outlined,
              title: 'App Theme',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ThemeSelectionScreen()),
                );
              },
            ),
            _MenuItem(
              icon: Icons.info_outline_rounded,
              title: 'About Budget',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Budget',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Text('💰', style: TextStyle(fontSize: 32)),
                  children: const [
                    Text('A modern Flutter Android app for managing personal budgets and expenses in INR.'),
                  ],
                );
              },
            ),
          ],
        ),
        const VGapBottomNav(),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, {required List<_MenuItem> items}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.defaultBorderRadius),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(color: AppTheme.borderColor(context), height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: AppTheme.primaryLight, size: 20),
            ),
            title: Text(item.title, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondaryColor(context)),
            onTap: item.onTap,
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
