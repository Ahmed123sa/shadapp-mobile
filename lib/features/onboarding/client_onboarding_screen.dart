import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../core/widgets/shad_logo.dart';
import '../../data/client_repository.dart';
import '../../data/payment_repository.dart';
import '../../data/system_settings_repository.dart';
import '../../providers/client_provider.dart';
import '../../providers/contract_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/system_settings_provider.dart';
import '../contracts/contract_detail_modal.dart';
import 'client_onboarding_payment_sheet.dart';
import 'client_onboarding_stages.dart';

class ClientOnboardingScreen extends StatefulWidget {
  final ApiClient? api;
  final ReverbService? reverb;
  // Lets widget tests skip FirebaseMessaging.onMessage/.onMessageOpenedApp,
  // same reasoning as client_dashboard_screen.dart's identical seam.
  final bool enableFcm;
  final ClientProvider? clientProvider;
  final ContractProvider? contractProvider;
  final PaymentProvider? paymentProvider;
  final SystemSettingsProvider? systemSettingsProvider;

  const ClientOnboardingScreen({
    super.key,
    this.api,
    this.reverb,
    this.enableFcm = true,
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
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider(repository: ClientRepository(api: _api));
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider(api: _api);
  late final PaymentProvider _paymentProvider = widget.paymentProvider ?? PaymentProvider(repository: PaymentRepository(api: _api));
  late final SystemSettingsProvider _systemSettingsProvider = widget.systemSettingsProvider ?? SystemSettingsProvider(repository: SystemSettingsRepository(api: _api));

  Map<String, dynamic>? _client;
  Map<String, dynamic>? _workspace;
  Map<String, dynamic>? _taxSettings;
  bool _loading = true;
  String? _error;
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
    if (paymentsList.any((p) => p is Map && p['status'] == 'approved')) return 5;
    if (paymentsList.isNotEmpty) return 5;
    if (contractsList.any((c) => c is Map && c['status'] == 'completed')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'archived')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'company_approved')) return 4;
    if (contractsList.any((c) => c is Map && c['status'] == 'client_approved')) return 3;
    if (contractsList.any((c) => c is Map && c['status'] == 'edit_requested')) return 2;
    if (contractsList.any((c) => c is Map && c['status'] == 'sent')) return 2;
    if (client['signed_at'] != null) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _setupRealtimeNotifications();
    WidgetsBinding.instance.addObserver(this);
  }

  void _setupRealtimeNotifications() {
    final cid = _api.userId;
    if (cid == null) return;
    _reverb.connectForClient(cid);
    _reverb.onNotificationReceived = (payload) {
      _loadClientData();
      _contractRefreshNotifier.value++;
      if (!mounted) return;
      final msg = (payload['data'] as Map?)?['message'] as String? ?? (payload['data'] as Map?)?['text'] as String? ?? AppLocalizations.of(context)!.onboarding_newNotification;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ));
    };
    _reverb.onContractStatusChanged = () {
      _loadClientData();
      _contractRefreshNotifier.value++;
    };
    if (widget.enableFcm) {
      _fcmSubscription = FirebaseMessaging.onMessage.listen((msg) {
        final type = msg.data['type'] as String? ?? '';
        if (type == 'contract.company_approved' || type == 'contract.completed' || type == 'payment.approved') {
          _loadClientData();
        }
      });
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
        if (wsId != null && wsId != _api.workspaceId) {
          await _api.setUserData(workspace: wsId);
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, size: 64, color: ShadColors.error),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: ShadColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadClientData, child: Text(AppLocalizations.of(context)!.onboarding_retry)),
            ]),
          ),
        ),
      );
    }

    final stage = _computeStage();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(stage),
            _buildOnboardingProgress(stage),
            const SizedBox(height: 8),
            Expanded(child: _buildStageScreen(stage)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int stage) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
      child: Row(
        children: [
          const ShadLogo(size: 28, showText: false),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.language, size: 20),
            onPressed: () => context.read<LocaleProvider>().toggle(),
            tooltip: AppLocalizations.of(context)!.onboarding_changeLanguage,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            onPressed: _logout,
            tooltip: AppLocalizations.of(context)!.onboarding_logout,
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingProgress(int stage) {
    final labels = [
      AppLocalizations.of(context)!.onboarding_signStage,
      AppLocalizations.of(context)!.onboarding_receiveContractStage,
      AppLocalizations.of(context)!.onboarding_yourApprovalStage,
      AppLocalizations.of(context)!.onboarding_companyApprovalStage,
      AppLocalizations.of(context)!.onboarding_paymentProofStage,
      AppLocalizations.of(context)!.onboarding_activateStage,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: List.generate(6, (i) {
              final done = i < stage;
              final current = i == stage;
              return Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: done
                        ? ShadColors.crimson
                        : current
                            ? ShadColors.gold
                            : ShadColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(6, (i) {
              final done = i < stage;
              final current = i == stage;
              return Expanded(
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 9,
                    color: done
                        ? ShadColors.crimson
                        : current
                            ? ShadColors.gold
                            : ShadColors.textDisabled,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStageScreen(int stage) {
    switch (stage) {
      case 0:
        return buildSignatureStage(
          context: context,
          client: _client,
          onSign: () async {
            await context.push('/signature');
            _loadClientData();
          },
        );
      case 1:
        return buildWaitingStage(
          context: context,
          icon: Icons.downloading,
          iconColor: ShadColors.sent,
          title: AppLocalizations.of(context)!.onboarding_waitingContract,
          subtitle: AppLocalizations.of(context)!.onboarding_waitingContractSendMsg,
        );
      case 2:
        return buildContractReviewStage(
          context: context,
          workspace: _workspace,
          onPreviewContract: _showContractModal,
          onRespond: _respondToContract,
        );
      case 3:
        return buildWaitingStage(
          context: context,
          icon: Icons.verified,
          iconColor: ShadColors.companyApproved,
          title: AppLocalizations.of(context)!.onboarding_waitingCompanyApproval,
          subtitle: AppLocalizations.of(context)!.onboarding_waitingCompanyReviewMsg,
        );
      case 4:
        return buildPaymentStage(
          context: context,
          workspace: _workspace,
          client: _client,
          taxSettings: _taxSettings,
          onSendPayment: _showPaymentBottomSheet,
        );
      case 5:
        return buildWaitingStage(
          context: context,
          icon: Icons.hourglass_top,
          iconColor: ShadColors.warning,
          title: AppLocalizations.of(context)!.onboarding_reviewingPayment,
          subtitle: AppLocalizations.of(context)!.onboarding_waitingActivation,
        );
      default:
        return buildSignatureStage(
          context: context,
          client: _client,
          onSign: () async {
            await context.push('/signature');
            _loadClientData();
          },
        );
    }
  }

  void _showContractModal(Map c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => ContractDetailModal(
          contract: c,
          workspaceId: _workspace?['id'] as int?,
          backLabel: AppLocalizations.of(context)!.onboarding_back,
        onAction: (id, action) async {
          Navigator.pop(context);
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
    final c = contracts.first as Map;
    await _respondToContractById(c['id'] as int, action);
  }

  Future<void> _respondToContractById(dynamic contractId, String action) async {
    String? reason;
    if (action == 'edit_requested') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(ctx)!.requiredEdits),
          content: TextField(controller: controller, maxLines: 3, decoration: InputDecoration(hintText: AppLocalizations.of(ctx)!.editRequestHint2)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(ctx)!.onboarding_cancel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(AppLocalizations.of(ctx)!.onboarding_confirmAction)),
          ],
        ),
      );
      if (reason == null) return;
    }
    try {
      await _contractProvider.clientAction(contractId as int, action, reason: (reason != null && reason.isNotEmpty) ? reason : null);
      _loadClientData();
      _contractRefreshNotifier.value++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            Icon(action == 'approved' ? Icons.check_circle : Icons.edit, color: action == 'approved' ? Colors.green : Colors.orange, size: 18),
            const SizedBox(width: 8),
            Text(action == 'approved' ? AppLocalizations.of(context)!.onboarding_approvedMessage : AppLocalizations.of(context)!.onboarding_editSentMessage),
          ]),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.onboarding_failedWithError(e.toString()))));
      }
    }
  }

  void _showPaymentBottomSheet(double suggestedAmount, int? workspaceId) => showOnboardingPaymentSheet(
    context: context,
    suggestedAmount: suggestedAmount,
    workspaceId: workspaceId,
    paymentProvider: _paymentProvider,
    loadClientData: _loadClientData,
  );
}
