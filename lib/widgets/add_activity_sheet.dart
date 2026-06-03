import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../models/activity.dart';

class AddActivitySheet extends StatefulWidget {
  final Function(String name, String trackingType, int targetCount) onAdd;
  final Activity? initialActivity;
  final Function(String name, String trackingType, int targetCount)? onEdit;

  const AddActivitySheet({
    Key? key,
    required this.onAdd,
    this.initialActivity,
    this.onEdit,
  }) : super(key: key);

  @override
  State<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<AddActivitySheet> {
  final TextEditingController _activityNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _trackingType = 'daily'; // 'daily' or 'multiple'
  int _targetCount = 3;

  @override
  void initState() {
    super.initState();
    if (widget.initialActivity != null) {
      _activityNameController.text = widget.initialActivity!.name;
      _trackingType = widget.initialActivity!.trackingType;
      _targetCount = widget.initialActivity!.targetCount;
    }
    // Request focus on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _activityNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _activityNameController.text.trim();
    if (name.isNotEmpty) {
      if (widget.initialActivity != null && widget.onEdit != null) {
        widget.onEdit!(
          name,
          _trackingType,
          _trackingType == 'daily' ? 1 : _targetCount,
        );
      } else {
        widget.onAdd(
          name,
          _trackingType,
          _trackingType == 'daily' ? 1 : _targetCount,
        );
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drawer drag handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const VGapLg(),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.initialActivity != null ? 'Edit Activity' : 'New Activity',
                          style: AppTheme.headingSmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const VGapLg(),

                    // Text Field
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _activityNameController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          hintText: 'Enter activity name...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          icon: Icon(Icons.edit_note_rounded, color: AppTheme.primaryLight),
                        ),
                      ),
                    ),
                    const VGapLg(),

                    // Options Selector Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'TRACKING FREQUENCY',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const VGapSm(),

                    // Frequency Choice Chips
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _trackingType = 'daily';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _trackingType == 'daily'
                                    ? AppTheme.primaryColor.withOpacity(0.12)
                                    : AppTheme.surfaceColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _trackingType == 'daily'
                                      ? AppTheme.primaryColor.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.04),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Once a day',
                                  style: TextStyle(
                                    color: _trackingType == 'daily' ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: _trackingType == 'daily' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const HGapMd(),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _trackingType = 'multiple';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _trackingType == 'multiple'
                                    ? AppTheme.primaryColor.withOpacity(0.12)
                                    : AppTheme.surfaceColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _trackingType == 'multiple'
                                      ? AppTheme.primaryColor.withOpacity(0.6)
                                      : Colors.white.withOpacity(0.04),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Multiple times',
                                  style: TextStyle(
                                    color: _trackingType == 'multiple' ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: _trackingType == 'multiple' ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_trackingType == 'multiple') ...[
                      const VGapLg(),
                      // Target Counter Adjustment Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Target Count',
                            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _targetCount > 2
                                      ? () {
                                          setState(() {
                                            _targetCount--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.remove_rounded, color: Colors.white70),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '$_targetCount times',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _targetCount++;
                                    });
                                  },
                                  icon: const Icon(Icons.add_rounded, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const VGapLg(),

                    // Submit Button
                    GestureDetector(
                      onTap: _submit,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.initialActivity != null ? 'Save Changes' : 'Add Activity',
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
