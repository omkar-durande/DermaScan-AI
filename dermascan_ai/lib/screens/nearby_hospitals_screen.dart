import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../constants/api_constants.dart';
import '../services/location_service.dart';

class NearbyPlace {
  final String name;
  final String address;
  final double lat, lng;
  final double distanceKm;
  final String type;
  final String? phone;

  NearbyPlace({required this.name, required this.address, required this.lat,
    required this.lng, required this.distanceKm, required this.type, this.phone});
}

class NearbyHospitalsScreen extends StatefulWidget {
  const NearbyHospitalsScreen({super.key});
  @override
  State<NearbyHospitalsScreen> createState() => _NearbyHospitalsScreenState();
}

class _NearbyHospitalsScreenState extends State<NearbyHospitalsScreen> {
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  bool _isLoading = true, _isMapView = false;
  String _selectedFilter = 'All';
  String? _errorMessage;
  double? _userLat, _userLng;
  List<NearbyPlace> _allPlaces = [];
  final _filters = ['All', 'Hospital', 'Clinic', 'Pharmacy', 'Doctor'];

  @override
  void initState() { super.initState(); _loadNearbyHospitals(); }

  Future<void> _loadNearbyHospitals() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos == null) {
        setState(() { _isLoading = false; _errorMessage = 'Enable GPS and grant location permission.'; });
        return;
      }
      _userLat = pos.latitude; _userLng = pos.longitude;
      await _fetchFromOverpass();
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = 'Failed: $e'; });
    }
  }

  Future<void> _fetchFromOverpass() async {
    if (_userLat == null) return;
    final radius = 10000; // 10km
    final query = '''
[out:json][timeout:15];
(
  node["amenity"="hospital"](around:$radius,$_userLat,$_userLng);
  way["amenity"="hospital"](around:$radius,$_userLat,$_userLng);
  node["amenity"="clinic"](around:$radius,$_userLat,$_userLng);
  way["amenity"="clinic"](around:$radius,$_userLat,$_userLng);
  node["amenity"="doctors"](around:$radius,$_userLat,$_userLng);
  way["amenity"="doctors"](around:$radius,$_userLat,$_userLng);
  node["amenity"="pharmacy"](around:$radius,$_userLat,$_userLng);
  way["amenity"="pharmacy"](around:$radius,$_userLat,$_userLng);
  node["healthcare"="doctor"](around:$radius,$_userLat,$_userLng);
  way["healthcare"="doctor"](around:$radius,$_userLat,$_userLng);
  node["healthcare"="hospital"](around:$radius,$_userLat,$_userLng);
  way["healthcare"="hospital"](around:$radius,$_userLat,$_userLng);
  node["healthcare"="clinic"](around:$radius,$_userLat,$_userLng);
  way["healthcare"="clinic"](around:$radius,$_userLat,$_userLng);
);
out center body;
''';
    try {
      final resp = await http.post(
        Uri.parse(ApiConstants.overpassApiUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'DermaScanAI/1.0 (com.dermascan.dermascan_ai; contact@dermascan.ai)',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        setState(() { _isLoading = false; _errorMessage = 'Overpass API error: ${resp.statusCode}'; });
        return;
      }
      final data = json.decode(resp.body);
      final elements = data['elements'] as List? ?? [];
      final seen = <String>{};
      final places = <NearbyPlace>[];

      for (final el in elements) {
        double? lat, lng;
        if (el['type'] == 'node') { lat = (el['lat'] as num?)?.toDouble(); lng = (el['lon'] as num?)?.toDouble(); }
        else if (el['center'] != null) { lat = (el['center']['lat'] as num?)?.toDouble(); lng = (el['center']['lon'] as num?)?.toDouble(); }
        if (lat == null || lng == null) continue;

        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] ?? tags['name:en'] ?? '';
        if (name.isEmpty) continue;
        final key = '$name|${lat.toStringAsFixed(4)}';
        if (!seen.add(key)) continue;

        final amenity = tags['amenity'] ?? tags['healthcare'] ?? '';
        String type;
        if (amenity == 'hospital' || name.toString().toLowerCase().contains('hospital')) { type = 'Hospital'; }
        else if (amenity == 'pharmacy' || amenity == 'drugstore') { type = 'Pharmacy'; }
        else if (amenity == 'doctors' || amenity == 'doctor' || tags['healthcare'] == 'doctor') { type = 'Doctor'; }
        else { type = 'Clinic'; }

        final dist = _locationService.distanceBetween(_userLat!, _userLng!, lat, lng);
        final addr = [tags['addr:street'], tags['addr:city']].where((s) => s != null).join(', ');

        places.add(NearbyPlace(name: name, address: addr.isNotEmpty ? addr : '${dist.toStringAsFixed(1)} km away',
          lat: lat, lng: lng, distanceKm: dist, type: type, phone: tags['phone'] ?? tags['contact:phone']));
      }
      places.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      setState(() { _allPlaces = places; _isLoading = false; });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = 'Network error: $e'; });
    }
  }

  List<NearbyPlace> get _filtered => _selectedFilter == 'All' ? _allPlaces : _allPlaces.where((p) => p.type == _selectedFilter).toList();

  void _openDirections(NearbyPlace p) {
    launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$_userLat,$_userLng&destination=${p.lat},${p.lng}&travelmode=driving'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text(AppStrings.nearbyHospitals, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(_isMapView ? Icons.list_rounded : Icons.map_rounded, color: AppColors.accent), onPressed: () => setState(() => _isMapView = !_isMapView)),
        ],
      ),
      body: Column(children: [
        // Filter chips
        SizedBox(height: 48, child: ListView(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          children: _filters.map((f) {
            final sel = _selectedFilter == f;
            final count = f == 'All' ? _allPlaces.length : _allPlaces.where((p) => p.type == f).length;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? AppColors.primary : AppColors.border)),
                child: Center(child: Text('$f ($count)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sel ? Colors.white : AppColors.textSecondary))),
              ),
            );
          }).toList(),
        )),
        const SizedBox(height: 12),
        Expanded(child: _isLoading ? _loadingView() : _errorMessage != null ? _errorView() : _isMapView ? _mapView() : _listView()),
      ]),
    );
  }

  Widget _loadingView() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    CircularProgressIndicator(color: AppColors.accent), SizedBox(height: 16),
    Text('Finding hospitals near you...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
  ]));

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.location_off_rounded, size: 64, color: AppColors.textTertiary), const SizedBox(height: 16),
    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
    const SizedBox(height: 24),
    ElevatedButton.icon(onPressed: _loadNearbyHospitals, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
  ])));

  Widget _mapView() {
    if (_userLat == null) return _errorView();
    final places = _filtered;
    final markers = <Marker>[
      Marker(point: LatLng(_userLat!, _userLng!), width: 40, height: 40,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 32)),
    ];
    for (final p in places) {
      markers.add(Marker(point: LatLng(p.lat, p.lng), width: 36, height: 36, child: Container(
        decoration: BoxDecoration(color: _typeColor(p.type), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
        child: Icon(_typeIcon(p.type), color: Colors.white, size: 18),
      )));
    }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: LatLng(_userLat!, _userLng!), initialZoom: 13),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.dermascan.ai',
          maxZoom: 19,
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _listView() {
    final places = _filtered;
    if (places.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.search_off_rounded, size: 56, color: AppColors.textTertiary), const SizedBox(height: 16),
        Text('No ${_selectedFilter == "All" ? "medical facilities" : "${_selectedFilter}s"} found nearby', style: const TextStyle(color: AppColors.textSecondary)),
      ]));
    }
    return RefreshIndicator(onRefresh: _loadNearbyHospitals, color: AppColors.accent, child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: places.length,
      itemBuilder: (ctx, i) => _buildCard(places[i]),
    ));
  }

  Color _typeColor(String t) {
    switch (t) { case 'Hospital': return AppColors.danger; case 'Pharmacy': return AppColors.success; case 'Doctor': return AppColors.accent; default: return AppColors.info; }
  }
  IconData _typeIcon(String t) {
    switch (t) { case 'Hospital': return Icons.local_hospital_rounded; case 'Pharmacy': return Icons.local_pharmacy_rounded; case 'Doctor': return Icons.medical_services_rounded; default: return Icons.health_and_safety_rounded; }
  }

  Widget _buildCard(NearbyPlace p) {
    final color = _typeColor(p.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_typeIcon(p.type), color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(p.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color))),
          ])),
          Text('${p.distanceKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary), const SizedBox(width: 4),
          Expanded(child: Text(p.address, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (p.phone != null) Expanded(child: OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('tel:${p.phone}')),
            icon: const Icon(Icons.phone_rounded, size: 16), label: const Text('Call'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(vertical: 8)),
          )),
          if (p.phone != null) const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            onPressed: () => _openDirections(p),
            icon: const Icon(Icons.directions_rounded, size: 16), label: const Text('Directions'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 8)),
          )),
        ]),
      ]),
    );
  }
}
