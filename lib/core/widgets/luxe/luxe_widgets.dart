import 'package:flutter/material.dart';
import '../../luxe/lx_icons.dart';
import '../../luxe/tokens.dart';

/// Luxe widget library (Plan 1, س٠). Every widget takes an optional [key];
/// screens give them fixed ValueKeys so tests survive re-skins.

// ── Card ──
class LuxeCard extends StatelessWidget {
  final Widget child;
  final bool attention; // the red "ap" variant
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const LuxeCard({super.key, required this.child, this.attention = false, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: attention ? Lx.cardApGradient : Lx.cardGradient,
        borderRadius: BorderRadius.circular(Lx.rCard),
        border: Border.all(color: attention ? Lx.cardApBorder : Lx.cardBorder),
      ),
      child: child,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: onTap == null
          ? box
          : InkWell(borderRadius: BorderRadius.circular(Lx.rCard), onTap: onTap, child: box),
    );
  }
}

// ── Status dot / chip ──
class LuxeStatusDot extends StatelessWidget {
  final LxStatus status;
  final double size;
  const LuxeStatusDot({super.key, required this.status, this.size = 7});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: lxStatusColor(status), shape: BoxShape.circle),
      );
}

class LuxeStatusChip extends StatelessWidget {
  final LxStatus status;
  final String label;
  const LuxeStatusChip({super.key, required this.status, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = lxStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: c.withAlpha(102))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LuxeStatusDot(status: status, size: 6),
        const SizedBox(width: 6),
        Text(label, style: Lx.text(context, size: 11, color: c)),
      ]),
    );
  }
}

// ── Button ──
enum LuxeButtonKind { primary, outline, quiet, danger }

enum LuxeButtonSize { sm, md, lg }

class LuxeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final LuxeButtonKind kind;
  final LuxeButtonSize size;
  final IconData? icon;
  /// Mockup icon name (see lx_icons.dart); wins over [icon].
  final String? lxIcon;
  const LuxeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = LuxeButtonKind.outline,
    this.size = LuxeButtonSize.md,
    this.icon,
    this.lxIcon,
  });

  @override
  Widget build(BuildContext context) {
    final h = size == LuxeButtonSize.sm ? 32.0 : size == LuxeButtonSize.lg ? 48.0 : 40.0;
    final fs = size == LuxeButtonSize.sm ? 12.0 : size == LuxeButtonSize.lg ? 14.0 : 13.0;
    final pad = size == LuxeButtonSize.sm ? 13.0 : 18.0;
    final primary = kind == LuxeButtonKind.primary;
    final fg = primary ? Colors.white : kind == LuxeButtonKind.danger ? Lx.danger : Lx.ink2;
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: primary ? Lx.crimson : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: primary ? Lx.crimson : kind == LuxeButtonKind.quiet ? Colors.transparent : Lx.line2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: Container(
            height: h,
            padding: EdgeInsets.symmetric(horizontal: pad),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (lxIcon != null) ...[LxIcon(lxIcon!, size: 15, color: fg), const SizedBox(width: 8)]
              else if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 8)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: fs, color: fg))),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Section header ──
class LuxeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const LuxeSectionHeader({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: Lx.text(context, size: 12, color: Lx.muted, weight: FontWeight.w500))),
          if (trailing != null) trailing!,
        ]),
      );
}

// ── Pinned banner (info / pay) ──
enum LuxeBannerTone { info, pay }

class LuxePinnedBanner extends StatelessWidget {
  final String text;
  final LuxeBannerTone tone;
  final VoidCallback? onTap;
  const LuxePinnedBanner({super.key, required this.text, this.tone = LuxeBannerTone.info, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = tone == LuxeBannerTone.pay ? Lx.wait : Lx.ink2;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: c.withAlpha(20),
          border: Border(bottom: BorderSide(color: c.withAlpha(46))),
        ),
        child: Text(text, style: Lx.text(context, size: 12, color: c)),
      ),
    );
  }
}

// ── KPI tile ──
class LuxeKpiTile extends StatelessWidget {
  final String value;
  final String label;
  const LuxeKpiTile({super.key, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: Lx.cardGradient,
          borderRadius: BorderRadius.circular(Lx.rCard),
          border: Border.all(color: Lx.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: Lx.display(context, size: 26)),
          const SizedBox(height: 4),
          Text(label, style: Lx.text(context, size: 11, color: Lx.muted)),
        ]),
      );
}

// ── Stepper bars: done = green, current = red, rest = line (client mockup .bars) ──
class LuxeStepperBars extends StatelessWidget {
  final int total;
  final int current; // 1-based; bars before it are done, it is the current one
  const LuxeStepperBars({super.key, required this.total, required this.current});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 1; i <= total; i++) ...[
          Expanded(
            child: Container(
              key: ValueKey('lx-step-$i'),
              height: 3,
              decoration: BoxDecoration(
                color: i < current ? Lx.ok : i == current ? Lx.crimsonInk : Lx.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < total) const SizedBox(width: 5),
        ],
      ]);
}

// ── Two-tone progress (paid vs. total) ──
class LuxeProgressSplit extends StatelessWidget {
  final double fraction; // 0..1
  const LuxeProgressSplit({super.key, required this.fraction});
  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: Stack(children: [
          Container(color: Lx.line2),
          FractionallySizedBox(
            key: const ValueKey('lx-progress-fill'),
            alignment: AlignmentDirectional.centerStart,
            widthFactor: f,
            child: Container(color: Lx.ok),
          ),
        ]),
      ),
    );
  }
}

// ── Switch row ──
class LuxeSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const LuxeSwitchRow({super.key, required this.label, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Lx.text(context, size: 13, color: enabled ? Lx.ink : Lx.faint)),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ── Permission group (title + rows) ──
class LuxePermGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const LuxePermGroup({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(title, style: Lx.text(context, size: 12, weight: FontWeight.w700, color: Lx.wait)),
        ),
        ...children,
      ]);
}

// ── Bottom navigation ──
class LuxeNavItem {
  final IconData icon;
  final String label;
  final int badge;
  final String id;
  const LuxeNavItem({required this.id, required this.icon, required this.label, this.badge = 0});
}

class LuxeBottomNav extends StatelessWidget {
  final List<LuxeNavItem> items;
  final int currentIndex; // -1 = none selected (e.g. "More" screens)
  final ValueChanged<int> onTap;
  const LuxeBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Lx.rail, border: Border(top: BorderSide(color: Lx.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  key: ValueKey('lx-nav-${items[i].id}'),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Icon(items[i].icon, size: 22, color: i == currentIndex ? Lx.ink : Lx.muted),
                        if (items[i].badge > 0)
                          PositionedDirectional(
                            top: -4,
                            end: -10,
                            child: Container(
                              key: ValueKey('lx-nav-badge-${items[i].id}'),
                              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(color: Lx.crimson, borderRadius: BorderRadius.circular(8)),
                              alignment: Alignment.center,
                              child: Text(items[i].badge > 99 ? '99+' : '${items[i].badge}',
                                  style: Lx.text(context, size: 9.5, color: Colors.white)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(items[i].label, style: Lx.text(context, size: 10.5, color: i == currentIndex ? Lx.ink : Lx.muted)),
                      const SizedBox(height: 3),
                      Container(
                        key: i == currentIndex ? const ValueKey('lx-nav-active-dot') : null,
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: i == currentIndex ? Lx.crimsonInk : Colors.transparent, shape: BoxShape.circle),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom sheet ──
Future<T?> showLuxeSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Lx.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
      side: BorderSide(color: Lx.line2),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                key: const ValueKey('lx-sheet-handle'),
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            builder(ctx),
          ]),
        ),
      ),
    ),
  );
}


// ── Pulse dot (waiting states): a 12px dot with an expanding ring ──
class LuxePulseDot extends StatefulWidget {
  final Color color;
  const LuxePulseDot({super.key, this.color = Lx.wait});
  @override
  State<LuxePulseDot> createState() => _LuxePulseDotState();
}

class _LuxePulseDotState extends State<LuxePulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 12,
        height: 12,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = (_c.value / 0.7).clamp(0.0, 1.0); // ring grows over the first 70%
            return DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withAlpha(((1 - t) * 128).round()),
                    spreadRadius: 12 * t,
                  ),
                ],
              ),
            );
          },
        ),
      );
}

// ── Dashed-border box (the mockup's `.drop`: 1px dashed line2, radius 12) ──
class LuxeDashedBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color color;
  const LuxeDashedBox({
    super.key,
    required this.child,
    this.radius = 12,
    this.padding = const EdgeInsets.all(18),
    this.color = Lx.line2,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DashedRRectPainter(color: color, radius: radius),
        child: Padding(padding: padding, child: child),
      );
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)));
    const dash = 4.0, gap = 3.0;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color || old.radius != radius;
}
