import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../core/api_client.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/locale_provider.dart';
import '../../core/reverb_service.dart';
import '../../core/widgets/shad_logo.dart';
import '../contracts/contract_detail_modal.dart';

class ClientOnboardingScreen extends StatefulWidget {
  const ClientOnboardingScreen({super.key});

  @override
  State<ClientOnboardingScreen> createState() => _ClientOnboardingScreenState();
}

class _ClientOnboardingScreenState extends State<ClientOnboardingScreen> with WidgetsBindingObserver {
  final _api = ApiClient();

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
    final reverb = ReverbService();
    reverb.connectForClient(cid);
    reverb.onNotificationReceived = (payload) {
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
    reverb.onContractStatusChanged = () {
      _loadClientData();
      _contractRefreshNotifier.value++;
    };
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
        _api.get('/clients/$cid'),
        _api.get('/settings').catchError((_) => <String, dynamic>{}),
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
        return _buildSignatureStage();
      case 1:
        return _buildWaitingStage(
          icon: Icons.downloading,
          iconColor: ShadColors.sent,
          title: AppLocalizations.of(context)!.onboarding_waitingContract,
          subtitle: AppLocalizations.of(context)!.onboarding_waitingContractSendMsg,
        );
      case 2:
        return _buildContractReviewStage();
      case 3:
        return _buildWaitingStage(
          icon: Icons.verified,
          iconColor: ShadColors.companyApproved,
          title: AppLocalizations.of(context)!.onboarding_waitingCompanyApproval,
          subtitle: AppLocalizations.of(context)!.onboarding_waitingCompanyReviewMsg,
        );
      case 4:
        return _buildPaymentStage();
      case 5:
        return _buildWaitingStage(
          icon: Icons.hourglass_top,
          iconColor: ShadColors.warning,
          title: AppLocalizations.of(context)!.onboarding_reviewingPayment,
          subtitle: AppLocalizations.of(context)!.onboarding_waitingActivation,
        );
      default:
        return _buildSignatureStage();
    }
  }

  Widget _buildSignatureStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.gold.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_fix_high, size: 36, color: ShadColors.gold),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.onboarding_welcomeName(_client?['contact_person'] ?? ''),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.onboarding_addSignaturePrompt,
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await context.push('/signature');
                _loadClientData();
              },
              icon: const Icon(Icons.draw, size: 20),
              label: Text(AppLocalizations.of(context)!.onboarding_signNow),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingStage({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.headset_mic, size: 18),
            label: Text(AppLocalizations.of(context)!.onboarding_contactSupport),
            style: TextButton.styleFrom(foregroundColor: ShadColors.textSecondary),
          ),
        ]),
      ),
    );
  }

  Widget _buildContractReviewStage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.approved.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.description, size: 36, color: ShadColors.approved),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.onboarding_contractReceived,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.onboarding_reviewContractPrompt,
            style: TextStyle(fontSize: 14, color: ShadColors.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final ws = _workspace;
                if (ws != null) {
                  final contracts = safeList(ws['contracts']);
                  if (contracts.isNotEmpty) {
                    final c = contracts.first as Map;
                    _showContractModal(c);
                  }
                }
              },
              icon: const Icon(Icons.visibility, size: 20),
              label: Text(AppLocalizations.of(context)!.onboarding_previewContract),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShadColors.gold,
                side: const BorderSide(color: ShadColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _respondToContract('approved'),
              icon: const Icon(Icons.thumb_up, size: 20),
              label: Text(AppLocalizations.of(context)!.onboarding_approve),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _respondToContract('edit_requested'),
            icon: const Icon(Icons.edit_note, size: 18),
            label: Text(AppLocalizations.of(context)!.onboarding_requestEdit),
            style: TextButton.styleFrom(foregroundColor: ShadColors.textSecondary),
          ),
        ],
      ),
    );
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
      final body = <String, dynamic>{'action': action};
      if (reason != null && reason.isNotEmpty) body['reason'] = reason;
      await _api.post('/contracts/$contractId/client-action', body);
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

  Widget _buildPaymentStage() {
    final ws = _workspace;
    double totalAmount = 0;
    double paidAmount = 0;
    double taxAmount = 0;
    double taxPercentage = 0;
    String currency = 'SAR';
    String? startDate;
    String? endDate;
    final isBusiness = (_client?['client_type'] ?? '') == 'business';
    if (isBusiness && _taxSettings != null) {
      taxPercentage = num.tryParse(_taxSettings!['corporate_tax_percentage']?['value']?.toString() ?? '')?.toDouble() ?? 0;
    }
    if (ws != null) {
      final contracts = safeList(ws['contracts']);
      for (final c in contracts) {
        if (c is Map) {
          final cv = double.tryParse((c['value'] ?? '0').toString()) ?? 0.0;
          totalAmount += cv;
          currency = (c['currency'] as String?) ?? currency;
          if (c['start_date'] != null) startDate = (c['start_date'] as String).split('T')[0];
          if (c['end_date'] != null) endDate = (c['end_date'] as String).split('T')[0];
        }
      }
      final payments = safeList(ws['payments']);
      for (final p in payments) {
        if (p is Map && p['status'] == 'approved') {
          paidAmount += double.tryParse((p['amount'] ?? '0').toString()) ?? 0.0;
        }
      }
    }
    if (isBusiness && taxPercentage > 0) {
      taxAmount = totalAmount * taxPercentage / 100;
    }
    final grandTotal = totalAmount + taxAmount;
    final remaining = grandTotal - paidAmount;
    final progress = grandTotal > 0 ? (paidAmount / grandTotal).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: ShadColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.payment, size: 36, color: ShadColors.warning),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.onboarding_completePayment,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay'),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.onboarding_confirmPaymentToActivate,
            style: TextStyle(fontSize: 13, color: ShadColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Progress card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ShadColors.surfaceDarker,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ShadColors.cardBorder),
            ),
            child: Column(children: [
              Text('${paidAmount.toStringAsFixed(2)} $currency', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ShadColors.gold, fontFamily: 'PlayfairDisplay')),
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.payments_remainingSummary(currency, remaining.toStringAsFixed(2), grandTotal.toStringAsFixed(2)), style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
              if (taxAmount > 0) ...[
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.payments_taxSummary(taxAmount.toStringAsFixed(2), currency, taxPercentage, totalAmount.toStringAsFixed(2)), style: TextStyle(fontSize: 10, color: ShadColors.textDisabled)),
              ],
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: ShadColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation(ShadColors.gold),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Contract details
          if (startDate != null || endDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ShadColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ShadColors.cardBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(context)!.onboarding_contractDetails, style: TextStyle(fontSize: 12, color: ShadColors.textSecondary)),
                const SizedBox(height: 10),
                if (startDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.calendar_today, size: 14, color: ShadColors.textDisabled),
                      const SizedBox(width: 8),
                      Text('${AppLocalizations.of(context)!.onboarding_startDate}: $startDate', style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                    ]),
                  ),
                if (endDate != null)
                  Row(children: [
                    Icon(Icons.calendar_today, size: 14, color: ShadColors.textDisabled),
                    const SizedBox(width: 8),
                    Text('${AppLocalizations.of(context)!.onboarding_endDate}: $endDate', style: const TextStyle(fontSize: 12, color: ShadColors.textPrimary)),
                  ]),
              ]),
            ),
          const SizedBox(height: 24),

          // Payment info cards
          Row(children: [
            Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_amount, totalAmount.toStringAsFixed(0), ShadColors.gold)),
            const SizedBox(width: 12),
            Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_currency, currency, ShadColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (taxAmount > 0)
              Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_tax, taxAmount.toStringAsFixed(0), ShadColors.error)),
            if (taxAmount > 0) const SizedBox(width: 12),
            Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_total, grandTotal.toStringAsFixed(0), ShadColors.gold)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_paidAmount, paidAmount.toStringAsFixed(0), ShadColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _paymentInfoTile(AppLocalizations.of(context)!.onboarding_remainingAmount2, remaining.toStringAsFixed(0), ShadColors.warning)),
          ]),
          const SizedBox(height: 28),

          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showPaymentBottomSheet(remaining > 0 ? remaining : grandTotal, ws?['id']),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: Text(AppLocalizations.of(context)!.onboarding_sendPayment),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShadColors.crimson,
                foregroundColor: ShadColors.textOnCrimson,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentInfoTile(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ShadColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: valueColor, fontFamily: 'PlayfairDisplay')),
      ]),
    );
  }

  void _showPaymentBottomSheet(double suggestedAmount, int? workspaceId) {
    final methodLabels = {
      'bank_transfer': AppLocalizations.of(context)!.payments_methodBankTransfer,
      'swift': AppLocalizations.of(context)!.payments_methodSwift,
      'corporate_account': AppLocalizations.of(context)!.payments_methodCorporateAccount,
      'instapay': AppLocalizations.of(context)!.payments_methodInstapay,
      'vodafone_cash': AppLocalizations.of(context)!.payments_methodVodafoneCash,
      'mobile_wallet': AppLocalizations.of(context)!.payments_methodMobileWallet,
    };

    const currencies = ['SAR', 'USD', 'EUR', 'AED', 'EGP', 'KWD', 'QAR', 'BHD', 'OMR'];
    final currencyLabels = {
      'SAR': AppLocalizations.of(context)!.currency_sar, 'USD': AppLocalizations.of(context)!.currency_usd, 'EUR': AppLocalizations.of(context)!.currency_eur,
      'AED': AppLocalizations.of(context)!.currency_aed, 'EGP': AppLocalizations.of(context)!.currency_egp, 'KWD': AppLocalizations.of(context)!.currency_kwd,
      'QAR': AppLocalizations.of(context)!.currency_qar, 'BHD': AppLocalizations.of(context)!.currency_bhd, 'OMR': AppLocalizations.of(context)!.currency_omr,
    };

    final amountCtrl = TextEditingController(text: suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(0) : '');
    final selectedCurrency = ValueNotifier<String>('SAR');
    final selectedMethod = ValueNotifier<String>('bank_transfer');
    List<Map<String, dynamic>> proofFiles = [];
    final uploadingNotifier = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(AppLocalizations.of(ctx)!.onboarding_requestPaymentTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ShadColors.textPrimary, fontFamily: 'PlayfairDisplay')),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: selectedCurrency,
                builder: (_, cur, __) => TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(labelText: '${AppLocalizations.of(ctx)!.onboarding_amountField} *', hintText: '0.00', prefixText: '$cur '),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: selectedCurrency,
                builder: (_, cur, __) => DropdownButtonFormField<String>(
                  initialValue: cur,
                  decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.onboarding_currencyField),
                  items: currencies.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text('$c — ${currencyLabels[c] ?? ''}'),
                  )).toList(),
                  onChanged: (v) { if (v != null) selectedCurrency.value = v; },
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: selectedMethod,
                builder: (_, val, __) => DropdownButtonFormField<String>(
                  initialValue: val,
                  decoration: InputDecoration(labelText: AppLocalizations.of(ctx)!.onboarding_paymentMethodField),
                  items: methodLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                  onChanged: (v) { if (v != null) selectedMethod.value = v; },
                ),
              ),
              const SizedBox(height: 16),

              // Proof files section
              Text(AppLocalizations.of(ctx)!.onboarding_proofField, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ShadColors.textSecondary)),
              const SizedBox(height: 8),

              if (proofFiles.isNotEmpty) ...[
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: proofFiles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final pf = proofFiles[i];
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: ShadColors.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ShadColors.cardBorder),
                            ),
                            child: pf['bytes'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(pf['bytes'] as Uint8List, fit: BoxFit.cover, width: 80, height: 80),
                                  )
                                : Center(
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.insert_drive_file, size: 24, color: ShadColors.textSecondary),
                                      const SizedBox(height: 4),
                                      Text(pf['name'] ?? '', style: const TextStyle(fontSize: 9, color: ShadColors.textDisabled), overflow: TextOverflow.ellipsis, maxLines: 2, textAlign: TextAlign.center),
                                    ]),
                                  ),
                          ),
                          Positioned(
                            right: -6, top: -6,
                            child: GestureDetector(
                              onTap: () {
                                setSheetState(() { proofFiles.removeAt(i); });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: ShadColors.error, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'], withData: kIsWeb);
                      if (r != null && r.files.isNotEmpty) {
                        setSheetState(() {
                          for (final f in r.files) {
                            if (kIsWeb) {
                              proofFiles.add({'bytes': f.bytes, 'name': f.name});
                            } else {
                              proofFiles.add({'file': File(f.path!), 'name': f.name});
                            }
                          }
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(AppLocalizations.of(ctx)!.onboarding_attachFile),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final r = await ImagePicker().pickImage(source: ImageSource.camera);
                    if (r != null) {
                      setSheetState(() {
                        if (kIsWeb) {
                          r.readAsBytes().then((bytes) {
                            setSheetState(() { proofFiles.add({'bytes': bytes, 'name': r.name}); });
                          });
                        } else {
                          proofFiles.add({'file': File(r.path), 'name': r.name});
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: Text(AppLocalizations.of(ctx)!.onboarding_takePhoto),
                ),
              ]),
              if (proofFiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(AppLocalizations.of(ctx)!.onboarding_filesAttached(proofFiles.length), style: TextStyle(fontSize: 11, color: ShadColors.textDisabled)),
                ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: uploadingNotifier,
                builder: (_, uploading, __) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: uploading ? null : () => _submitPaymentOnboarding(
                      ctx, setSheetState, uploadingNotifier, workspaceId,
                      amountCtrl, selectedCurrency.value, selectedMethod.value, proofFiles,
                    ),
                    child: uploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(AppLocalizations.of(ctx)!.onboarding_sendPayment),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _submitPaymentOnboarding(
    BuildContext ctx,
    void Function(void Function()) setSheetState,
    ValueNotifier<bool> uploadingNotifier,
    int? workspaceId,
    TextEditingController amountCtrl,
    String currency,
    String methodType,
    List<Map<String, dynamic>> proofFiles,
  ) async {
    final amount = double.tryParse(amountCtrl.text);
    if (amount == null || amount <= 0) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.onboarding_enterValidAmount)));
      return;
    }
    if (workspaceId == null) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.onboarding_workspaceUnavailable)));
      return;
    }
    uploadingNotifier.value = true;
    setSheetState(() {});
    try {
      final fields = <String, dynamic>{
        'amount': amount,
        'currency': currency,
        'method_type': methodType,
      };

      final nativeFiles = proofFiles.where((pf) => pf['file'] != null).map((pf) => pf['file'] as File).toList();
      final bytesFiles = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['bytes'] as Uint8List).toList();
      final bytesNames = proofFiles.where((pf) => pf['bytes'] != null).map((pf) => pf['name'] as String? ?? 'file.jpg').toList();

      if (nativeFiles.isNotEmpty) {
        await _api.multipartPost(
          '/workspaces/$workspaceId/payments',
          fields,
          multipleFiles: nativeFiles,
          multipleFileField: 'proof_files[]',
        );
      } else if (bytesFiles.isNotEmpty) {
        await _api.multipartPost(
          '/workspaces/$workspaceId/payments',
          fields,
          multipleBytes: bytesFiles,
          multipleBytesNames: bytesNames,
          multipleFileField: 'proof_files[]',
        );
      } else {
        await _api.post('/workspaces/$workspaceId/payments', fields);
      }

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 8), Text(AppLocalizations.of(ctx)!.onboarding_paymentSent)])));
        Navigator.pop(ctx);
      }
      _loadClientData();
    } catch (_) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppLocalizations.of(ctx)!.onboarding_paymentFailed)));
    }
    uploadingNotifier.value = false;
    if (ctx.mounted) setSheetState(() {});
  }

}

List safeList(dynamic value) {
  if (value is List) return value;
  if (value is String) return [];
  return [];
}
