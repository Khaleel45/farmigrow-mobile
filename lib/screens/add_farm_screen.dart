import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/geocoding_service.dart';
import 'package:farmigrow_ai/services/satellite_metadata_service.dart';
import 'package:farmigrow_ai/constants/map_config.dart';

class AddFarmScreen extends StatefulWidget {
  const AddFarmScreen({super.key});
  @override
  State<AddFarmScreen> createState() => _AddFarmScreenState();
}

enum DrawMode { none, tap, walk }

Timer? _searchDebounceTimer;

class _AddFarmScreenState extends State<AddFarmScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _polygonPoints = [];
  DrawMode _drawMode = DrawMode.none;
  bool _polygonClosed = false;
  bool _locating = false;
  bool _searching = false;
  bool _saving = false;
  String _selectedCrop = 'Rice';
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  LatLng _center = const LatLng(17.385044, 78.486671);
  SatelliteMetadata? _imageryMetadata;
  bool _useSatellite = true;
  StreamSubscription<Position>? _walkSub;
  List<GeoSearchResult> _searchResults = [];

  final List<String> _crops = [
    'Rice', 'Wheat', 'Cotton', 'Chilli', 'Maize', 'Sugarcane',
    'Soybean', 'Groundnut', 'Sunflower', 'Vegetables'
  ];

  @override
  void initState() {
    super.initState();
    _fetchImageryMetadata();
  }

  Future<void> _fetchImageryMetadata() async {
    final meta = await SatelliteMetadataService.getMetadataForLocation(
        _center.latitude, _center.longitude);
    if (mounted) setState(() => _imageryMetadata = meta);
  }

  @override
  void dispose() {
    _walkSub?.cancel();
    _searchDebounceTimer?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _calculateAcres() {
    if (_polygonPoints.length < 3) return 0;
    double area = 0;
    final n = _polygonPoints.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += _polygonPoints[i].longitude * _polygonPoints[j].latitude;
      area -= _polygonPoints[j].longitude * _polygonPoints[i].latitude;
    }
    area = area.abs() / 2;
    final hectares = (area * 111320 * 110540) / 10000;
    return hectares * 2.471;
  }

  void _onSearchChanged(String v) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 600), () => _searchLocation(v));
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await GeocodingService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No locations found. Try a different spelling or a nearby town name.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _searching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search failed — check your internet connection and try again')),
        );
      }
    }
  }

  void _selectSearchResult(GeoSearchResult result) {
    final loc = LatLng(result.lat, result.lng);
    setState(() {
      _center = loc;
      _searchResults = [];
      _searchController.text = result.name;
    });
    _mapController.move(loc, 16);
    FocusScope.of(context).unfocus();
    _fetchImageryMetadata();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Enable in phone settings.')),
          );
        }
        setState(() => _locating = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final loc = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = loc;
        _locating = false;
      });
      _mapController.move(loc, 17);
      _fetchImageryMetadata();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 Moved to your current location!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _locating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    }
  }

  Future<void> _startWalkMode() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required for walk mode')),
        );
      }
      return;
    }

    setState(() {
      _drawMode = DrawMode.walk;
      _polygonClosed = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚶 Walk Mode ON — walk around your field border'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 3),
        ),
      );
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _walkSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _polygonPoints.add(point);
        _center = point;
      });
      _mapController.move(point, _mapController.camera.zoom);
    });
  }

  void _stopWalkMode() {
    _walkSub?.cancel();
    _walkSub = null;
    setState(() => _drawMode = DrawMode.none);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Walk tracking stopped — ${_polygonPoints.length} points recorded')),
      );
    }
  }

  void _onMapTap(TapPosition tapPos, LatLng point) {
    if (_drawMode != DrawMode.tap || _polygonClosed) return;
    setState(() => _polygonPoints.add(point));
  }

  void _closePolygon() {
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 3 points to close the boundary')),
      );
      return;
    }
    setState(() {
      _polygonClosed = true;
      _drawMode = DrawMode.none;
    });
    _walkSub?.cancel();
  }

  void _saveFarm() {
    if (_saving) return;

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please enter a farm name')),
      );
      return;
    }
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please draw your farm boundary first (need at least 3 points)')),
      );
      return;
    }

    setState(() => _saving = true);

    final areaAcres = _calculateAcres();
    final firstPoint = _polygonPoints[0];

    final farm = Farm(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      cropType: _selectedCrop,
      sowingDate: DateTime.now().toString().split(' ')[0],
      areaAcres: double.parse(areaAcres.toStringAsFixed(2)),
      locationName: _searchController.text.isNotEmpty
          ? _searchController.text
          : 'Lat ${firstPoint.latitude.toStringAsFixed(4)}, Lng ${firstPoint.longitude.toStringAsFixed(4)}',
      healthScore: 78,
      healthStatus: 'New Farm',
      latitude: firstPoint.latitude,
      longitude: firstPoint.longitude,
      waterStressLevel: 'Low',
      waterStressConfidence: 75,
      pestRiskPercent: 8,
      pestConfidence: 70,
      diseaseRiskLevel: 'Low',
      diseaseRiskNotes: 'New farm - initial scan pending',
      lastScanDate: 'Just now',
      gpsPolygon: _polygonPoints.map((p) => {
        'lat': p.latitude,
        'lng': p.longitude,
      }).toList(),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.pop(context, farm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text('Add New Farm',
            style: GoogleFonts.poppins(
                color: AppTheme.textWhite, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveFarm,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                : Text('SAVE',
                    style: GoogleFonts.poppins(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.poppins(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'Farm Name',
                    labelStyle: GoogleFonts.poppins(color: AppTheme.textGrey),
                    hintText: 'e.g. North Field A',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textGrey.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.agriculture, color: AppTheme.primaryGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCrop,
                  isExpanded: true,
                  dropdownColor: AppTheme.bgCard,
                  style: GoogleFonts.poppins(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'Crop Type',
                    labelStyle: GoogleFonts.poppins(color: AppTheme.textGrey),
                    prefixIcon: const Icon(Icons.grass, color: AppTheme.primaryGreen),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _crops
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: GoogleFonts.poppins(color: AppTheme.textWhite))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCrop = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: AppTheme.textWhite, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Search location (village/town or lat,lng)',
                    labelStyle: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 12),
                    hintText: 'e.g. Guntur or 16.5062, 80.6480',
                    hintStyle: GoogleFonts.poppins(color: AppTheme.textGrey.withOpacity(0.5), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.accentBlue),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppTheme.textGrey, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchResults = []);
                                },
                              )
                            : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: _onSearchChanged,
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place, color: AppTheme.accentBlue, size: 18),
                          title: Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: AppTheme.textWhite, fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: r.fullName.isNotEmpty
                              ? Text(r.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 10))
                              : null,
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _drawMode != DrawMode.none
                ? AppTheme.primaryGreen.withOpacity(0.15)
                : AppTheme.bgCardLight,
            child: Text(
              _drawMode == DrawMode.walk
                  ? '🚶 Walking mode active — moving with you (${_polygonPoints.length} points)'
                  : _drawMode == DrawMode.tap
                      ? (_polygonClosed
                          ? '✅ Boundary complete! ${_polygonPoints.length} points · ${_calculateAcres().toStringAsFixed(2)} acres'
                          : '📍 Tap on map to mark boundary points (${_polygonPoints.length} added)')
                      : _polygonPoints.isNotEmpty
                          ? '✅ ${_polygonPoints.length} points ready · ${_calculateAcres().toStringAsFixed(2)} acres — tap SAVE'
                          : 'Choose Draw Boundary or Walk Mode below',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _drawMode != DrawMode.none ? AppTheme.primaryGreen : AppTheme.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (_useSatellite)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppTheme.bgCardLight,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 12, color: AppTheme.textGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _imageryMetadata != null && _imageryMetadata!.found
                          ? 'Imagery: ${_imageryMetadata!.source ?? "Esri World Imagery"}'
                              '${_imageryMetadata!.captureDate != null ? " · captured ${_imageryMetadata!.captureDate}" : ""}'
                          : 'Free satellite imagery for this area may be outdated by months or years — it is not real-time.',
                      style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textGrey),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onTap: _onMapTap,
                    // Google Maps supports up to zoom 20 for most areas.
                    maxZoom: 20,
                  ),
                  children: [
                    // Google Maps Hybrid when satellite mode is on —
                    // sharper, more recent imagery for Indian farmland
                    // with road/village labels built in.
                    // Dark CartoDB when street map mode is on.
                    TileLayer(
                      urlTemplate: _useSatellite
                          ? MapConfig.googleHybridTemplate
                          : MapConfig.cartoDarkTemplate,
                      subdomains: _useSatellite ? const [] : const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.farmigrow.ai',
                      maxZoom: 20,
                      maxNativeZoom: 20,
                    ),
                    if (_polygonPoints.length >= 3)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _polygonPoints,
                            color: AppTheme.primaryGreen.withOpacity(0.3),
                            borderColor: Colors.yellow,
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                    if (_polygonPoints.length >= 2 && !_polygonClosed)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _polygonPoints,
                            color: Colors.yellow,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        ..._polygonPoints.asMap().entries.map((e) => Marker(
                              point: e.value,
                              width: 24, height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: e.key == 0 ? Colors.yellow : AppTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: _drawMode == DrawMode.tap
                                    ? Center(
                                        child: Text('${e.key + 1}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold)),
                                      )
                                    : null,
                              ),
                            )),
                        Marker(
                          point: _center,
                          width: 20, height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(color: AppTheme.accentBlue.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (_polygonPoints.isNotEmpty)
                  Positioned(
                    left: 12, top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_polygonPoints.length} pts · ${_calculateAcres().toStringAsFixed(2)} acres',
                        style: GoogleFonts.poppins(
                            color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                Positioned(
                  right: 12, top: 12,
                  child: GestureDetector(
                    onTap: () => setState(() => _useSatellite = !_useSatellite),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_useSatellite ? Icons.map : Icons.satellite_alt,
                              size: 16, color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          Text(_useSatellite ? 'Map' : 'Satellite',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  right: 12, bottom: 100,
                  child: Column(
                    children: [
                      _mapBtn(Icons.my_location, _locating ? null : _getCurrentLocation, _locating),
                      const SizedBox(height: 6),
                      _mapBtn(Icons.add, () => _mapController.move(
                          _mapController.camera.center, _mapController.camera.zoom + 1), false),
                      const SizedBox(height: 6),
                      _mapBtn(Icons.remove, () => _mapController.move(
                          _mapController.camera.center, _mapController.camera.zoom - 1), false),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: AppTheme.bgCard,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_drawMode == DrawMode.tap) {
                            setState(() => _drawMode = DrawMode.none);
                          } else {
                            setState(() {
                              _drawMode = DrawMode.tap;
                              _polygonClosed = false;
                            });
                          }
                        },
                        icon: Icon(_drawMode == DrawMode.tap ? Icons.stop_circle : Icons.touch_app, size: 16),
                        label: Text(_drawMode == DrawMode.tap ? 'Stop' : 'Tap to Draw',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _drawMode == DrawMode.tap ? Colors.red.shade600 : AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_drawMode == DrawMode.walk) {
                            _stopWalkMode();
                          } else {
                            _startWalkMode();
                          }
                        },
                        icon: Icon(_drawMode == DrawMode.walk ? Icons.stop_circle : Icons.directions_walk, size: 16),
                        label: Text(_drawMode == DrawMode.walk ? 'Stop Walk' : 'Walk Border',
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _drawMode == DrawMode.walk ? Colors.red.shade600 : AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_polygonPoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_drawMode == DrawMode.tap && _polygonPoints.length >= 3 && !_polygonClosed)
                        _toolBtn(Icons.check_circle_outline, 'Close Boundary', Colors.teal, _closePolygon),
                      if (_drawMode == DrawMode.tap && _polygonPoints.isNotEmpty)
                        _toolBtn(Icons.undo, 'Undo', Colors.orange, () {
                          setState(() {
                            _polygonPoints.removeLast();
                            _polygonClosed = false;
                          });
                        }),
                      _toolBtn(Icons.delete_outline, 'Clear All', Colors.red, () {
                        _walkSub?.cancel();
                        setState(() {
                          _polygonPoints.clear();
                          _polygonClosed = false;
                          _drawMode = DrawMode.none;
                        });
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback? onTap, bool loading) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: loading
            ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, size: 20, color: AppTheme.primaryGreen),
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.poppins(fontSize: 8, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
