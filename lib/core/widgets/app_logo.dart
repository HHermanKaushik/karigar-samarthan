import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo/app_icon.png',
          width: size,
          height: size,
        ),
        const SizedBox(height: 12),
        Text(
          'KARIGAR SAMARTHAN',
          style: TextStyle(
            color: AppColors.primaryDark,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.13,
          ),
        ),
      ],
    );
  }
}
