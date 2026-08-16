import 'package:flutter/material.dart';

/// Wrapper that presents [child] as a tall rounded bottom sheet so the user
/// keeps psychological context of the Home screen behind it.
Future<T?> showAppModal<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      // The Padding above already shifts the whole sheet up by the keyboard
      // height. Without this, every screen opened through showAppModal
      // (any Scaffold with resizeToAvoidBottomInset: true inside [child])
      // sees the SAME viewInsets.bottom again and shrinks a second time -
      // double-counting the keyboard. That corrupts how much room the
      // screen thinks it has, which is what caused a hard layout overflow
      // on one screen and, on plain scrollable forms, made the actively
      // focused field scroll to the wrong spot (covered by the keyboard,
      // so typed digits weren't visible). Stripping the bottom inset here
      // means descendants only ever account for it once.
      child: MediaQuery.removeViewInsets(
        context: ctx,
        removeBottom: true,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Material(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
