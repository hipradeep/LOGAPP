import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cache_service.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_page.dart';
import '../widgets/glow_blob.dart';
import '../widgets/budget_tab.dart';
import '../widgets/milestones_tab.dart';
import '../widgets/notes_tab.dart';
import '../widgets/diet_tab.dart';
import '../widgets/reminders_tab.dart';



// ==================== MANAGEMENT SCREEN ====================

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  final CacheService _cacheService = CacheService();

  // Current active category (0: Milestones, 1: Budget, 2: Diet, 3: Reminders, 4: Study)
  int _activeCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCachedTab();
  }

  Future<void> _loadCachedTab() async {
    final cachedIndex = await _cacheService.getSelectedTab();
    if (mounted && cachedIndex >= 0 && cachedIndex < _categories.length) {
      setState(() {
        _activeCategoryIndex = cachedIndex;
      });
    }
  }

  bool _isMenuOpen = false;
  int? _hoveredCategoryIndex;
  double _accumulatedDragDelta = 0.0;
  bool _hasTriggeredDrag = false;

  // Category Configuration
  final List<Map<String, dynamic>> _categories = [
    {
      'label': 'Milestones',
      'icon': Icons.flag_outlined,
      'activeIcon': Icons.flag,
    },
    {
      'label': 'Budget',
      'icon': Icons.account_balance_wallet_outlined,
      'activeIcon': Icons.account_balance_wallet,
    },
    {
      'label': 'Note/Journal',
      'icon': Icons.book_outlined,
      'activeIcon': Icons.book,
    },
    {
      'label': 'Diet',
      'icon': Icons.restaurant_outlined,
      'activeIcon': Icons.restaurant,
    },
    {
      'label': 'Reminders',
      'icon': Icons.notifications_active_outlined,
      'activeIcon': Icons.notifications_active,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: FullScreenPage(
        showScaffold: false,
        isScrollable: false,
        padding: EdgeInsets.zero,
        backgroundWidgets: const [
          GlowBlob(
            top: -40,
            left: -40,
            size: 220,
            color: AppTheme.primaryColor,
            opacity: 0.08,
          ),
          GlowBlob(
            bottom: -50,
            right: -50,
            size: 260,
            color: AppTheme.secondaryColor,
            opacity: 0.05,
          ),
        ],
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Scrollable Active Content (Self-Scrolling inside each tab)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 70,
                    ),
                    child: _buildActiveContent(),
                  ),
                ),
                
                // 2. Custom App Bar / Header (drawn behind dropdown but on top of scrollable content)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCustomHeader(context),
                ),
                
                // 3. Tap-to-Close Menu Barrier
                if (_isMenuOpen)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _isMenuOpen = false;
                        });
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                
                // 4. Overlaid Collapsible Category Menu
                Positioned(
                  top: 5,
                  right: 17,
                  child: _buildCollapsibleCategoryMenu(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            12,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _categories[_activeCategoryIndex]['label'] as String,
                  style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildMenuToggleButton(),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePanUpdate(double globalY) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final capsuleTop = statusBarHeight + 5;
    final localY = globalY - capsuleTop;

    if (localY >= 61 && localY < 61 + _categories.length * 52) {
      final idx = (localY - 61) ~/ 52;
      if (idx >= 0 && idx < _categories.length) {
        if (_hoveredCategoryIndex != idx) {
          setState(() {
            _hoveredCategoryIndex = idx;
          });
        }
      }
    } else {
      if (_hoveredCategoryIndex != null) {
        setState(() {
          _hoveredCategoryIndex = null;
        });
      }
    }
  }

  void _setActiveCategory(int index) {
    if (_activeCategoryIndex != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeCategoryIndex = index;
      });
      _cacheService.saveSelectedTab(index);
    }
  }

  void _handlePanEnd() {
    if (_hoveredCategoryIndex != null) {
      _setActiveCategory(_hoveredCategoryIndex!);
      setState(() {
        _isMenuOpen = false;
        _hoveredCategoryIndex = null;
      });
    } else {
      setState(() {
        _hoveredCategoryIndex = null;
      });
    }
  }

  // ==================== WIDGET BUILDERS ====================

  Widget _buildMenuToggleButton() {
    final selectedCategory = _categories[_activeCategoryIndex];

    return GestureDetector(
      onTap: () => setState(() => _isMenuOpen = !_isMenuOpen),
      onPanStart: (details) {
        if (!_isMenuOpen) {
          _accumulatedDragDelta = 0.0;
          _hasTriggeredDrag = false;
        } else {
          setState(() {
            _hoveredCategoryIndex = null;
          });
        }
      },
      onPanUpdate: (details) {
        if (!_isMenuOpen) {
          if (!_hasTriggeredDrag) {
            _accumulatedDragDelta += details.delta.dy;
            const double threshold = 25.0; // slightly lower threshold for quick snapping
            if (_accumulatedDragDelta >= threshold) {
              // Swipe down -> next tab
              final nextIdx = (_activeCategoryIndex + 1) % _categories.length;
              _setActiveCategory(nextIdx);
              _hasTriggeredDrag = true;
              _accumulatedDragDelta = 0.0;
            } else if (_accumulatedDragDelta <= -threshold) {
              // Swipe up -> previous tab
              final prevIdx = (_activeCategoryIndex - 1 + _categories.length) % _categories.length;
              _setActiveCategory(prevIdx);
              _hasTriggeredDrag = true;
              _accumulatedDragDelta = 0.0;
            }
          }
        } else {
          // Hover-select when menu is open
          _handlePanUpdate(details.globalPosition.dy);
        }
      },
      onPanEnd: (details) {
        if (!_isMenuOpen) {
          _accumulatedDragDelta = 0.0;
          _hasTriggeredDrag = false;
        } else {
          _handlePanEnd();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isMenuOpen
              ? AppTheme.primaryColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: _isMenuOpen
                ? AppTheme.primaryColor.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              selectedCategory['activeIcon'] as IconData,
              color: _isMenuOpen ? AppTheme.primaryLight : Colors.white,
              size: 20,
            ),
            Positioned(
              right: 3,
              bottom: 3,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceColor,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Icon(
                  _isMenuOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondary,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleCategoryMenu() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _hoveredCategoryIndex = null;
        });
      },
      onPanUpdate: (details) {
        _handlePanUpdate(details.globalPosition.dy);
      },
      onPanEnd: (details) {
        _handlePanEnd();
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topRight,
        child: SizedBox(
          width: 56,
          height: _isMenuOpen ? null : 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: _isMenuOpen
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor.withValues(
                      alpha: _isMenuOpen ? 0.90 : 0.0,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: _isMenuOpen ? 0.12 : 0.0,
                      ),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 7),
                      Opacity(
                        opacity: _isMenuOpen ? 1.0 : 0.0,
                        child: _buildMenuToggleButton(),
                      ),
                      const SizedBox(height: 12),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: _isMenuOpen ? 1.0 : 0.0,
                        child: _buildCategorySelector(),
                      ),
                      const SizedBox(height: 7),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_categories.length, (index) {
        final isSelected = _activeCategoryIndex == index;
        final isHovered = _hoveredCategoryIndex == index;
        final showActive = _hoveredCategoryIndex != null ? isHovered : isSelected;
        final cat = _categories[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GestureDetector(
            onTap: () {
              _setActiveCategory(index);
              setState(() {
                _isMenuOpen = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showActive
                    ? AppTheme.primaryColor
                    : Colors.transparent,
                border: Border.all(
                  color: showActive
                      ? AppTheme.primaryLight.withValues(alpha: 0.5)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Icon(
                showActive ? cat['activeIcon'] : cat['icon'],
                color: showActive ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActiveContent() {
    switch (_activeCategoryIndex) {
      case 0:
        return const MilestonesTab();
      case 1:
        return const BudgetTab();
      case 2:
        return const NotesTab();
      case 3:
        return const DietTab();
      case 4:
        return const RemindersTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // -------------------- 2. BUDGET (MODULARIZED OUT TO BUDGET_TAB) --------------------

  // -------------------- 3. DIET --------------------
}
