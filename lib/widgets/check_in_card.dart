import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_icons.dart';
import 'app_spacers.dart';

class CheckInCard extends StatelessWidget {
  final Map<String, dynamic>? session;
  final Map<String, dynamic> membership;
  final VoidCallback onCheckIn;
  final String? businessName;

  const CheckInCard({
    super.key,
    required this.session,
    required this.membership,
    required this.onCheckIn,
    this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final bizName = businessName ?? membership['businessName'] ?? 'Your Space';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session?['name'] ?? 'Scheduled Session',
                      style: AppTheme.headingSmall.copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const VGapXs(),
                    Text(
                      bizName,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryLight.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const HGapMd(),
              _buildLiveBadge(),
            ],
          ),
          const VGapMd(),
          const Divider(color: Colors.white10, height: 1),
          const VGapMd(),
          Row(
            children: [
              _buildSmallDetail(Icons.access_time_rounded, session?['startTime'] ?? '--:--'),
              const Spacer(),
              _buildCompactCheckInButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: AppTheme.successColor, shape: BoxShape.circle),
          ),
          const HGapSm(),
          Text(
            'LIVE',
            style: AppTheme.bodyMicro.copyWith(
              color: AppTheme.successColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCheckInButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          'Check-in',
          style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSmallDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconSm(icon, color: Colors.white38),
        const HGapSm(),
        Text(
          text,
          style: AppTheme.bodySmall.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
