import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../data/assistant_repository.dart';

/// CLIENT_ASSISTANT_PLAN.md ٨ — the client's assistant. A button in the corner
/// of the workspace opens a chat-shaped sheet: ready questions, one tap each,
/// the answer from the client's own data and a button to the right tab. No free
/// typing and no fake "typing..." — the answer is there at once, because it is
/// not an AI.
///
/// It shows only when the server says it is switched on, and stays out of the
/// way (draws nothing) when anything goes wrong.
class ClientAssistantFab extends StatefulWidget {
  final ApiClient api;
  final int workspaceId;

  /// Called with a workspace tab name (contracts, payments, chat, approvals,
  /// files, meetings) when the client taps an answer's button.
  final ValueChanged<String> onNavigate;

  const ClientAssistantFab({super.key, required this.api, required this.workspaceId, required this.onNavigate});

  @override
  State<ClientAssistantFab> createState() => _ClientAssistantFabState();
}

class _ClientAssistantFabState extends State<ClientAssistantFab> {
  late final AssistantRepository _repo = AssistantRepository(api: widget.api);
  AssistantData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetch(widget.workspaceId);
      if (mounted) setState(() => _data = data);
    } catch (e, s) {
      // Never an error screen: the assistant simply is not there.
      AppLog.error('client_assistant._load', e, s);
    }
  }

  void _open() {
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Lx.sheet,
      barrierColor: const Color(0x8C000000),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Lx.rSheet)),
        side: BorderSide(color: Lx.line2),
      ),
      builder: (ctx) => _AssistantSheet(
        initial: _data!,
        lang: lang,
        reload: () => _repo.fetch(widget.workspaceId),
        onNavigate: (target) {
          Navigator.of(ctx).pop();
          widget.onNavigate(target);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null || !data.enabled) return const SizedBox.shrink();
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    return Semantics(
      button: true,
      label: data.nameIn(lang),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          key: const ValueKey('assistant-fab'),
          color: Lx.crimson,
          shape: const CircleBorder(side: BorderSide(color: Color(0x14FFFFFF))),
          elevation: 6,
          shadowColor: Colors.black,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _open,
            child: const Center(child: LxIcon('chat', size: 22, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _Turn {
  final AssistantQuestion question;
  const _Turn(this.question);
}

class _AssistantSheet extends StatefulWidget {
  final AssistantData initial;
  final String lang;
  final Future<AssistantData> Function() reload;
  final ValueChanged<String> onNavigate;

  const _AssistantSheet({required this.initial, required this.lang, required this.reload, required this.onNavigate});

  @override
  State<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<_AssistantSheet> {
  late AssistantData _data = widget.initial;
  final List<_Turn> _turns = [];
  final ScrollController _scroll = ScrollController();

  bool get _ar => widget.lang == 'ar';
  String _t(String ar, String en) => _ar ? ar : en;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // A fresh copy every time the sheet opens: the numbers are the point.
  Future<void> _refresh() async {
    try {
      final fresh = await widget.reload();
      if (mounted && fresh.enabled) setState(() => _data = fresh);
    } catch (e, s) {
      AppLog.error('client_assistant._refresh', e, s);
    }
  }

  AssistantQuestion _current(AssistantQuestion q) => _data.questions.firstWhere((x) => x.sameAs(q), orElse: () => q);

  void _ask(AssistantQuestion q) {
    setState(() => _turns.add(_Turn(q)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  String _goLabel(String target) {
    switch (target) {
      case 'contracts': return _t('افتح العقود', 'Open contracts');
      case 'payments': return _t('افتح المدفوعات', 'Open payments');
      case 'chat': return _t('افتح الشات', 'Open the chat');
      case 'approvals': return _t('افتح الموافقات', 'Open approvals');
      case 'files': return _t('افتح الملفات', 'Open files');
      case 'meetings': return _t('افتح الاجتماعات', 'Open meetings');
      default: return target;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: _data.nameIn(lang),
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(color: Lx.line2, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x2E941414),
                  border: Border.all(color: const Color(0x40D24A4A)),
                ),
                child: const LxIcon('chat', size: 16, color: Lx.crimsonInk),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_data.nameIn(lang), style: Lx.display(context, size: 16)),
                  Text(_t('ردود فورية من بيانات حسابك', 'Instant answers from your account data'), style: Lx.text(context, size: 11, color: Lx.muted)),
                ]),
              ),
              IconButton(
                key: const ValueKey('assistant-close'),
                tooltip: _t('إغلاق', 'Close'),
                icon: const Icon(Icons.close, size: 20, color: Lx.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          const Divider(height: 1, thickness: 1, color: Lx.line),
          Flexible(
            child: ListView(
              key: const ValueKey('assistant-thread'),
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              shrinkWrap: true,
              children: [
                _bubble(_data.welcomeIn(lang), bot: true),
                for (final turn in _turns) ..._turn(_current(turn.question)),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Lx.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.24),
              child: SingleChildScrollView(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(
                    key: const ValueKey('assistant-chips'),
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final q in _data.questions)
                        InkWell(
                          key: ValueKey('assistant-q-${q.key ?? 'faq'}-${q.id}'),
                          borderRadius: BorderRadius.circular(Lx.rPill),
                          onTap: () => _ask(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(Lx.rPill),
                              border: Border.all(color: Lx.line2),
                              color: const Color(0x05FFFFFF),
                            ),
                            child: Text(q.q(lang), style: Lx.text(context, size: 12, color: Lx.ink2)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _turn(AssistantQuestion q) {
    final lang = widget.lang;
    final paid = q.progressPaid;
    final total = q.progressTotal;
    return [
      const SizedBox(height: 10),
      _bubble(q.q(lang), bot: false),
      const SizedBox(height: 10),
      _bubble(
        q.a(lang),
        bot: true,
        footer: [
          if (paid != null && total != null && total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                key: const ValueKey('assistant-progress'),
                value: (paid / total).clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: Lx.line2,
                valueColor: const AlwaysStoppedAnimation(Lx.ok),
              ),
            ),
          ],
          if (q.actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final target in q.actions)
                InkWell(
                  key: ValueKey('assistant-go-$target'),
                  borderRadius: BorderRadius.circular(Lx.rPill),
                  onTap: () => widget.onNavigate(target),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(Lx.rPill), border: Border.all(color: Lx.line2)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_goLabel(target), style: Lx.text(context, size: 12, color: Lx.ink)),
                      const SizedBox(width: 6),
                      Directionality.of(context) == TextDirection.rtl
                          ? Transform.flip(flipX: true, child: const LxIcon('send', size: 14, color: Lx.ink))
                          : const LxIcon('send', size: 14, color: Lx.ink),
                    ]),
                  ),
                ),
            ]),
          ],
        ],
      ),
    ];
  }

  Widget _bubble(String text, {required bool bot, List<Widget> footer = const []}) {
    return Align(
      alignment: bot ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bot ? Lx.surface : const Color(0x33941414),
            border: Border.all(color: bot ? Lx.line : const Color(0x33D24A4A)),
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(bot ? 4 : 14),
              topEnd: Radius.circular(bot ? 14 : 4),
              bottomStart: const Radius.circular(14),
              bottomEnd: const Radius.circular(14),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: Lx.text(context, size: 13, color: bot ? Lx.ink2 : Lx.ink, height: 1.55)),
            ...footer,
          ]),
        ),
      ),
    );
  }
}
