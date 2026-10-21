import 'package:flutter/material.dart';
import '../luxe/tokens.dart';

/// Loading placeholders in the Luxe language: crimson-ink spinner, or
/// skeleton `.card`s (card gradient, line border, r16) with line-2 bars.
class LoadingState extends StatelessWidget {
  final LoadingStyle style;
  final int itemCount;

  const LoadingState({super.key, this.style = LoadingStyle.list, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      LoadingStyle.spinner => const Center(child: CircularProgressIndicator(color: Lx.crimsonInk, strokeWidth: 2.5)),
      LoadingStyle.list => ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8),
          itemCount: itemCount,
          itemBuilder: (_, __) => _skeletonCard(),
        ),
      LoadingStyle.grid => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: itemCount,
          itemBuilder: (_, __) => _skeletonBox(),
        ),
    };
  }

  static const _card = BoxDecoration(
    gradient: Lx.cardGradient,
    borderRadius: BorderRadius.all(Radius.circular(Lx.rCard)),
    border: Border.fromBorderSide(BorderSide(color: Lx.line)),
  );

  Widget _skeletonCard() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: _card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 10, width: 70, decoration: _bar()),
          const SizedBox(height: 10),
          Container(height: 14, width: 180, decoration: _bar()),
          const SizedBox(height: 8),
          Container(height: 11, width: 120, decoration: _bar()),
        ]),
      );

  Widget _skeletonBox() => Container(
        decoration: _card,
        child: Center(child: Container(height: 14, width: 80, decoration: _bar())),
      );

  BoxDecoration _bar() => BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(6));
}

enum LoadingStyle { spinner, list, grid }
