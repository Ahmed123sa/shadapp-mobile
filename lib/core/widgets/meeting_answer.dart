import 'package:flutter/material.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../luxe/tokens.dart';
import 'luxe/luxe_widgets.dart';

/// The client's answer about the time of a meeting: 'pending' until they
/// reply, then 'accepted' or 'declined' (with an optional note). The server
/// keeps it on the meeting and on its chat cards, and resets it to 'pending'
/// when the meeting is moved.
String normalizeMeetingResponse(Object? raw) => raw == 'accepted' || raw == 'declined' ? raw as String : 'pending';

/// What the company sees on a meeting: waiting, accepted, or asked for another time.
class MeetingResponseBadge extends StatelessWidget {
  const MeetingResponseBadge({super.key, required this.response, this.note});

  final Object? response;
  final Object? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = normalizeMeetingResponse(response);
    final text = switch (value) {
      'accepted' => l10n.meetingResponseAccepted,
      'declined' => l10n.meetingResponseDeclined,
      _ => l10n.meetingResponsePending,
    };
    final noteText = '${note ?? ''}'.trim();

    return Column(
      key: ValueKey('meeting-response-$value'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          LuxeStatusDot(status: switch (value) { 'accepted' => LxStatus.ok, 'declined' => LxStatus.bad, _ => LxStatus.wait }),
          const SizedBox(width: 7),
          Flexible(child: Text(text, style: Lx.text(context, size: 12, color: Lx.ink2))),
        ]),
        if (value == 'declined' && noteText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(l10n.meetingResponseNote(noteText), style: Lx.text(context, size: 12, color: Lx.muted)),
          ),
      ],
    );
  }
}

/// What the client sees on the card: the question with two buttons, then
/// their answer with a way to change it.
class MeetingAnswer extends StatefulWidget {
  const MeetingAnswer({
    super.key,
    required this.response,
    required this.note,
    required this.canAnswer,
    required this.onAnswer,
  });

  final Object? response;
  final Object? note;

  /// False for an old card of the same meeting, or a meeting that is over.
  final bool canAnswer;

  final Future<void> Function(String response, String? note) onAnswer;

  @override
  State<MeetingAnswer> createState() => _MeetingAnswerState();
}

class _MeetingAnswerState extends State<MeetingAnswer> {
  final _noteController = TextEditingController();
  bool _declining = false;
  bool _changing = false;
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _send(String response) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onAnswer(response, response == 'declined' ? _noteController.text.trim() : null);
      if (!mounted) return;
      setState(() {
        _declining = false;
        _changing = false;
        _noteController.clear();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pill(String label, VoidCallback? onTap, {Key? key, bool strong = false}) => GestureDetector(
        key: key,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Lx.rPill),
              border: Border.all(color: strong ? Lx.crimson : Lx.line2),
              color: strong ? Lx.crimson.withAlpha(30) : null,
            ),
            child: Text(label, style: Lx.text(context, size: 12.5, color: onTap == null ? Lx.faint : Lx.ink)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = normalizeMeetingResponse(widget.response);
    final answered = value != 'pending';
    final showButtons = widget.canAnswer && (!answered || _changing);

    if (!showButtons) {
      if (!answered) return const SizedBox.shrink();
      final noteText = '${widget.note ?? ''}'.trim();
      return Column(
        key: ValueKey('meeting-answer-$value'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value == 'accepted'
                ? l10n.meetingAnswerYouAccepted
                : (noteText.isNotEmpty ? '${l10n.meetingAnswerYouDeclined} — $noteText' : l10n.meetingAnswerYouDeclined),
            style: Lx.text(context, size: 12.5, color: Lx.ink2),
          ),
          if (widget.canAnswer)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _pill(l10n.meetingAnswerChange, _busy ? null : () => setState(() => _changing = true), key: const ValueKey('meeting-answer-change')),
            ),
        ],
      );
    }

    return Column(
      key: const ValueKey('meeting-answer-pending'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.meetingAnswerQuestion, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
        const SizedBox(height: 6),
        if (_declining) ...[
          TextField(
            key: const ValueKey('meeting-answer-note'),
            controller: _noteController,
            maxLength: 500,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(hintText: l10n.meetingAnswerNoteHint),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(l10n.meetingAnswerSend, _busy ? null : () => _send('declined'), key: const ValueKey('meeting-answer-send'), strong: true),
            _pill(l10n.meetingAnswerCancel, _busy ? null : () => setState(() {
                  _declining = false;
                  _noteController.clear();
                }), key: const ValueKey('meeting-answer-cancel')),
          ]),
        ] else
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(l10n.meetingAnswerAccept, _busy ? null : () => _send('accepted'), key: const ValueKey('meeting-answer-accept'), strong: true),
            _pill(l10n.meetingAnswerDecline, _busy ? null : () => setState(() => _declining = true), key: const ValueKey('meeting-answer-decline')),
          ]),
      ],
    );
  }
}
