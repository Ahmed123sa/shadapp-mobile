import 'package:flutter/material.dart';
import '../theme.dart';

class LoadingState extends StatelessWidget {
  final LoadingStyle style;
  final int itemCount;

  const LoadingState({super.key, this.style = LoadingStyle.list, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      LoadingStyle.spinner => const Center(child: CircularProgressIndicator()),
      LoadingStyle.list => ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          itemBuilder: (_, __) => _shimmerCard(),
        ),
      LoadingStyle.grid => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: itemCount,
          itemBuilder: (_, __) => _shimmerBox(),
        ),
    };
  }

  Widget _shimmerCard() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: ShadColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ShadColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 16, width: 180, decoration: _shimmer()),
      const SizedBox(height: 8),
      Container(height: 12, width: 120, decoration: _shimmer()),
      const SizedBox(height: 6),
      Container(height: 12, width: 80, decoration: _shimmer()),
    ]),
  );

  Widget _shimmerBox() => Container(
    decoration: BoxDecoration(color: ShadColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ShadColors.cardBorder)),
    child: Center(child: Container(height: 14, width: 80, decoration: _shimmer())),
  );

  BoxDecoration _shimmer() => BoxDecoration(
    color: ShadColors.cardBorder,
    borderRadius: BorderRadius.circular(6),
  );
}

enum LoadingStyle { spinner, list, grid }
