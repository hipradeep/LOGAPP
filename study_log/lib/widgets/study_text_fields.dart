import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';
import '../utils/url_launcher_helper.dart';
export '../utils/url_launcher_helper.dart';

/// Reusable clean unrounded input with bottom bar on focus.
/// Features:
/// - Clean label with optional required red asterisk
/// - Larger text size with modern semi-bold weight
/// - Subtle bottom border that highlights to primaryColor on focus
/// - Optional suffix icon (e.g. stepper or clear icon)
class UnderlineInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool isRequired;
  final TextInputType keyboardType;
  final Widget? suffixIcon;
  final double fontSize;
  final FontWeight fontWeight;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int? maxLines;
  final EdgeInsetsGeometry? contentPadding;

  const UnderlineInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    this.isRequired = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.fontSize = 18.0,
    this.fontWeight = FontWeight.w600,
    this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          if (isRequired)
            RichText(
              text: TextSpan(
                text: label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor(context),
                ),
                children: [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
          const VGapSm(),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: AppTheme.textPrimaryColor(context),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
              color: AppTheme.textMutedColor(context),
            ),
            suffixIcon: suffixIcon,
            isDense: true,
            contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 10),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.borderColor(context)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom [TextEditingController] that automatically detects valid URLs
/// and renders them in blue with an underline.
class UrlHighlightEditingController extends TextEditingController {
  final Color urlColor;

  UrlHighlightEditingController({
    super.text,
    this.urlColor = const Color(0xFF2196F3),
  });

  /// Regex detecting web URLs starting with http://, https://, or www.
  static final RegExp urlRegex = RegExp(
    r'https?:\/\/[^\s<>"{}|\\^`\[\]]+|www\.[^\s<>"{}|\\^`\[\]]+',
    caseSensitive: false,
  );

  /// Splits [text] into spans, highlighting valid URL matches with [urlStyle].
  /// If [onUrlTap] is provided, clicking the URL will trigger the callback.
  static List<InlineSpan> buildUrlSpans({
    required String text,
    required TextStyle defaultStyle,
    required TextStyle urlStyle,
    void Function(String url)? onUrlTap,
  }) {
    if (text.isEmpty) return const [];

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in urlRegex.allMatches(text)) {
      var url = match.group(0)!;
      final matchStart = match.start;
      var matchEnd = match.end;

      // Trim trailing punctuation marks like '.', ',', ';', '!' that shouldn't belong to the URL
      while (url.isNotEmpty &&
          (url.endsWith('.') || url.endsWith(',') || url.endsWith(';') || url.endsWith('!'))) {
        url = url.substring(0, url.length - 1);
        matchEnd--;
      }

      if (matchStart > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, matchStart),
          style: defaultStyle,
        ));
      }

      final targetUrl = url;
      spans.add(TextSpan(
        text: url,
        style: urlStyle,
        recognizer: onUrlTap != null
            ? (TapGestureRecognizer()..onTap = () => onUrlTap(targetUrl))
            : null,
      ));

      lastMatchEnd = matchEnd;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: defaultStyle,
      ));
    }

    return spans;
  }

  /// Extracts all unique valid URLs from [text].
  static List<String> extractUrls(String text) {
    if (text.isEmpty) return const [];
    final List<String> urls = [];
    for (final match in urlRegex.allMatches(text)) {
      var url = match.group(0)!;
      while (url.isNotEmpty &&
          (url.endsWith('.') || url.endsWith(',') || url.endsWith(';') || url.endsWith('!'))) {
        url = url.substring(0, url.length - 1);
      }
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (text.isEmpty) {
      return TextSpan(style: style, text: '');
    }

    final effectiveStyle = style ?? const TextStyle();
    final effectiveUrlStyle = effectiveStyle.copyWith(
      color: urlColor,
      decoration: TextDecoration.underline,
      decorationColor: urlColor,
    );

    return TextSpan(
      style: effectiveStyle,
      children: buildUrlSpans(
        text: text,
        defaultStyle: effectiveStyle,
        urlStyle: effectiveUrlStyle,
      ),
    );
  }
}

/// Reusable borderless description field.
/// Features:
/// - Flat unrounded surface with no borders
/// - Clean multiline text editing with larger readable font
/// - URL identifier: highlights valid URLs in blue with underline
/// - Real-time surgical character counter (e.g. 0/500) via [ListenableBuilder]
class BorderlessDescriptionField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String hintText;
  final int maxLength;
  final int? minLines;
  final int? maxLines;
  final ScrollPhysics? scrollPhysics;
  final double fontSize;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color urlColor;
  final ValueChanged<String>? onChanged;

  final bool showUrlChips;
  final bool readOnly;

  const BorderlessDescriptionField({
    super.key,
    this.label = 'Notes/Description',
    this.controller,
    this.hintText = 'Enter description',
    this.maxLength = 1000,
    this.minLines = 1,
    this.maxLines,
    this.scrollPhysics = const NeverScrollableScrollPhysics(),
    this.fontSize = 15.0,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.transparent,
    this.urlColor = const Color(0xFF2196F3),
    this.showUrlChips = true,
    this.readOnly = false,
    this.onChanged,
  });

  /// Specialized constructor for Course descriptions.
  const BorderlessDescriptionField.course({
    super.key,
    this.label = 'Course Description',
    this.controller,
    this.hintText = 'Enter course description, syllabus, or notes...',
    this.maxLength = 1000,
    this.minLines = 2,
    this.maxLines,
    this.scrollPhysics = const NeverScrollableScrollPhysics(),
    this.fontSize = 15.0,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.transparent,
    this.urlColor = const Color(0xFF2196F3),
    this.showUrlChips = true,
    this.readOnly = false,
    this.onChanged,
  });

  /// Specialized constructor for Module descriptions.
  const BorderlessDescriptionField.module({
    super.key,
    this.label = 'Module Description',
    this.controller,
    this.hintText = 'Enter module description, outline, or resources...',
    this.maxLength = 1000,
    this.minLines = 2,
    this.maxLines,
    this.scrollPhysics = const NeverScrollableScrollPhysics(),
    this.fontSize = 15.0,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.transparent,
    this.urlColor = const Color(0xFF2196F3),
    this.showUrlChips = true,
    this.readOnly = false,
    this.onChanged,
  });

  /// Specialized constructor for Topic descriptions.
  const BorderlessDescriptionField.topic({
    super.key,
    this.label = 'Notes/Description',
    this.controller,
    this.hintText = 'Enter topic notes, references, or key takeaways...',
    this.maxLength = 1000,
    this.minLines = 2,
    this.maxLines,
    this.scrollPhysics = const NeverScrollableScrollPhysics(),
    this.fontSize = 15.0,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.transparent,
    this.urlColor = const Color(0xFF2196F3),
    this.showUrlChips = true,
    this.readOnly = false,
    this.onChanged,
  });

  /// Specialized constructor for Todo / Task notes.
  const BorderlessDescriptionField.todo({
    super.key,
    this.label = 'Notes',
    this.controller,
    this.hintText = 'Add description, notes, or links (optional)...',
    this.maxLength = 1000,
    this.minLines = 2,
    this.maxLines = 6,
    this.scrollPhysics = const NeverScrollableScrollPhysics(),
    this.fontSize = 15.0,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = Colors.transparent,
    this.urlColor = const Color(0xFF2196F3),
    this.showUrlChips = true,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<BorderlessDescriptionField> createState() => _BorderlessDescriptionFieldState();
}

class _BorderlessDescriptionFieldState extends State<BorderlessDescriptionField> {
  late UrlHighlightEditingController _effectiveController;
  bool _isProxy = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final external = widget.controller;
    if (external is UrlHighlightEditingController) {
      _effectiveController = external;
      _isProxy = false;
    } else {
      _isProxy = true;
      _effectiveController = UrlHighlightEditingController(
        text: external?.text ?? '',
        urlColor: widget.urlColor,
      );
      _effectiveController.addListener(_onInternalChanged);
      external?.addListener(_onExternalChanged);
    }
  }

  void _onInternalChanged() {
    final external = widget.controller;
    if (external != null && external.text != _effectiveController.text) {
      external.value = _effectiveController.value;
    }
  }

  void _onExternalChanged() {
    final external = widget.controller;
    if (external != null && external.text != _effectiveController.text) {
      _effectiveController.value = external.value;
    }
  }

  @override
  void didUpdateWidget(BorderlessDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_isProxy) {
        _effectiveController.removeListener(_onInternalChanged);
        oldWidget.controller?.removeListener(_onExternalChanged);
        _effectiveController.dispose();
      }
      _initController();
    }
  }

  @override
  void dispose() {
    if (_isProxy) {
      _effectiveController.removeListener(_onInternalChanged);
      widget.controller?.removeListener(_onExternalChanged);
      _effectiveController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveController = _effectiveController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const VGapSm(),
        Container(
          color: widget.backgroundColor ?? Colors.transparent,
          padding: widget.padding ?? EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: effectiveController,
                readOnly: widget.readOnly,
                keyboardType: TextInputType.multiline,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                scrollPhysics: widget.scrollPhysics,
                maxLength: widget.maxLength,
                onChanged: widget.onChanged,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  height: 1.5,
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.normal,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    fontSize: widget.fontSize,
                    height: 1.5,
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const VGapXs(),
              ListenableBuilder(
                listenable: effectiveController,
                builder: (context, _) {
                  final urls = widget.showUrlChips
                      ? UrlHighlightEditingController.extractUrls(effectiveController.text)
                      : const <String>[];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (urls.isNotEmpty)
                            Text(
                              '${urls.length} link${urls.length == 1 ? "" : "s"} detected',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2196F3),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Text(
                            '${effectiveController.text.length}/${widget.maxLength}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (urls.isNotEmpty) ...[
                        const VGapXs(),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: urls.map((u) {
                            return InkWell(
                              onTap: () => UrlLauncherHelper.openUrl(u, context: context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link_rounded, size: 13, color: Color(0xFF2196F3)),
                                    const HGapXs(),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 220),
                                      child: Text(
                                        u,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2196F3),
                                          fontWeight: FontWeight.w500,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    const HGapXs(),
                                    const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF2196F3)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Common alias for borderless notes and description field.
typedef NotesDescriptionField = BorderlessDescriptionField;
