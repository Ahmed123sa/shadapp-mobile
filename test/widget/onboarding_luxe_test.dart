import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/luxe/tokens.dart';
import 'package:shadapp_client/core/luxe/lx_icons.dart';
import 'package:shadapp_client/core/widgets/luxe/luxe_widgets.dart';
import 'package:shadapp_client/features/onboarding/client_onboarding_stages.dart';
import 'package:shadapp_client/features/onboarding/onboarding_signature_pad.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('boxed waiting stage: card + pulse + notify hint', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(builder: (ctx) => buildWaitingStage(context: ctx, title: 'Waiting', subtitle: 'Hang on')),
    );
    expect(find.byKey(const ValueKey('waiting-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('waiting-pulse')), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.textContaining('notify you'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop the repeating pulse
  });

  testWidgets('bare waiting stage has no card', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(builder: (ctx) => buildWaitingStage(context: ctx, title: 'Reviewing', subtitle: 'Soon', boxed: false)),
    );
    expect(find.byKey(const ValueKey('waiting-card')), findsNothing);
    expect(find.byKey(const ValueKey('waiting-plain')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('next list numbers the remaining steps 0N and hides when empty', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => buildNextList(
          context: ctx,
          title: 'What happens next',
          steps: const [MapEntry(4, 'Payment proof'), MapEntry(5, 'Activate')],
        ),
      ),
    );
    expect(find.text('05'), findsOneWidget);
    expect(find.text('06'), findsOneWidget);
    expect(find.text('Payment proof'), findsOneWidget);

    await pumpWithLocalizations(
      tester,
      Builder(builder: (ctx) => buildNextList(context: ctx, title: 'x', steps: const [])),
    );
    expect(find.byKey(const ValueKey('next-steps')), findsNothing);
  });

  testWidgets('payment stage shows the bill rows and the rejection card', (tester) async {
    final ws = {
      'id': 5,
      'contracts': [
        {'id': 7, 'status': 'company_approved', 'value': '14500', 'currency': 'EGP'}
      ],
      'payments': [
        {'status': 'approved', 'amount': '1000'},
        {'status': 'rejected', 'rejection_reason': 'Blurry'},
      ],
    };
    await pumpWithLocalizations(
      tester,
      SingleChildScrollView(
        child: Builder(
          builder: (ctx) => buildPaymentStage(context: ctx, workspace: ws, client: {'client_type': 'individual'}, taxSettings: null),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('payment-bill-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('payment-rejected-card')), findsOneWidget);
    expect(find.textContaining('Blurry'), findsOneWidget);
    expect(find.textContaining('14,500'), findsWidgets);
    expect(find.textContaining('13,500'), findsOneWidget); // remaining
  });

  final sentWs = {
    'id': 5,
    'contracts': [
      {
        'id': 7,
        'status': 'sent',
        'title': 'Retainer 2026',
        'value': '14500',
        'currency': 'EGP',
        'pdf_url': '/c.pdf',
        'updated_at': '2026-10-12T10:00:00Z',
        'clauses': [{}, {}, {}],
        'required_documents': [
          {'id': 1, 'name': 'Commercial register', 'status': 'pending', 'files': [{'status': 'pending', 'file_url': '/f.pdf'}]},
          {'id': 2, 'name': 'Tax card', 'status': 'missing', 'files': []},
        ],
      }
    ],
  };

  testWidgets('contract review: card with title/amount/PDF and a docs card with uploaded + missing', (tester) async {
    final uploads = <List<int>>[];
    final opened = <String>[];
    await pumpWithLocalizations(
      tester,
      SingleChildScrollView(
        child: Builder(
          builder: (ctx) => buildContractReviewStage(
            context: ctx,
            workspace: sentWs,
            onPreviewContract: (_) {},
            uploadingDocId: null,
            onUploadDocument: (c, d) => uploads.add([c, d]),
            onOpenFile: opened.add,
          ),
        ),
      ),
    );
    expect(find.text('Retainer 2026'), findsOneWidget);
    expect(find.textContaining('14,500'), findsOneWidget);
    expect(find.text('Sent 12 Oct · 3 clauses'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-download-pdf')), findsOneWidget);
    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-doc-upload-1')));
    await tester.tap(find.byKey(const ValueKey('onboarding-doc-open-0')));
    await tester.tap(find.byKey(const ValueKey('onboarding-download-pdf')));
    expect(uploads, [[7, 2]]);
    expect(opened, ['/f.pdf', '/c.pdf']);
  });

  testWidgets('approve actions: approve is disabled while a required document is missing', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => Column(children: buildContractReviewActions(context: ctx, workspace: sentWs, onRespond: (_) {})),
      ),
    );
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-approve'))).onPressed, isNull);
    expect(find.byKey(const ValueKey('onboarding-request-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-docs-hint')), findsOneWidget);
  });

  testWidgets('payment actions: one send button', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => Column(
          children: buildPaymentActions(context: ctx, workspace: sentWs, client: null, taxSettings: null, onSendPayment: (_, __, ___) {}),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('onboarding-send-payment')), findsOneWidget);
  });

  testWidgets('sent payment card shows the pending payment, nothing otherwise', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => buildSentPaymentCard(context: ctx, workspace: {
          'payments': [
            {'status': 'pending', 'amount': '16530', 'currency': 'EGP', 'method_type': 'instapay'}
          ]
        }),
      ),
    );
    expect(find.textContaining('Payment sent · InstaPay'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.textContaining('16,530'), findsOneWidget);

    await pumpWithLocalizations(
      tester,
      Builder(builder: (ctx) => buildSentPaymentCard(context: ctx, workspace: {'payments': []})),
    );
    expect(find.byKey(const ValueKey('sent-payment-card')), findsNothing);
  });

  testWidgets('signature box: modes switch, drawing enables Save, clear disables it', (tester) async {
    final draft = SignatureDraft();
    var picked = 0;
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => SingleChildScrollView(
          child: Column(children: [
            buildSignatureStage(
              context: ctx,
              client: {'contact_person': 'Ali'},
              draft: draft,
              onPickImage: () => picked++,
              onDrawingChanged: (_) {},
            ),
            ...buildSignatureActions(context: ctx, draft: draft, saving: false, onSave: () async {}),
          ]),
        ),
      ),
    );
    expect(find.text('Welcome Ali'), findsOneWidget);
    expect(find.byKey(const ValueKey('sig-mode-draw')), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-sign'))).onPressed, isNull);

    final pad = find.byKey(const ValueKey('sig-pad'));
    final g = await tester.startGesture(tester.getCenter(pad));
    await g.moveBy(const Offset(40, 10));
    await g.moveBy(const Offset(30, -20));
    await g.up();
    await tester.pump();
    expect(draft.strokes.length, 1);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-sign'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('sig-clear')));
    await tester.pump();
    expect(draft.strokes, isEmpty);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-sign'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('sig-mode-type')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('sig-text')), 'Ali Hassan');
    await tester.pump();
    expect(draft.mode, SignatureMode.type);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-sign'))).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('sig-mode-upload')));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-sign'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('sig-pick')));
    expect(picked, 1);
    draft.pick('/tmp/s.png', 's.png');
    await tester.pump();
    expect(find.text('s.png'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('onboarding-sign'))).onPressed, isNotNull);
    draft.dispose();
  });

  testWidgets('every mockup icon renders as an SVG at the requested size', (tester) async {
    await pumpWithLocalizations(
      tester,
      Wrap(children: [for (final n in lxIconNames) LxIcon(n, key: ValueKey('ic-$n'), size: 20, color: Colors.white)]),
    );
    await tester.pump();
    expect(lxIconNames.length, 23);
    for (final n in lxIconNames) {
      expect(tester.getSize(find.byKey(ValueKey('ic-$n'))), const Size(20, 20));
    }
  });

  testWidgets('dashed box paints around its child', (tester) async {
    await pumpWithLocalizations(tester, const LuxeDashedBox(child: Text('drop')));
    expect(find.text('drop'), findsOneWidget);
    expect(find.descendant(of: find.byType(LuxeDashedBox), matching: find.byType(CustomPaint)), findsWidgets);
  });

  testWidgets('headings use the Arabic face in Arabic and the serif in English', (tester) async {
    TextStyle? style;
    Widget probe() => Builder(builder: (ctx) {
          style = Lx.display(ctx);
          return const SizedBox();
        });
    await pumpWithLocalizations(tester, probe());
    expect(style?.fontFamily, Lx.serif);
    await pumpWithLocalizations(tester, probe(), locale: const Locale('ar'));
    expect(style?.fontFamily, Lx.arabic);
  });

  testWidgets('review actions: request edit calls the inline-edit callback', (tester) async {
    var editTapped = false;
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => Column(children: [
          ...buildContractReviewActions(context: ctx, workspace: sentWs, onRespond: (_) {}, onRequestEdit: () => editTapped = true),
        ]),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-request-edit')));
    expect(editTapped, isTrue);
  });

  testWidgets('inline edit card sends and cancels', (tester) async {
    final ctrl = TextEditingController();
    var sent = 0, cancelled = 0;
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => buildEditRequestCard(context: ctx, controller: ctrl, sending: false, onSend: () => sent++, onCancel: () => cancelled++),
      ),
    );
    expect(find.text('What would you like changed?'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('onboarding-edit-text')), 'Two instalments please');
    await tester.tap(find.byKey(const ValueKey('onboarding-edit-send')));
    await tester.tap(find.byKey(const ValueKey('onboarding-edit-cancel')));
    expect(ctrl.text, 'Two instalments please');
    expect([sent, cancelled], [1, 1]);
  });

  testWidgets('edit reason quote', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(builder: (ctx) => buildEditReasonQuote(ctx, 'Split it in two')),
    );
    expect(find.text('YOUR REQUEST'), findsOneWidget);
    expect(find.text('Split it in two'), findsOneWidget);
  });
}
