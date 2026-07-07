import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
class ExpandableDescription extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final Color? buttonColor;

  const ExpandableDescription({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 3,
    this.buttonColor,
  });

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final primaryAccent = widget.buttonColor ?? AppTheme.primaryAccentColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use TextPainter to check if text exceeds the maxLines
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        final exceedsMaxLines = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: widget.style,
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow: _isExpanded ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
            if (exceedsMaxLines) ...[
              const VGapXs(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _isExpanded ? 'View Less' : 'View More',
                    style: TextStyle(
                      color: primaryAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.style.fontSize != null ? widget.style.fontSize! - 1 : 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
