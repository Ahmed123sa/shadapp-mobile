import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/api_client.dart';
import '../../../core/app_log.dart';
import '../../../core/luxe/tokens.dart';
import '../../../core/widgets/luxe/luxe_widgets.dart';
import '../../../core/widgets/client_type_badge.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../providers/client_provider.dart';
import '../../../providers/contract_provider.dart';
import 'location_picker_page.dart';

class ClientProfileTab extends StatefulWidget {
  final int? workspaceId;
  // Optional so this screen can be pumped in a widget test with mocked
  // providers instead of hitting the network.
  final ClientProvider? clientProvider;
  final ContractProvider? contractProvider;
  final ApiClient? api;
  const ClientProfileTab({super.key, this.workspaceId, this.clientProvider, this.contractProvider, this.api});

  @override
  State<ClientProfileTab> createState() => _ClientProfileTabState();
}

class _ClientProfileTabState extends State<ClientProfileTab> {
  late final ApiClient _api = widget.api ?? ApiClient();
  late final ClientProvider _clientProvider = widget.clientProvider ?? ClientProvider();
  late final ContractProvider _contractProvider = widget.contractProvider ?? ContractProvider();
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
      final wsData = await _contractProvider.fetchWorkspaceRaw(wsId);
      if (!mounted) return;
      final client = wsData['workspace']?['client'] as Map<String, dynamic>?;
      _clientId = client?['id'] as int?;
      if (_clientId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final profileData = await _clientProvider.fetchClientProfile(_clientId!);
      if (!mounted) return;
      setState(() {
        _client = profileData['client'] as Map<String, dynamic>? ?? {};
        _stats = profileData['stats'] as Map<String, dynamic>? ?? {};
        _location = profileData['location'] as Map<String, dynamic>? ?? {};
      });
    } catch (e, s) {
      AppLog.error('client_profile_tab._load', e, s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.clientProfileLoadFailed)));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  bool get _isAM => _api.role == 'account_manager' || (_api.role == 'manager_assistant' && _api.canDo('can_edit_clients'));

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
      await _clientProvider.updateClientLocation(_clientId!, latitude: position.latitude, longitude: position.longitude);
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

  Future<void> _pickOnMap(AppLocalizations l10n) async {
    final loc = _location['latitude'] != null && _location['longitude'] != null
        ? _location
        : null;
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: loc != null ? (loc['latitude'] as num).toDouble() : null,
          initialLng: loc != null ? (loc['longitude'] as num).toDouble() : null,
        ),
      ),
    );
    if (result == null || _clientId == null) return;
    try {
      await _clientProvider.updateClientLocation(
        _clientId!,
        latitude: result.latitude,
        longitude: result.longitude,
        address: result.address,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientProfileCheckInSuccess)));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.clientProfileCheckInFailed)));
      }
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
      color: Lx.crimsonInk,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 28),
        children: [
          // ── Stats ──
          Row(children: [
            Expanded(child: _statCard(l10n.clientProfileContracts, '${_stats['total_contracts'] ?? 0}', '${_stats['draft_contracts'] ?? 0} ${l10n.clientProfileDraft} • ${_stats['sent_contracts'] ?? 0} ${l10n.clientProfileInProgress}')),
            const SizedBox(width: 8),
            Expanded(child: _statCard(l10n.clientProfileCompleted, '${_stats['completed_contracts'] ?? 0}', '${_stats['meetings_count'] ?? 0} ${l10n.clientProfileMeetings} • ${_stats['approvals_count'] ?? 0} ${l10n.clientProfileApprovals}')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _statCard(l10n.clientProfileTotalValue, _fmt(_stats['total_contract_value']), '')),
            const SizedBox(width: 8),
            Expanded(child: _statCard(l10n.clientProfileTotalPaid, _fmt(_stats['total_paid']), '${l10n.clientProfilePending}: ${_fmt(_stats['pending_payments'])}', hl: true)),
          ]),
          const SizedBox(height: 14),

          // ── Contact info (mockup: kind label + `.doc` rows) ──
          LuxeCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: LuxeKind(l10n.clientProfileContactInfo)),
                if (_isAM && _clientId != null)
                  LuxeButton(
                    label: l10n.clientProfileEdit,
                    size: LuxeButtonSize.sm,
                    kind: LuxeButtonKind.quiet,
                    onPressed: () => context.push('/am/clients/$_clientId'),
                  ),
              ]),
              const SizedBox(height: 4),
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
              _infoRow(l10n.clientProfileIndustry, Text('${_client['industry'] ?? '—'}'), last: true),
            ]),
          ),

          // ── Location ──
          LuxeCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LuxeKind(l10n.clientProfileLocation),
              const SizedBox(height: 10),
              if (hasLocation) ...[
                if ((_location['address'] as String?)?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${_location['address']}', style: Lx.text(context, size: 14)),
                  ),
                Text('${l10n.clientProfileLastUpdated}: ${_formatDate(_location['updated_at'], l10n)}', style: Lx.text(context, size: 12, color: Lx.muted)),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LuxeButton(
                    label: l10n.clientProfileOpenMaps,
                    size: LuxeButtonSize.sm,
                    kind: LuxeButtonKind.outline,
                    onPressed: () => _openMaps(_location['maps_url'] as String?),
                  ),
                ),
              ] else
                Text(l10n.clientProfileNotSet, style: Lx.text(context, size: 13.5, color: Lx.muted)),
              if (_isAM && _clientId != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: LuxeButton(
                      label: l10n.clientProfilePickOnMap,
                      size: LuxeButtonSize.sm,
                      kind: LuxeButtonKind.outline,
                      onPressed: () => _pickOnMap(l10n),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LuxeButton(
                      label: l10n.clientProfileCheckIn,
                      size: LuxeButtonSize.sm,
                      kind: LuxeButtonKind.primary,
                      onPressed: _checkingIn ? null : () => _checkIn(l10n),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  // Mockup `.sum` tile.
  Widget _statCard(String label, String value, String sub, {bool hl = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Lx.line), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Lx.text(context, size: 10, color: Lx.faint).copyWith(letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Directionality(textDirection: TextDirection.ltr, child: Text(value, style: Lx.display(context, size: 20, color: hl ? Lx.ok : Lx.ink))),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub, style: Lx.text(context, size: 11, color: Lx.muted)),
        ],
      ]),
    );
  }

  // Mockup `.doc` row: muted label on one side, value on the other.
  Widget _infoRow(String label, Widget value, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Lx.line))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: Lx.text(context, size: 12.5, color: Lx.muted))),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: DefaultTextStyle.merge(style: Lx.text(context, size: 13.5), textAlign: TextAlign.end, child: value),
          ),
        ),
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
