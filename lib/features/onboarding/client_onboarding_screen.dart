import 'dart:async';
import 'dart:io' show Directory, File;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import '../../core/app_log.dart';
import 'package:provider/provider.dart';
import '../../core/luxe/lx_icons.dart';
import '../../core/luxe/tokens.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/luxe/luxe_widgets.dart';
import '../../core/helpers/signature_required_dialog.dart';
import '../../core/helpers/required_documents_dialog.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../data/client_repository.dart';
import '../../data/file_repository.dart';
import '../../data/signature_repository.dart';
import '../../data/payment_repository.dart';
import '../../data/system_settings_repository.dart';
import '../../providers/client_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/file_provider.dart';
import '../../providers/signature_provider.dart';
import '../../core/widgets/signature_pad_screen.dart' show renderSignaturePng;
import '../../providers/payment_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../contracts/contract_detail_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_onboarding_payment_sheet.dart';
import 'onboarding_signature_pad.dart';
import 'client_onboarding_stages.dart';
import 'onboarding_toast_keys.dart';

class ClientOnboardingScreen extends StatefulWidget {
  final ApiClient? api;
  final ReverbService? reverb;
  // Lets widget tests skip FirebaseMessaging.onMessage/.onMessageOpenedApp,
  // same reasoning as client_dashboard_screen.dart's identical seam.
  final bool enableFcm;
  /// Optional stream seam for widget tests to drive foreground FCM messages
  /// without requiring a live Firebase / MethodChannel runtime.
  final Stream<RemoteMessage>? foregroundMessages;
  final ClientProvider? clientProvider;
  final ContractProvider? contractProvider;
  final PaymentProvider? paymentProvider;
  final SystemSettingsProvider? systemSettingsProvider;

  const ClientOnboardingScreen({
    super.key,
    this.api,
    this.reverb,
    this.enableFcm = true,
    this.foregroundMessages,
    this.clientProvider,
    this.contractProvider,
    this.paymentProvider,
    this.systemSettingsProvider,
  });

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ReverbService _reverb = widget.reverb ?? ReverbService();
  // plans/notifications-badges-toasts-plan.md ن15 — see the identical field
  // in client_dashboard_screen.dart for why this list exists.
  final List<VoidCallback> _reverbUnsubscribers = [];
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider(repository: ClientRepository(api: _api));
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  late final FileProvider _fileProvider = FileProvider(repository: FileRepository(api: _api));
  int? _uploadingDocId;
  late final SignatureProvider _signatureProvider = SignatureProvider(repository: SignatureRepository(api: _api));
  final SignatureDraft _sigDraft = SignatureDraft();
  bool _savingSig = false;
  bool _drawing = false;
  // Mockup `st.edit`: "Request edit" opens an inline card in the body.
  bool _editing = false;
  bool _sendingEdit = false;
  final TextEditingController _editCtrl = TextEditingController();
  late final PaymentProvider _paymentProvider = widget.paymentProvider ?? PaymentProvider(repository: PaymentRepository(api: _api));
  late final SystemSettingsProvider _systemSettingsProvider = widget.systemSettingsProvider ?? SystemSettingsProvider(repository: SystemSettingsRepository(api: _api));

  Map<String, dynamic>? _client;
  Map<String, dynamic>? _workspace;
  Map<String, dynamic>? _taxSettings;
  bool _loading = true;
  String? _error;
  int _unreadNotifs = 0;
  int _lastStage = 0;
  bool _autoAdvancing = false;
  String _prevWsStatus = '';
  StreamSubscription? _fcmSubscription;
  final ValueNotifier<int> _contractRefreshNotifier = ValueNotifier<int>(0);

  int _computeStage() {
    final client = _client;
    final ws = _workspace;
    if (client == null || ws == null) return 0;
    final contractsList = safeList(ws['contracts']);
    final paymentsList = safeList(ws['payments']);
    if (paymentsList.any((p) => p is Map && (p['status'] == 'approved' || p['status'] == 'pending'))) return 5;
    if (contractsList.any((c) => c is Map && c['status'] == 'completed')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'archived')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'company_approved')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'client_approved')) return 3;
    final hasSent = contractsList.any((c) => c is Map && c['status'] == 'sent');
    if (hasSent) return client['signed_at'] != null ? 2 : 0;
    final hasEditRequested = contractsList.any((c) => c is Map && c['status'] == 'edit_requested');
    if (hasEditRequested) return 6;
    if (client['signed_at'] != null) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _loadUnread();
    _setupRealtimeNotifications();
    WidgetsBinding.instance.addObserver(this);
  }

  int? _joinedWsId;
  final Map<String, DateTime> _recentToasts = {};

  void _showToastOnce(String? text, {required String key}) {
    if (text == null || text.trim().isEmpty) return;
    final now = DateTime.now();
    if (!shouldShowToast(_recentToasts, key, now)) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(fontSize: 13)),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ));
  }

  void _setupRealtimeNotifications() {
    final cid = _api.userId;
    if (cid == null) return;
    _reverb.connectForClient(cid);
    _reverbUnsubscribers.add(_reverb.addNotificationReceivedListener((payload) {
      _loadClientData();
      _loadUnread();
      _contractRefreshNotifier.value++;
      if (!mounted) return;
      final dynamic rawData = payload['data'];
      final dataMap = rawData is Map ? rawData : null;
      final msg = (payload['message'] ?? payload['text'] ?? dataMap?['message'] ?? dataMap?['text']) as String? 
          ?? AppLocalizations.of(context)!.onboarding_newNotification;
      _showToastOnce(msg, key: toastKeyFromBroadcast(payload));
    }));
    _reverbUnsubscribers.add(_reverb.addContractStatusChangedListener(() {
      _loadClientData();
      _contractRefreshNotifier.value++;
    }));
    _reverbUnsubscribers.add(_reverb.addWorkspaceStatusChangedListener((_) {
      _loadClientData();
    }));
    final fcmStream = widget.foregroundMessages ??
        (widget.enableFcm ? FirebaseMessaging.onMessage : null);
    if (fcmStream != null) {
      _fcmSubscription = fcmStream.listen((msg) {
        final type = msg.data['type'] as String? ?? '';
        if (!(type.startsWith('contract.') || type.startsWith('payment.') || type.startsWith('workspace.'))) return;
        _loadClientData();
        _contractRefreshNotifier.value++;
        final body = msg.notification?.body ?? msg.data['message'] as String?;
        _showToastOnce(body, key: toastKeyFromFcm(msg.data));
      });
    }
    if (widget.enableFcm && widget.foregroundMessages == null) {
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        _loadClientData();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadClientData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fcmSubscription?.cancel();
    _sigDraft.dispose();
    _editCtrl.dispose();
    for (final unsubscribe in _reverbUnsubscribers) {
      unsubscribe();
    }
    if (_joinedWsId != null) {
      _reverb.leaveWorkspace(_joinedWsId!);
    }
    super.dispose();
  }

  Future<void> _loadClientData() async {
    final cid = _api.userId;
    if (cid == null) return;
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        _clientProvider.fetchClientRaw(cid),
        _systemSettingsProvider.fetchSettings().catchError((_) => <String, dynamic>{}),
      ]);
      final data = results[0];
      _client = data['client'] as Map<String, dynamic>?;
      _workspace = data['client']?['workspace'] as Map<String, dynamic>?;
      final settingsData = results[1];
      _taxSettings = settingsData['settings'] as Map<String, dynamic>?;
      if (_workspace != null) {
        final wsId = _workspace!['id'] as int?;
        if (wsId != null) {
          if (wsId != _api.workspaceId) {
            await _api.setUserData(workspace: wsId);
          }
          if (_joinedWsId != wsId) {
            await _reverb.connect(wsId);
            _joinedWsId = wsId;
          }
        }
      }
      _checkAutoAdvance();

      final prevStatus = _prevWsStatus;
      final newStatus = _workspace?['status'] as String? ?? '';
      if (newStatus == 'active' && prevStatus != 'active' && prevStatus.isNotEmpty) {
        if (mounted) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.onboarding_spaceActivated),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
              duration: const Duration(seconds: 3),
            ));
          });
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) context.go('/dashboard');
          });
        }
      }
      _prevWsStatus = _workspace?['status'] as String? ?? '';
    } catch (e) {
      if (mounted) _error = AppLocalizations.of(context)!.onboarding_failedToLoad;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _checkAutoAdvance() {
    if (_autoAdvancing) return;
    final currentStage = _computeStage();
    if (currentStage > _lastStage && currentStage > 0) {
      _autoAdvancing = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _autoAdvancing = false;
      });
    }
    _lastStage = currentStage;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.onboarding_logout),
        content: Text(AppLocalizations.of(ctx)!.onboarding_logoutQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.onboarding_cancel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.onboarding_logoutAction)),
        ],
      ),
    );
    if (confirm == true) {
      // See client_dashboard_screen.dart's _logout for why this has to run
      // before clearToken() — an open socket left under the cleared identity
      // eventually 401s on reconnect and bounces the user back to /login a
      // second time. See docs/mobile-review-2026-08-round2.md, #1.
      _reverb.disconnect();
      await _api.clearToken();
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Lx.page, body: SafeArea(child: LoadingState(style: LoadingStyle.spinner)));
    }
    if (_error != null) {
      return Scaffold(backgroundColor: Lx.page, body: SafeArea(child: ErrorState(message: _error!, onRetry: _loadClientData)));
    }

    final stage = _computeStage();
    final l10n = AppLocalizations.of(context)!;
    final labels = _stageLabels(l10n);
    final v = _visualStage(stage);
    final next = [for (var i = v + 1; i < labels.length; i++) MapEntry(i, labels[i])];
    return Scaffold(
      backgroundColor: Lx.page,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(stage),
            _buildOnboardingProgress(stage),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('onboarding-body'),
                physics: _drawing ? const NeverScrollableScrollPhysics() : null,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildStageBody(stage),
                  buildNextList(context: context, title: l10n.onboardingNextStepsTitle, steps: next),
                ]),
              ),
            ),
            _buildStickyBar(stage),
          ],
        ),
      ),
    );
  }

  // Mockup top bar (same as the workspace): brand + company, the bell with a
  // pip when something is unread, and the avatar that opens the "More" sheet.
  Future<void> _loadUnread() async {
    try {
      final res = await _api.get('/notifications');
      final n = int.tryParse(res['unread_count']?.toString() ?? '') ?? 0;
      if (mounted) setState(() => _unreadNotifs = n);
    } catch (e, s) {
      AppLog.error('client_onboarding._loadUnread', e, s);
    }
  }

  String _avatarInitial() {
    final name = (_api.userName ?? _client?['contact_person'] ?? _client?['company_name'] ?? '').toString().trim();
    return name.isEmpty ? '' : String.fromCharCode(name.runes.first);
  }

  /// The mockup's "More" sheet, trimmed to what exists during onboarding:
  /// who you are, language, logout.
  void _showMoreSheet() {
    final l10n = AppLocalizations.of(context)!;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final name = (_api.userName ?? _client?['contact_person'] ?? '').toString();
    final isSub = _api.role == 'sub_user';
    showLuxeSheet<void>(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            LuxeAvatar(initial: _avatarInitial()),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, key: const ValueKey('onboarding-more-name'), style: Lx.display(ctx, size: 16)),
                Text(
                  (isSub ? l10n.dashboardRoleAssistant : l10n.dashboardRoleOwner).toUpperCase(),
                  style: Lx.text(ctx, size: 11, color: Lx.faint).copyWith(letterSpacing: 1.1),
                ),
              ]),
            ),
          ]),
        ),
        LuxeMoreRow(
          key: const ValueKey('onboarding-more-language'),
          lxIcon: 'lang',
          label: isAr ? 'English' : 'العربية',
          onTap: () {
            Navigator.pop(ctx);
            context.read<LocaleProvider>().toggle();
          },
        ),
        LuxeMoreRow(
          key: const ValueKey('onboarding-more-logout'),
          lxIcon: 'out',
          label: l10n.onboarding_logout,
          danger: true,
          last: true,
          onTap: () {
            Navigator.pop(ctx);
            _logout();
          },
        ),
      ]);
    });
  }

  Widget _buildHeader(int stage) {
    final company = (_client?['company_name'] ?? _client?['contact_person'] ?? '').toString();
    return LuxeTopBar(
      company: company,
      avatarInitial: _avatarInitial(),
      unread: _unreadNotifs > 0,
      onBell: () => context.push('/notifications').then((_) => _loadUnread()),
      onAvatar: _showMoreSheet,
    );
  }

  List<String> _stageLabels(AppLocalizations l10n) => [
        l10n.onboarding_signStage,
        l10n.onboarding_receiveContractStage,
        l10n.onboarding_yourApprovalStage,
        l10n.onboarding_companyApprovalStage,
        l10n.onboarding_paymentProofStage,
        l10n.onboarding_activateStage,
      ];

  /// "Edit requested" (stage 6) sits at the contract-review step visually.
  int _visualStage(int stage) => stage >= 6 ? 2 : stage;

  Widget _buildOnboardingProgress(int stage) {
    final l10n = AppLocalizations.of(context)!;
    final labels = _stageLabels(l10n);
    final v = _visualStage(stage);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(labels[v], key: const ValueKey('onboarding-stage-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 11.5, weight: FontWeight.w500))),
              Text(l10n.onboardingStepOf(v + 1, 6), key: const ValueKey('onboarding-step-of'), style: Lx.text(context, size: 11.5, color: Lx.muted)),
            ],
          ),
          const SizedBox(height: 8),
          LuxeStepperBars(total: 6, current: v + 1),
        ],
      ),
    );
  }

  /// Stage buttons + the always-there support link, pinned under the body.
  Widget _buildStickyBar(int stage) {
    final l10n = AppLocalizations.of(context)!;
    final actions = _stageActions(stage);
    return Container(
      key: const ValueKey('onboarding-sticky'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(color: Lx.rail, border: Border(top: BorderSide(color: Lx.line))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final a in actions) ...[a, const SizedBox(height: 8)],
        InkWell(
          key: const ValueKey('onboarding-support'),
          onTap: _contactSupport,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const LxIcon('chat', size: 15, color: Lx.ink2),
              const SizedBox(width: 8),
              Text(l10n.onboarding_contactSupport, style: Lx.text(context, size: 12.5, color: Lx.ink2)),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _stageActions(int stage) {
    switch (stage) {
      case 2:
        if (_editing) return const [];
        return buildContractReviewActions(
          context: context,
          workspace: _workspace,
          onRespond: _respondToContract,
          onRequestEdit: () => setState(() => _editing = true),
        );
      case 4:
        return buildPaymentActions(
          context: context,
          workspace: _workspace,
          client: _client,
          taxSettings: _taxSettings,
          onSendPayment: _showPaymentBottomSheet,
        );
      case 1:
      case 3:
      case 5:
      case 6:
        return const [];
      default:
        return buildSignatureActions(context: context, draft: _sigDraft, saving: _savingSig, onSave: _saveSignature);
    }
  }

  Future<void> _openFile(String url) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = Uri.tryParse(_api.resolveFileUrl(url));
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidFileUrl)));
      return;
    }
    var failed = false;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      failed = true;
    }
    if (failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fileOpenFailed)));
    }
  }

  /// Same upload the contract sheet does, straight from the stage: the picked
  /// file goes against the contract and the required-document definition.
  Future<void> _uploadRequiredDoc(int contractId, int docId) async {
    final wsId = _workspace?['id'] as int?;
    if (wsId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.single;
    setState(() => _uploadingDocId = docId);
    String? message;
    try {
      final fields = <String, dynamic>{'contract_id': contractId, 'contract_required_document_id': docId};
      if (kIsWeb) {
        await _fileProvider.uploadFile(wsId, fields, bytes: pf.bytes, filename: pf.name);
      } else {
        await _fileProvider.uploadFile(wsId, fields, file: File(pf.path!));
      }
      message = l10n.documentUploaded;
      await _loadClientData();
    } catch (e) {
      message = l10n.documentUploadFailed(e.toString());
    }
    if (!mounted) return;
    setState(() => _uploadingDocId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickSignatureImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    _sigDraft.pick(result.files.single.path!, result.files.single.name);
  }

  /// Saves whatever the box holds: the drawing (as a cropped transparent PNG),
  /// the typed name, or the picked image — the same three calls the signature
  /// page makes. On success the client reloads and moves to the next stage.
  Future<void> _saveSignature() async {
    final cid = _api.userId;
    if (cid == null || !_sigDraft.canSave) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingSig = true);
    String message;
    var ok = false;
    try {
      switch (_sigDraft.mode) {
        case SignatureMode.draw:
          final bytes = await renderSignaturePng(_sigDraft.allStrokes);
          if (bytes == null) return;
          final file = File('${Directory.systemTemp.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(bytes);
          await _signatureProvider.uploadImage(cid, file);
        case SignatureMode.type:
          await _signatureProvider.saveText(cid, _sigDraft.text.text.trim());
        case SignatureMode.upload:
          await _signatureProvider.uploadImage(cid, File(_sigDraft.pickedPath!));
      }
      message = l10n.signature_saved;
      ok = true;
    } catch (e, s) {
      AppLog.error('client_onboarding._saveSignature', e, s);
      message = l10n.signature_saveFailed;
    } finally {
      if (mounted) setState(() => _savingSig = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (ok) {
      _sigDraft.clear();
      await _loadClientData();
    }
  }

  Widget _buildStageBody(int stage) {
    final l10n = AppLocalizations.of(context)!;
    switch (stage) {
      case 1:
        return buildWaitingStage(context: context, title: l10n.onboarding_waitingContract, subtitle: l10n.onboarding_waitingContractSendMsg);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          buildContractReviewStage(
            context: context,
            workspace: _workspace,
            onPreviewContract: _showContractModal,
            uploadingDocId: _uploadingDocId,
            onUploadDocument: _uploadRequiredDoc,
            onOpenFile: _openFile,
          ),
          if (_editing)
            buildEditRequestCard(
              context: context,
              controller: _editCtrl,
              sending: _sendingEdit,
              onSend: _sendEditRequest,
              onCancel: () => setState(() {
                _editing = false;
                _editCtrl.clear();
              }),
            ),
        ]);
      case 3:
        return buildWaitingStage(context: context, title: l10n.onboarding_waitingCompanyApproval, subtitle: l10n.onboarding_waitingCompanyReviewMsg);
      case 4:
        return buildPaymentStage(context: context, workspace: _workspace, client: _client, taxSettings: _taxSettings);
      case 5:
        // Mockup: the sent payment sits inside the waiting column.
        return buildWaitingStage(
          context: context,
          title: l10n.onboarding_reviewingPayment,
          subtitle: l10n.onboarding_waitingActivation,
          boxed: false,
          extra: buildSentPaymentCard(context: context, workspace: _workspace),
        );
      case 6:
        final reason = _editReason();
        return buildWaitingStage(
          context: context,
          title: l10n.onboardingWaitingEditContract,
          subtitle: l10n.onboardingWaitingEditContractMsg,
          boxed: false,
          extra: reason == null ? null : buildEditReasonQuote(context, reason),
        );
      default:
        return buildSignatureStage(
          context: context,
          client: _client,
          draft: _sigDraft,
          onPickImage: _pickSignatureImage,
          onDrawingChanged: (v) {
            if (_drawing != v) setState(() => _drawing = v);
          },
        );
    }
  }

  /// The client's own words from the contract waiting on an edit.
  String? _editReason() {
    for (final c in safeList(_workspace?['contracts'])) {
      if (c is Map && c['status'] == 'edit_requested') {
        final r = (c['edit_reason'] ?? '').toString().trim();
        if (r.isNotEmpty) return r;
      }
    }
    return null;
  }

  Future<void> _sendEditRequest() async {
    final reason = _editCtrl.text.trim();
    final contracts = safeList(_workspace?['contracts']).whereType<Map>().toList();
    if (contracts.isEmpty) return;
    final c = contracts.firstWhere((x) => x['status'] == 'sent', orElse: () => contracts.first);
    setState(() => _sendingEdit = true);
    final ok = await _respondToContractById(c['id'] as int, 'edit_requested', reason: reason);
    if (!mounted) return;
    setState(() {
      _sendingEdit = false;
      if (ok) {
        _editing = false;
        _editCtrl.clear();
      }
    });
  }

  Future<void> _contactSupport() async {
    final manager = _workspace?['manager'] as Map<String, dynamic>?;
    final phone = (manager?['phone'] ?? '').toString().trim();
    final clientName = (_client?['company_name'] ?? _client?['contact_person'] ?? '').toString();

    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('00')) {
      cleanPhone = cleanPhone.substring(2);
    }

    if (cleanPhone.isNotEmpty) {
      final text = 'مرحباً، أنا العميل $clientName وأحتاج مساعدة في مرحلة الإعداد.';
      final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم هاتف مدير الحساب غير متاح حالياً')),
      );
    }
  }

  void _showContractModal(Map c) {
    showLuxeSheet<void>(
      context,
      builder: (_) => ContractDetailModal(
        contract: c,
        workspaceId: _workspace?['id'] as int?,
        onAction: (id, action) async {
          Navigator.pop(context);
          // "Request edit" from the sheet opens the same inline card.
          if (action == 'edit_requested') {
            setState(() => _editing = true);
            return;
          }
          await _respondToContractById(id, action);
        },
        onRefresh: () {
          _loadClientData();
          _contractRefreshNotifier.value++;
        },
      ),
    );
  }

  Future<void> _respondToContract(String action) async {
    final ws = _workspace;
    if (ws == null) return;
    final contracts = safeList(ws['contracts']);
    if (contracts.isEmpty) return;
    final c = contracts.firstWhere(
      (contract) => contract is Map && contract['status'] == 'sent',
      orElse: () => contracts.first,
    ) as Map;
    await _respondToContractById(c['id'] as int, action);
  }

  /// Returns true when the server accepted the action.
  Future<bool> _respondToContractById(dynamic contractId, String action, {String? reason}) async {
    if (action == 'edit_requested' && reason == null) {
      setState(() => _editing = true);
      return false;
    }
    try {
      await _contractProvider.clientAction(contractId as int, action, reason: (reason != null && reason.isNotEmpty) ? reason : null);
      _loadClientData();
      _contractRefreshNotifier.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            LxIcon(action == 'approved' ? 'check' : 'msg', size: 18, color: action == 'approved' ? Lx.ok : Lx.wait),
            const SizedBox(width: 8),
            Flexible(child: Text(action == 'approved' ? AppLocalizations.of(context)!.onboarding_approvedMessage : AppLocalizations.of(context)!.onboarding_editSentMessage)),
          ]),
          duration: const Duration(seconds: 2),
        ));
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      if (await maybeShowSignatureRequiredDialog(context, e, isSubUser: _api.subUserId != null)) return false;
      if (!mounted) return false;
      if (await maybeShowRequiredDocumentsDialog(context, e)) return false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.onboarding_failedWithError(e.toString()))));
      }
      return false;
    }
  }

  void _showPaymentBottomSheet(double suggestedAmount, int? workspaceId, String currency) => showOnboardingPaymentSheet(
    context: context,
    suggestedAmount: suggestedAmount,
    workspaceId: workspaceId,
    currency: currency,
    paymentProvider: _paymentProvider,
    loadClientData: _loadClientData,
  );
}
