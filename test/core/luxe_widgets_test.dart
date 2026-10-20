import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/luxe/tokens.dart';
import 'package:shadapp_client/core/widgets/luxe/luxe_widgets.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr, Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (c, w) => Directionality(textDirection: dir, child: w!),
    home: Scaffold(body: child),
  );
}

void main() {
  test('status colours come from the mockup tokens', () {
    expect(lxStatusColor(LxStatus.ok), const Color(0xFF8FB98B));
    expect(lxStatusColor(LxStatus.wait), const Color(0xFFC9B27A));
    expect(lxStatusColor(LxStatus.bad), const Color(0xFFD24A4A));
    expect(lxStatusColor(LxStatus.off), const Color(0xFF8A8A8A));
  });

  testWidgets('status dot uses the status colour', (t) async {
    await t.pumpWidget(_host(const LuxeStatusDot(key: ValueKey('d'), status: LxStatus.wait)));
    final box = t.widget<Container>(find.descendant(of: find.byKey(const ValueKey('d')), matching: find.byType(Container)));
    expect((box.decoration as BoxDecoration).color, Lx.wait);
  });

  testWidgets('status chip shows label', (t) async {
    await t.pumpWidget(_host(const LuxeStatusChip(status: LxStatus.ok, label: 'Active')));
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('button fires, and is inert when disabled', (t) async {
    var n = 0;
    await t.pumpWidget(_host(Column(children: [
      LuxeButton(key: const ValueKey('b1'), label: 'Go', kind: LuxeButtonKind.primary, onPressed: () => n++),
      const LuxeButton(key: ValueKey('b2'), label: 'Off', onPressed: null),
    ])));
    await t.tap(find.byKey(const ValueKey('b1')));
    await t.tap(find.byKey(const ValueKey('b2')), warnIfMissed: false);
    expect(n, 1);
  });

  testWidgets('stepper bars fill up to current', (t) async {
    await t.pumpWidget(_host(const LuxeStepperBars(total: 4, current: 2)));
    Color c(int i) => (t.widget<Container>(find.byKey(ValueKey('lx-step-$i'))).decoration as BoxDecoration).color!;
    expect(c(1), Lx.crimsonInk);
    expect(c(2), Lx.crimsonInk);
    expect(c(3), Lx.line2);
    expect(c(4), Lx.line2);
  });

  testWidgets('progress split clamps and starts at the reading edge', (t) async {
    await t.pumpWidget(_host(const SizedBox(width: 200, child: LuxeProgressSplit(fraction: 1.7))));
    expect(t.widget<FractionallySizedBox>(find.byKey(const ValueKey('lx-progress-fill'))).widthFactor, 1.0);
    await t.pumpWidget(_host(const SizedBox(width: 200, child: LuxeProgressSplit(fraction: double.nan))));
    expect(t.widget<FractionallySizedBox>(find.byKey(const ValueKey('lx-progress-fill'))).widthFactor, 0.0);
  });

  testWidgets('bottom nav: tap, badge, active dot, RTL', (t) async {
    int? tapped;
    await t.pumpWidget(_host(
      LuxeBottomNav(
        currentIndex: 0,
        onTap: (i) => tapped = i,
        items: const [
          LuxeNavItem(id: 'home', icon: Icons.home, label: 'Home'),
          LuxeNavItem(id: 'appr', icon: Icons.check, label: 'Approvals', badge: 120),
          LuxeNavItem(id: 'more', icon: Icons.more_horiz, label: 'More'),
        ],
      ),
      dir: TextDirection.rtl,
      locale: const Locale('ar'),
    ));
    expect(find.text('99+'), findsOneWidget);
    expect(find.byKey(const ValueKey('lx-nav-badge-home')), findsNothing);
    expect(find.byKey(const ValueKey('lx-nav-active-dot')), findsOneWidget);
    // RTL: first item sits on the right of the second.
    expect(t.getCenter(find.byKey(const ValueKey('lx-nav-home'))).dx, greaterThan(t.getCenter(find.byKey(const ValueKey('lx-nav-more'))).dx));
    await t.tap(find.byKey(const ValueKey('lx-nav-appr')));
    expect(tapped, 1);
  });

  testWidgets('nav respects bottom safe area', (t) async {
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Scaffold(
          bottomNavigationBar: LuxeBottomNav(currentIndex: 0, onTap: (_) {}, items: const [LuxeNavItem(id: 'a', icon: Icons.home, label: 'A')]),
        ),
      ),
    ));
    final navBottom = t.getBottomLeft(find.byType(LuxeBottomNav)).dy;
    final dotBottom = t.getBottomLeft(find.byKey(const ValueKey('lx-nav-active-dot'))).dy;
    expect(navBottom - dotBottom, greaterThanOrEqualTo(34));
  });

  testWidgets('sheet shows handle + content and is dismissible', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            key: const ValueKey('open'),
            onPressed: () => showLuxeSheet<void>(ctx, builder: (_) => const Text('Inside')),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.byKey(const ValueKey('open')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('lx-sheet-handle')), findsOneWidget);
    expect(find.text('Inside'), findsOneWidget);
  });

  testWidgets('card, banner, kpi, section header, switch row render', (t) async {
    bool v = false;
    await t.pumpWidget(_host(StatefulBuilder(
      builder: (c, set) => ListView(children: [
        const LuxeCard(attention: true, child: Text('card')),
        const LuxePinnedBanner(text: 'pay now', tone: LuxeBannerTone.pay),
        const LuxeKpiTile(value: '12', label: 'Clients'),
        const LuxeSectionHeader(title: 'Section'),
        LuxeSwitchRow(label: 'Sw', value: v, onChanged: (x) => set(() => v = x)),
      ]),
    )));
    for (final s in ['card', 'pay now', '12', 'Clients', 'Section', 'Sw']) {
      expect(find.text(s), findsOneWidget);
    }
    await t.tap(find.byType(Switch));
    await t.pump();
    expect(v, isTrue);
  });
}
