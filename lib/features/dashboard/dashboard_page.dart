import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/reverb_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../onboarding/client_onboarding_screen.dart';
import 'client_dashboard_screen.dart';

class DashboardPage extends StatefulWidget {
  final int initialTab;
  const DashboardPage({super.key, this.initialTab = 0});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  final _api = ApiClient();
  Map<String, dynamic>? _workspace;
  bool _loading = true;
  String? _error;
  StreamSubscription? _fcmSubscription;

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
    final reverb = ReverbService();
    reverb.connectForClient(cid);
    reverb.onContractStatusChanged = () => _loadClientData();
    _fcmSubscription = FirebaseMessaging.onMessage.listen((msg) {
      final type = msg.data['type'] as String? ?? '';
      if (type == 'contract.company_approved' || type == 'contract.completed' || type == 'payment.approved') {
        _loadClientData();
      }
    });
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
      final data = await _api.get('/clients/$cid');
      _workspace = data['client']?['workspace'] as Map<String, dynamic>?;
      if (_workspace != null) {
        final wsId = _workspace!['id'] as int?;
        if (wsId != null && wsId != _api.workspaceId) {
          await _api.setUserData(workspace: wsId);
        }
      }
    } catch (e) {
      _error = 'فشل تحميل البيانات';
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
              ElevatedButton(onPressed: _loadClientData, child: const Text('إعادة المحاولة')),
            ]),
          ),
        ),
      );
    }

    if (_isActiveWorkspace) {
      return ClientDashboardScreen(initialTab: widget.initialTab);
    }

    return const ClientOnboardingScreen();
  }
}
