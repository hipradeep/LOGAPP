import 'package:flutter/material.dart';

import '../models/contact.dart';
import '../theme/app_theme.dart';

class ContactAvatar extends StatelessWidget {
  final Contact contact;
  final double size;

  const ContactAvatar({super.key, required this.contact, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final tint = AppTheme.tintFor(context, contact.avatarColorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.$1,
        shape: BoxShape.circle,
        border: Border.all(color: tint.$3),
      ),
      alignment: Alignment.center,
      child: Text(
        contact.initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          color: tint.$2,
        ),
      ),
    );
  }
}
