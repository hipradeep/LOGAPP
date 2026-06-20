import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../controllers/calendar_scheduler_controller.dart';

class DiagonalStripesPainter extends CustomPainter {
  final Color stripeColor;
  final double stripeWidth;
  final double gap;

  DiagonalStripesPainter({
    required this.stripeColor,
    this.stripeWidth = 2.0,
    this.gap = 8.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = stripeColor
      ..strokeWidth = stripeWidth
      ..style = PaintingStyle.stroke;

    final double step = stripeWidth + gap;

    for (double i = -size.height; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DiagonalStripesPainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor ||
        oldDelegate.stripeWidth != stripeWidth ||
        oldDelegate.gap != gap;
  }
}

class TimelineEventCard extends StatelessWidget {
  final TimelineEvent event;
  final VoidCallback onTap;

  const TimelineEventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  ({Color background, Color accent, Color text, Color stripe}) _resolveColors(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final titleLower = event.title.toLowerCase();
    final isBreak = titleLower.contains('break') || titleLower.contains('lunch');

    if (isBreak) {
      if (isDark) {
        return (
          background: Colors.white.withValues(alpha: 0.02),
          accent: Colors.white.withValues(alpha: 0.2),
          text: AppTheme.textSecondaryColor(context),
          stripe: Colors.white.withValues(alpha: 0.04),
        );
      } else {
        return (
          background: Colors.black.withValues(alpha: 0.01),
          accent: Colors.black.withValues(alpha: 0.15),
          text: AppTheme.textSecondaryColor(context),
          stripe: Colors.black.withValues(alpha: 0.03),
        );
      }
    }

    // Curated color themes based on category or tracking type
    final category = event.category?.toLowerCase() ?? '';
    if (category.contains('work') || category.contains('job') || category.contains('office') || event.title.contains('work')) {
      // Periwinkle/Indigo Theme
      if (isDark) {
        return (
          background: const Color(0xFF312E81).withValues(alpha: 0.35),
          accent: const Color(0xFF818CF8),
          text: const Color(0xFFC7D2FE),
          stripe: Colors.transparent,
        );
      } else {
        return (
          background: const Color(0xFFEEF2FF),
          accent: const Color(0xFF6366F1),
          text: const Color(0xFF3730A3),
          stripe: Colors.transparent,
        );
      }
    } else if (category.contains('health') || category.contains('fit') || category.contains('sport') || category.contains('water') || category.contains('gym')) {
      // Teal/Emerald Theme
      if (isDark) {
        return (
          background: const Color(0xFF064E3B).withValues(alpha: 0.35),
          accent: const Color(0xFF34D399),
          text: const Color(0xFFA7F3D0),
          stripe: Colors.transparent,
        );
      } else {
        return (
          background: const Color(0xFFECFDF5),
          accent: const Color(0xFF10B981),
          text: const Color(0xFF065F46),
          stripe: Colors.transparent,
        );
      }
    } else if (category.contains('goal') || category.contains('milestone') || event.trackingType == 'milestone') {
      // Gold/Amber Theme
      if (isDark) {
        return (
          background: const Color(0xFF78350F).withValues(alpha: 0.3),
          accent: const Color(0xFFFBBF24),
          text: const Color(0xFFFDE68A),
          stripe: Colors.transparent,
        );
      } else {
        return (
          background: const Color(0xFFFFFBEB),
          accent: const Color(0xFFF59E0B),
          text: const Color(0xFF78350F),
          stripe: Colors.transparent,
        );
      }
    } else {
      // Default: Violet/Brand Theme
      final primary = AppTheme.primaryColor;
      final accent = AppTheme.primaryAccentColor(context);
      if (isDark) {
        return (
          background: primary.withValues(alpha: 0.12),
          accent: accent,
          text: AppTheme.textPrimaryColor(context),
          stripe: Colors.transparent,
        );
      } else {
        return (
          background: primary.withValues(alpha: 0.06),
          accent: primary,
          text: AppTheme.textPrimaryColor(context),
          stripe: Colors.transparent,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context);
    final titleLower = event.title.toLowerCase();
    final isBreak = titleLower.contains('break') || titleLower.contains('lunch');

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxHeight = constraints.maxHeight;
        
        // Dynamic sizing thresholds for timeline blocks
        final bool isShort = maxHeight < 68.0;
        final bool isVeryShort = maxHeight < 52.0;

        final double verticalPadding = isVeryShort ? 2.0 : (isShort ? 4.0 : 8.0);
        final double titleSize = isVeryShort ? 11.5 : (isShort ? 12.5 : 14.0);
        final double accentBarWidth = isVeryShort ? 3.0 : 4.0;
        final double gapSize = isVeryShort ? 4.0 : 8.0;

        final String headingText;
        final String? subHeadingText;

        if (event.trackingType == 'multiple' || event.trackingType == 'milestone') {
          if (maxHeight >= 36.0) {
            headingText = event.description; // Activity name
            subHeadingText = event.title;     // Task name
            // Future implementation: Include start/end time (e.g. subHeadingText = '${event.title} | ${_timeFormatter.format(event.startTime)}')
          } else {
            headingText = event.title;       // Task name
            subHeadingText = null;
          }
        } else {
          headingText = event.title;       // Activity name
          final hasDesc = event.description.isNotEmpty &&
              !isBreak &&
              !isShort &&
              event.title.trim().toLowerCase() != event.description.trim().toLowerCase();
          subHeadingText = hasDesc ? event.description : null;
          // Future implementation: Include start/end time (e.g. subHeadingText = _timeFormatter.format(event.startTime))
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  if (isBreak)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DiagonalStripesPainter(
                          stripeColor: colors.stripe,
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left color bar
                        Container(
                          width: accentBarWidth,
                          color: colors.accent,
                        ),
                        SizedBox(width: gapSize),
                        // Event info
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 2),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                physics: const NeverScrollableScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      headingText,
                                      style: GoogleFonts.outfit(
                                        color: event.isCompleted ? colors.text.withValues(alpha: 0.5) : colors.text,
                                        fontSize: titleSize,
                                        fontWeight: FontWeight.bold,
                                        decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subHeadingText != null) ...[
                                      SizedBox(height: isVeryShort ? 2.0 : 4.0),
                                      Text(
                                        subHeadingText,
                                        style: AppTheme.bodySmall.copyWith(
                                          color: event.isCompleted ? colors.text.withValues(alpha: 0.4) : colors.text.withValues(alpha: 0.65),
                                          fontSize: isVeryShort ? 9.5 : 10.5,
                                          fontWeight: FontWeight.w500,
                                          decoration: event.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
