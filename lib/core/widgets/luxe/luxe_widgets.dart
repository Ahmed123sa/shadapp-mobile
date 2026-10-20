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
        height: 6,
        child: Stack(children: [
          Container(color: Lx.line2),
          FractionallySizedBox(
            key: const ValueKey('lx-progress-fill'),
            alignment: AlignmentDirectional.centerStart,
            widthFactor: f,
            child: Container(
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Lx.ok, Color(0xFFA9D1A5)])),
            ),
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

// ── Bottom navigation (client mockup .nav) ──
class LuxeNavItem {
  final IconData? icon; // Material icon (legacy)
  final String? lxIcon; // mockup icon name (lx_icons.dart); wins over [icon]
  final String label;
  final int badge;
  final String id;
  const LuxeNavItem({required this.id, this.icon, this.lxIcon, required this.label, this.badge = 0});
}

class LuxeBottomNav extends StatelessWidget {
  final List<LuxeNavItem> items;
  final int currentIndex; // -1 = none selected
  final ValueChanged<int> onTap;
  const LuxeBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  // Mockup `.nav`: padding 6px 4px 20px, rail background, top hairline.
  // Each button: padding 6px 0, icon 18, gap 3, label 10.5px. The active dot
  // is drawn *under* the button (bottom:-2px), outside the layout flow.
  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(color: Lx.rail, border: Border(top: BorderSide(color: Lx.line))),
      padding: EdgeInsets.fromLTRB(4, 6, 4, inset > 20 ? inset : 20),
      child: Row(children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              key: ValueKey('lx-nav-${items[i].id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: LayoutBuilder(builder: (context, c) {
                final on = i == currentIndex;
                final color = on ? Lx.ink : Lx.muted;
                final it = items[i];
                return Stack(clipBehavior: Clip.none, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: it.lxIcon != null
                              ? LxIcon(it.lxIcon!, size: 18, color: color)
                              : Icon(it.icon, size: 18, color: color),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10.5, color: color, height: 1.5)),
                    ]),
                  ),
                  if (on)
                    Positioned(
                      bottom: -2,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          key: const ValueKey('lx-nav-active-dot'),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(color: Lx.crimsonInk, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  if (it.badge > 0)
                    PositionedDirectional(
                      top: 2,
                      start: c.maxWidth / 2 + 6,
                      child: Container(
                        key: ValueKey('lx-nav-badge-${it.id}'),
                        constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: Lx.crimson, borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text(it.badge > 99 ? '99+' : '${it.badge}', style: Lx.text(context, size: 9.5, color: Colors.white, height: 1)),
                      ),
                    ),
                ]);
              }),
            ),
          ),
      ]),
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
    barrierColor: const Color(0x8C000000), // .scrim rgba(0,0,0,.55)
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
      side: BorderSide(color: Lx.line2),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                key: const ValueKey('lx-sheet-handle'),
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
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


// ── Page background: the mockup's two soft glows (.glow) ──
class LuxeGlow extends StatelessWidget {
  final Widget child;
  const LuxeGlow({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Stack(children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              key: ValueKey('lx-glow'),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.7, -1.05),
                  radius: 0.9,
                  colors: [Color(0x38941414), Color(0x00941414)],
                  stops: [0, 0.62],
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.9, 1.1),
                  radius: 0.8,
                  colors: [Color(0x12A8986A), Color(0x00A8986A)],
                  stops: [0, 0.6],
                ),
              ),
            ),
          ),
        ),
        child,
      ]);
}

// ── Top bar (mockup .top): d. mark, company, bell with pip, avatar ──
class LuxeTopBar extends StatelessWidget {
  final String company;
  final String avatarInitial;
  final bool unread; // crimson pip on the bell
  final VoidCallback? onBell;
  final VoidCallback? onAvatar;
  const LuxeTopBar({
    super.key,
    this.company = '',
    this.avatarInitial = '',
    this.unread = false,
    this.onBell,
    this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(children: [
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'd'),
            TextSpan(text: '.', style: TextStyle(fontStyle: FontStyle.normal, color: Lx.crimsonInk)),
          ]),
          key: ValueKey('lx-brand'),
          style: TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: 30, height: 1, color: Lx.ink),
        ),
        if (company.isNotEmpty)
          Flexible(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(company, maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 12.5, color: Lx.faint)),
              ),
            ),
          ),
        const Spacer(),
        SizedBox(
          width: 38,
          height: 38,
          child: InkResponse(
            key: const ValueKey('lx-bell'),
            onTap: onBell,
            radius: 20,
            child: Stack(alignment: Alignment.center, children: [
              const LxIcon('bell', size: 18, color: Lx.muted),
              if (unread)
                const PositionedDirectional(
                  top: 8,
                  end: 9,
                  child: SizedBox(
                    key: ValueKey('lx-bell-pip'),
                    width: 6,
                    height: 6,
                    child: DecoratedBox(decoration: BoxDecoration(color: Lx.crimsonInk, shape: BoxShape.circle)),
                  ),
                ),
            ]),
          ),
        ),
        SizedBox(
          width: 38,
          height: 38,
          child: InkResponse(
            key: const ValueKey('lx-avatar'),
            onTap: onAvatar,
            radius: 20,
            child: Center(child: LuxeAvatar(initial: avatarInitial)),
          ),
        ),
      ]),
    );
  }
}

// ── Avatar (mockup .av: 32px circle, serif italic initial) ──
class LuxeAvatar extends StatelessWidget {
  final String initial;
  final double size;
  const LuxeAvatar({super.key, required this.initial, this.size = 32});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          shape: BoxShape.circle,
          border: Border.all(color: Lx.line2),
        ),
        child: Text(initial, style: TextStyle(fontFamily: Lx.serif, fontStyle: FontStyle.italic, fontSize: size * 0.375 + 0.0, color: Lx.ink)),
      );
}

// ── Row in the "More" sheet (mockup .mrow) ──
class LuxeMoreRow extends StatelessWidget {
  final String lxIcon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool last;
  const LuxeMoreRow({super.key, required this.lxIcon, required this.label, required this.onTap, this.danger = false, this.last = false});
  @override
  Widget build(BuildContext context) {
    final color = danger ? Lx.danger : Lx.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
        child: Row(children: [
          LxIcon(lxIcon, size: 18, color: Lx.muted),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: Lx.text(context, size: 14.5, color: color))),
        ]),
      ),
    );
  }
}

// ── Page title (mockup `h1.h`): serif 26 with the crimson full stop ──
class LuxePageTitle extends StatelessWidget {
  final String text;
  const LuxePageTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final style = Lx.display(context, size: 26);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: text),
          TextSpan(text: '.', style: style.copyWith(color: Lx.crimsonInk, fontStyle: FontStyle.normal)),
        ]),
        key: const ValueKey('lx-page-title'),
        style: style,
      ),
    );
  }
}

// ── Small-caps kind label (mockup `.kind`) ──
class LuxeKind extends StatelessWidget {
  final String text;
  const LuxeKind(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 2.2));
}

// ── Amount with small currency (mockup `.amt`) ──
class LuxeAmount extends StatelessWidget {
  final String value;
  final String currency;
  final double size;
  const LuxeAmount(this.value, this.currency, {super.key, this.size = 20});
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: value, style: Lx.display(context, size: size)),
          TextSpan(text: ' $currency', style: Lx.text(context, size: 11, color: Lx.muted)),
        ])),
      );
}

// ── Labelled steps (mockup `.steps`): bar + caption, done green / now red ──
class LuxeLabeledSteps extends StatelessWidget {
  final List<String> labels;
  final int current; // steps before it are done, it is "now"; >= length = all done
  const LuxeLabeledSteps({super.key, required this.labels, required this.current});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  key: ValueKey('lx-cstep-$i'),
                  height: 3,
                  decoration: BoxDecoration(
                    color: i < current ? Lx.ok : i == current ? Lx.crimsonInk : Lx.line2,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 5),
                Text(labels[i], style: Lx.text(context, size: 9.5, color: i == current ? Lx.ink : Lx.faint)),
              ]),
            ),
            if (i < labels.length - 1) const SizedBox(width: 4),
          ],
        ]),
      );
}

// ── "Locked" hint line (mockup `hint()`): lock icon + faint text ──
class LuxeHint extends StatelessWidget {
  final String text;
  final bool center;
  const LuxeHint(this.text, {super.key, this.center = false});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          const LxIcon('lock', size: 14, color: Lx.faint),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: Lx.text(context, size: 12.5, color: Lx.faint))),
        ],
      );
}


// ── Mockup form look (`.f2 .in` underline fields, `.btn` pills, `.sw2` switch) ──
/// Wrap a form/page so stock TextFields, Elevated/Outlined buttons and
/// Switches pick up the Luxe look without changing their widget types.
class LuxeFormTheme extends StatelessWidget {
  final Widget child;
  const LuxeFormTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    const underline = UnderlineInputBorder(borderSide: BorderSide(color: Lx.line2));
    return Theme(
      data: base.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(0, 6, 0, 9),
          border: underline,
          enabledBorder: underline,
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.crimsonInk)),
          errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Lx.danger)),
          labelStyle: Lx.text(context, size: 12, color: Lx.muted),
          floatingLabelStyle: Lx.text(context, size: 12, color: Lx.muted),
          hintStyle: Lx.text(context, size: 15, color: Lx.faint),
        ),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Lx.crimsonInk),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Lx.crimson,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Lx.crimson.withAlpha(96),
            disabledForegroundColor: Colors.white70,
            elevation: 0,
            minimumSize: const Size(0, 44),
            shape: const StadiumBorder(),
            textStyle: Lx.text(context, size: 13, weight: FontWeight.w500),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Lx.ink2,
            side: const BorderSide(color: Lx.line2),
            minimumSize: const Size(0, 44),
            shape: const StadiumBorder(),
            textStyle: Lx.text(context, size: 13),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Lx.ink2, textStyle: Lx.text(context, size: 13)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF777777)),
          trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Lx.crimson : const Color(0xFF2A2A2A)),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      child: child,
    );
  }
}
