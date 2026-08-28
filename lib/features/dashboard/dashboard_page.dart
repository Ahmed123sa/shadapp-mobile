import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/reverb_service.dart';
import '../../data/client_repository.dart';
import '../../providers/client_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../onboarding/client_onboarding_screen.dart';
import 'client_dashboard_screen.dart';

class DashboardPage extends StatefulWidget {
  final int initialTab;
  // Step 0 of the state-layer migration plan: lets widget tests inject a
  // ReverbService.forTesting() instance instead of the real singleton, so
  // pumping this screen (and the ClientDashboardScreen it can render) never
  // opens a real WebSocket. Defaults to null, which falls back to the real
  // singleton — zero behavior change for every existing call site.
  final ReverbService? reverb;
  // Optional so this screen can be pumped in a widget test with a mocked
  // ApiClient instead of hitting the network. Defaults to the real
  // singleton — zero behavior change for every existing call site.
  final ApiClient? api;
  // Lets widget tests skip FirebaseMessaging.onMessage entirely — it
  // requires a real Firebase.initializeApp() call that plain `flutter test`
  // never makes. Same reasoning as client_dashboard_screen.dart's identical
  // seam. Defaults to true — zero behavior change for every existing call
  // site.
  final bool enableFcm;
  // Threaded straight through to the embedded ClientDashboardScreen (shown
  // for an active workspace), whose own ChatTab-equivalent ChatPage tab has
  // the same RealtimePoller testability problem documented there. Defaults
  // to true — zero behavior change for every existing call site.
  final bool enablePolling;
  const DashboardPage({super.key, this.initialTab = 0, this.reverb, this.api, this.enableFcm = true, this.enablePolling = true});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = ClientProvider(repository: ClientRepository(api: _api));
  Map<String, dynamic>? _workspace;
  bool _loading = true;
  String? _error;
  StreamSubscription? _fcmSubscription;
  late final ReverbService _reverb = widget.reverb ?? ReverbService();

  @override
  void initState() {
    super.initState();
    _loadClientData();
    _setupRealtime();
    WidgetsBinding.instance.addObserver(this);
  }

  void _setupRealtime() {
    final cid = _api.userId;
    if (cid == null) return;
    final reverb = _reverb;
    reverb.connectForClient(cid);
    reverb.onContractStatusChanged = () => _loadClientData();
    if (widget.enableFcm) {
      _fcmSubscription = FirebaseMessaging.onMessage.listen((msg) {
        final type = msg.data['type'] as String? ?? '';
        if (type == 'contract.company_approved' || type == 'contract.completed' || type == 'payment.approved') {
          _loadClientData();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadClientData();
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
      final data = await _clientProvider.fetchClientRaw(cid);
      _workspace = data['client']?['workspace'] as Map<String, dynamic>?;
      if (_workspace != null) {
        final wsId = _workspace!['id'] as int?;
        if (wsId != null && wsId != _api.workspaceId) {
          await _api.setUserData(workspace: wsId);
        }
      }
    } catch (e) {
      if (mounted) _error = AppLocalizations.of(context)!.dashboard_failedToLoad;
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isActiveWorkspace {
    final ws = _workspace;
    return ws != null && (ws['status'] as String? ?? '') == 'active';
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
              ElevatedButton(onPressed: _loadClientData, child: Text(AppLocalizations.of(context)!.retry)),
            ]),
          ),
        ),
      );
    }

    if (_isActiveWorkspace) {
      return ClientDashboardScreen(
        initialTab: widget.initialTab,
        reverb: widget.reverb,
        api: _api,
        enableFcm: widget.enableFcm,
        enablePolling: widget.enablePolling,
      );
    }

    return const ClientOnboardingScreen();
  }
}
