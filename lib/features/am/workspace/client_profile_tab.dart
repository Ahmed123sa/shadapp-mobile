import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/loading_state.dart';

class ClientProfileTab extends StatefulWidget {
  final int? workspaceId;
  const ClientProfileTab({super.key, this.workspaceId});

  @override
  State<ClientProfileTab> createState() => _ClientProfileTabState();
}

class _ClientProfileTabState extends State<ClientProfileTab> {
  final _api = ApiClient();
  int? _clientId;
  Map<String, dynamic> _client = {};
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _location = {};
  bool _loading = true;
  bool _checkingIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wsId = widget.workspaceId ?? _api.workspaceId;
    if (wsId == null) return;
    setState(() => _loading = true);
    try {
      final wsData = await _api.get('/workspaces/$wsId');
      if (!mounted) return;
      final client = wsData['workspace']?['client'] as Map<String, dynamic>?;
      _clientId = client?['id'] as int?;
      if (_clientId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final profileData = await _api.get('/clients/$_clientId/profile');
      if (!mounted) return;
      setState(() {
        _client = profileData['client'] as Map<String, dynamic>? ?? {};
        _stats = profileData['stats'] as Map<String, dynamic>? ?? {};
        _location = profileData['location'] as Map<String, dynamic>? ?? {};
      });
    } catch (e) {
      debugPrint('ClientProfile: failed to load: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.clientProfileLoadFailed)));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isAM => _api.role == 'account_manager';

  Future<void> _checkIn(AppLocalizations l10n) async {
    setState(() => _checkingIn = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientProfileCheckInFailed)));
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      await _api.post('/clients/$_clientId/location', {
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientProfileCheckInSuccess)));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientProfileCheckInFailed)));
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _openMaps(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingState();
    final l10n = AppLocalizations.of(context)!;
    final hasLocation = _location['latitude'] != null && _location['longitude'] != null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Stats ──
          Row(children: [
            Expanded(child: _statCard(l10n.clientProfileContracts, '${_stats['total_contracts'] ?? 0}', '${_stats['draft_contracts'] ?? 0} ${l10n.clientProfileDraft} • ${_stats['sent_contracts'] ?? 0} ${l10n.clientProfileInProgress}')),
            const SizedBox(width: 10),
            Expanded(child: _statCard(l10n.clientProfileCompleted, '${_stats['completed_contracts'] ?? 0}', '${_stats['meetings_count'] ?? 0} ${l10n.clientProfileMeetings} • ${_stats['approvals_count'] ?? 0} ${l10n.clientProfileApprovals}')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _statCard(l10n.clientProfileTotalValue, _fmt(_stats['total_contract_value']), '')),
            const SizedBox(width: 10),
            Expanded(child: _statCard(l10n.clientProfileTotalPaid, _fmt(_stats['total_paid']), '${l10n.clientProfilePending}: ${_fmt(_stats['pending_payments'])}')),
          ]),
          const SizedBox(height: 16),

          // ── Contact info ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(l10n.clientProfileContactInfo, style: ShadTypography.sectionHeader)),
                  if (_isAM && _clientId != null)
                    TextButton.icon(
                      onPressed: () => context.push('/am/clients/$_clientId'),
                      icon: const Icon(Icons.edit_outlined, size: 16, color: ShadColors.gold),
                      label: Text(l10n.clientProfileEdit, style: const TextStyle(fontSize: 12, color: ShadColors.gold)),
                    ),
                ]),
                const Divider(height: 20),
                _infoRow(l10n.clientProfileCompany, Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(child: Text('${_client['company_name'] ?? '—'}', overflow: TextOverflow.ellipsis)),
                  if (_client['client_type'] != null) ...[
                    const SizedBox(width: 6),
                    ClientTypeBadge(clientType: _client['client_type'] as String?),
                  ],
                ])),
                _infoRow(l10n.clientProfileContactPerson, Text('${_client['contact_person'] ?? '—'}')),
                _infoRow(l10n.clientProfileEmail, Text('${_client['email'] ?? '—'}', textDirection: TextDirection.ltr)),
                _infoRow(l10n.clientProfilePhone, Text('${_client['phone'] ?? '—'}', textDirection: TextDirection.ltr)),
                _infoRow(l10n.clientProfileCountry, Text('${_client['country'] ?? '—'}')),
                _infoRow(l10n.clientProfileIndustry, Text('${_client['industry'] ?? '—'}')),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── Location ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: ShadColors.crimson),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l10n.clientProfileLocation, style: ShadTypography.sectionHeader)),
                  if (_isAM && _clientId != null)
                    FilledButton.icon(
                      onPressed: _checkingIn ? null : () => _checkIn(l10n),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: _checkingIn
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ShadColors.textOnCrimson))
                          : const Icon(Icons.my_location, size: 14),
                      label: Text(l10n.clientProfileCheckIn, style: const TextStyle(fontSize: 11)),
                    ),
                ]),
                const Divider(height: 20),
                if (hasLocation) ...[
                  if ((_location['address'] as String?)?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${_location['address']}', style: ShadTypography.cardSubtitle),
                    ),
                  Text('${l10n.clientProfileLastUpdated}: ${_formatDate(_location['updated_at'], l10n)}', style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _openMaps(_location['maps_url'] as String?),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.map_outlined, size: 16, color: ShadColors.gold),
                        const SizedBox(width: 6),
                        Text(l10n.clientProfileOpenMaps, style: const TextStyle(fontSize: 12, color: ShadColors.gold)),
                      ]),
                    ),
                  ),
                ] else
                  Text(l10n.clientProfileNotSet, style: ShadTypography.body.copyWith(color: ShadColors.textSecondary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: ShadColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ShadColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub, style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary)),
        ],
      ]),
    );
  }

  Widget _infoRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: ShadTypography.caption.copyWith(color: ShadColors.textSecondary))),
        Expanded(child: DefaultTextStyle.merge(style: ShadTypography.cardBody, child: value)),
      ]),
    );
  }

  String _fmt(dynamic value) {
    final num = double.tryParse('$value');
    if (num == null) return '0';
    return num.toStringAsFixed(0);
  }

  String _formatDate(String? dt, AppLocalizations l10n) {
    if (dt == null || dt.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt;
    }
  }
}
