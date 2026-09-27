import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A premium, reusable toggle switch for choosing between two options.
class AppBinaryToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String trueLabel;
  final String falseLabel;
  final Color trueColor;
  final Color falseColor;

  const AppBinaryToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.trueLabel,
    required this.falseLabel,
    this.trueColor = AppTheme.errorColor,
    this.falseColor = AppTheme.successColor,
  });

  @override
  State<AppBinaryToggle> createState() => _AppBinaryToggleState();
}

class _AppBinaryToggleState extends State<AppBinaryToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant AppBinaryToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      setState(() {
        _value = widget.value;
      });
    }
  }

  void _handleToggle() {
    setState(() {
      _value = !_value;
    });
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _value ? widget.trueColor : widget.falseColor;
    final activeLabel = _value ? widget.trueLabel : widget.falseLabel;

    return GestureDetector(
      onTap: _handleToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: activeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          activeLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: activeColor,
          ),
        ),
      ),
    );
  }
}
