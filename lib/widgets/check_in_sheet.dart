import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_spacers.dart';

class CheckInSheet extends StatefulWidget {
  final Map<String, dynamic>? session;
  final Map<String, dynamic> membership;
  final Future<bool> Function(String note) onConfirm;

  const CheckInSheet({
    super.key,
    required this.session,
    required this.membership,
    required this.onConfirm,
  });

  @override
  State<CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<CheckInSheet> {
  String _note = '';
  bool _isLoading = false;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  bool _isOutsideWindow() {
    final startTimeStr = widget.session?['startTime'];
    if (startTimeStr == null) return false;

    try {
      final parts = startTimeStr.split('-');
      var startPart = parts.first.trim().toUpperCase();
      var endPart = parts.length > 1 ? parts.last.trim().toUpperCase() : null;
      final fullStr = startTimeStr.toUpperCase();

      // Handle AM/PM for both parts
      if (!startPart.contains('AM') && !startPart.contains('PM')) {
        if (fullStr.contains('AM')) startPart += ' AM';
        else if (fullStr.contains('PM')) startPart += ' PM';
      }
      if (endPart != null && !endPart.contains('AM') && !endPart.contains('PM')) {
        if (fullStr.contains('AM')) endPart += ' AM';
        else if (fullStr.contains('PM')) endPart += ' PM';
      }

      final formats = [
        DateFormat('hh:mm a'),
        DateFormat('h:mm a'),
        DateFormat('hh:mma'),
        DateFormat('h:mma'),
        DateFormat('h a'),
        DateFormat('ha'),
      ];

      DateTime? parseTime(String timeStr) {
        for (var format in formats) {
          try {
            return format.parse(timeStr);
          } catch (_) {}
        }
        return null;
      }

      final parsedStart = parseTime(startPart);
      if (parsedStart == null) return false;

      final now = DateTime.now();
      final sessionStart = DateTime(now.year, now.month, now.day, parsedStart.hour, parsedStart.minute);
      
      DateTime? sessionEnd;
      if (endPart != null) {
        final parsedEnd = parseTime(endPart);
        if (parsedEnd != null) {
          sessionEnd = DateTime(now.year, now.month, now.day, parsedEnd.hour, parsedEnd.minute);
          // Handle overnight sessions
          if (sessionEnd.isBefore(sessionStart)) {
            sessionEnd = sessionEnd.add(const Duration(days: 1));
          }
        }
      }

      // Check window
      final windowStart = sessionStart.subtract(const Duration(minutes: 15));
      final windowEnd = sessionEnd ?? sessionStart.add(const Duration(minutes: 15));

      return now.isBefore(windowStart) || now.isAfter(windowEnd);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutside = _isOutsideWindow();
    final checkInColor = isOutside ? AppTheme.errorColor : AppTheme.successColor;
    final statusText = isOutside ? 'Outside Window' : 'On Time';

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Column(
                children: [
                  const VGapMd(),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const VGapLg(),
                  
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Confirmation', style: AppTheme.headingMedium.copyWith(fontSize: 28)),
                                Text(
                                  'Complete your session entry',
                                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
                                ),
                                const VGapXs(),
                                RichText(
                                  text: TextSpan(
                                    style: AppTheme.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'CHECK-IN TIME ',
                                        style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                                      ),
                                      TextSpan(
                                        text: DateFormat('hh:mm a').format(DateTime.now()),
                                        style: TextStyle(color: checkInColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const VGapMd(),
                        Text(
                          'Add Notes',
                          style: AppTheme.headingSmall.copyWith(fontSize: 16, color: AppTheme.textSecondary),
                        ),
                        const VGapMd(),
                        TextField(
                          onChanged: (v) => _note = v,
                          onTap: () {
                            _sheetController.animateTo(
                              0.95,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          minLines: 2,
                          maxLines: 6,
                          decoration: InputDecoration(
                            hintText: 'How are you feeling today?',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.02),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(color: AppTheme.primaryColor),
                            ),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                        
                        const VGapXxl(),
                        
                        // Action Button
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              setState(() => _isLoading = true);
                              final success = await widget.onConfirm(_note);
                              if (mounted) {
                                Navigator.pop(context, success);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                child: _isLoading 
                                  ? const SizedBox(
                                      height: 20, 
                                      width: 20, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const HGapMd(),
                                        Text(
                                          'Confirm Check-in',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const VGapXxl(),
                        const VGapXxl(),
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

