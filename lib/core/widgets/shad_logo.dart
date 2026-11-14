import 'package:flutter/material.dart';

class ShadLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const ShadLogo({super.key, this.size = 48, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.15),
          child: Image.asset(
            'assets/images/logo.jpg',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 8),
          Text('SHAD', style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
            color: const Color(0xFF1A1A1A),
            fontFamily: 'PlayfairDisplay',
          )),
        ],
      ],
    );
  }
}
