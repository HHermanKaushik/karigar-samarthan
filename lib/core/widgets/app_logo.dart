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
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'KS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
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
