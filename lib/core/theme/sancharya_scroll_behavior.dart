import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Custom ScrollBehavior for SANCHARYA
/// Resolves the Android 12+ stretching overscroll bug on Pixel devices.
/// Prevents cards, text, and buttons from stretching/distorting vertically like rubber.
class SancharyaScrollBehavior extends MaterialScrollBehavior {
  const SancharyaScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Replace the default Android 12+ StretchingOverscrollIndicator with a subtle glowing edge
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: AppColors.primaryGreen.withAlpha(40),
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Clamping physics guarantees zero vertical layout distortion/stretching
    return const ClampingScrollPhysics();
  }
}
