import 'package:flutter/material.dart';

class BottomCTAContainer extends StatelessWidget {
  final Widget child;

  const BottomCTAContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: child,
    );
  }
}
