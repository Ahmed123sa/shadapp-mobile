import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../../../core/theme.dart';

/// Result returned by [LocationPickerPage] when the manager confirms a pin.
class PickedLocation {
  final double latitude;
  final double longitude;
  final String? address;
  const PickedLocation({required this.latitude, required this.longitude, this.address});
}

/// Free, no-API-key location picker built on OpenStreetMap (via flutter_map)
/// and the Nominatim search/reverse-geocoding endpoints — the same stack the
/// dashboard's LocationPickerModal already uses. No Google Maps SDK, no
/// billing, no usage tracking beyond Nominatim's own public rate limits.
class LocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _defaultCenter = LatLng(24.7136, 46.6753); // Riyadh — only used with no saved location yet.

  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _addressController = TextEditingController();

  LatLng? _selected;
  bool _searching = false;
  bool _reverseGeocoding = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeQueryComponent(q)}');
      final res = await http.get(uri, headers: {'Accept-Language': 'ar,en'});
      final results = jsonDecode(res.body) as List<dynamic>;
      if (results.isEmpty) {
        if (mounted) setState(() => _searchError = l10n.locationPickerSearchNoResults);
        return;
      }
      final first = results.first as Map<String, dynamic>;
      final lat = double.parse(first['lat'] as String);
      final lon = double.parse(first['lon'] as String);
      final display = first['display_name'] as String?;
      setState(() {
        _selected = LatLng(lat, lon);
        if (display != null) _addressController.text = display;
      });
      _mapController.move(LatLng(lat, lon), 15);
    } catch (_) {
      if (mounted) setState(() => _searchError = l10n.locationPickerSearchFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() => _selected = point);
    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _reverseGeocoding = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}');
      final res = await http.get(uri, headers: {'Accept-Language': 'ar,en'});
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final display = data['display_name'] as String?;
      if (mounted && display != null) setState(() => _addressController.text = display);
    } catch (_) {
      // Best-effort — the manager can still type the address manually.
    } finally {
      if (mounted) setState(() => _reverseGeocoding = false);
    }
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.pop(
      context,
      PickedLocation(
        latitude: _selected!.latitude,
        longitude: _selected!.longitude,
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final center = _selected ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.locationPickerTitle, style: const TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(l10n.locationPickerHint, style: const TextStyle(fontSize: 11, color: ShadColors.textSecondary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(hintText: l10n.locationPickerSearchPh, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(l10n.locationPickerSearchBtn),
                ),
              ),
            ]),
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
              child: Align(alignment: AlignmentDirectional.centerStart, child: Text(_searchError!, style: const TextStyle(fontSize: 11, color: ShadColors.error))),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selected != null ? 15 : 5,
                    onTap: (tapPos, point) => _onMapTap(point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.shadapp.client',
                    ),
                    if (_selected != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _selected!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: ShadColors.crimson, size: 40),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.locationPickerAddressLabel,
                  suffixIcon: _reverseGeocoding
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  // No busy state needed: this only pops with the chosen
                  // point — the caller performs the actual save.
                  onPressed: _selected == null ? null : _confirm,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(l10n.locationPickerConfirm),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
