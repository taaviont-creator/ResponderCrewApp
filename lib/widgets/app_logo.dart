import 'package:flutter/material.dart';

/// The supplied brand artwork; adjacent headings provide its accessible name.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size / 10),
    child: Image.asset(
      'assets/branding/respondcrew-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    ),
  );
}
