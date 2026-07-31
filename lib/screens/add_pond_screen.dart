import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/geocoding_service.dart';
import 'package:farmigrow_ai/constants/map_config.dart';

class AddPondScreen extends StatefulWidget {
  const AddPondScreen({super.key});
  @override
  State<AddPondScreen> createState() => _AddPondScreenState();
}

class _AddPondScreenState extends State<AddPondScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();

  String _selectedSpecies = 'Fish';
  DateTime? _stockingDate;
  LatLng _center = const LatLng(17.385044, 78.486671);
  List<LatLng> _polygonPoints = [];
  bool _searching = false;
  List<GeoSearchResult> _searchResults = [];
  bool _saving = false;

  final List<String> _speciesList = [
    'Fish', 'Rohu', 'Catla', 'Tilapia', 'Shrimp', 'Prawn', 'Catfish', 'Other'
  ];

  double get _areaAcres {
    if (_polygonPoints.length < 3) return 0.0;
    double area = 0;
    final n = _polygonPoints.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      area += _polygonPoints[i].longitude * _polygonPoints[j].latitude;
      area -= _polygonPoints[j].longitude * _polygonPoints[i].latitude;
    }
    area = area.abs() / 2.0;
    return double.parse((area * 111320 * 111320 / 4047).toStringAsFixed(2));
  }

  void _onMapTap(_, LatLng point) {
    setState(() => _polygonPoints.add(point));
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = loc);
      _mapController.move(loc, 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await GeocodingService.search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    }
  }

  void _selectSearchResult(GeoSearchResult r) {
    final loc = LatLng(r.lat, r.lng);
    setState(() {
      _center = loc;
      _searchResults = [];
      _searchController.text = r.name;
    });
    _mapController.move(loc, 16);
    FocusScope.of(context).unfocus();
  }

  Future<void> _savePond() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a pond name')));
      return;
    }
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap at least 3 points on the map to mark the pond boundary')));
      return;
    }

    setState(() => _saving = true);

    final pond = AquaPond(
      id: 'pond_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      areaAcres: _areaAcres,
      locationName: _searchController.text.isNotEmpty
          ? _searchController.text
          : 'Lat ${_center.latitude.toStringAsFixed(4)}, Lng ${_center.longitude.toStringAsFixed(4)}',
      latitude: _center.latitude,
      longitude: _center.longitude,
      gpsPolygon: _polygonPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
      species: _selectedSpecies,
      stockingDate: _stockingDate != null
          ? '${_stockingDate!.year}-${_stockingDate!.month.toString().padLeft(2, '0')}-${_stockingDate!.day.toString().padLeft(2, '0')}'
          : '',
    );

    if (mounted) {
      Navigator.pop(context, pond);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text('Add Pond', style: AppTheme.h1()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _savePond,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                : Text('SAVE', style: AppTheme.button().copyWith(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                // Pond name
                TextField(
                  controller: _nameController,
                  style: AppTheme.body().copyWith(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    labelText: 'Pond Name',
                    labelStyle: AppTheme.bodySmall(),
                    prefixIcon: const Icon(Icons.water, color: Colors.blue),
                    filled: true, fillColor: AppTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                // Species
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSpecies,
                            dropdownColor: AppTheme.bgCardLight,
                            isExpanded: true,
                            hint: Text('Select Species', style: AppTheme.bodySmall()),
                            items: _speciesList.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s, style: AppTheme.body().copyWith(color: AppTheme.textWhite)),
                            )).toList(),
                            onChanged: (v) => setState(() => _selectedSpecies = v!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.dark(primary: AppTheme.primaryGreen),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _stockingDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Text(
                          _stockingDate != null
                              ? 'Stocked: ${_stockingDate!.day}/${_stockingDate!.month}/${_stockingDate!.year}'
                              : 'Stocking Date',
                          style: AppTheme.bodySmall(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                // Location search
                TextField(
                  controller: _searchController,
                  style: AppTheme.body().copyWith(color: AppTheme.textWhite),
                  decoration: InputDecoration(
                    hintText: 'Search village, area, or coordinates',
                    hintStyle: AppTheme.bodySmall(),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.accentBlue),
                    suffixIcon: _searching
                        ? const Padding(padding: EdgeInsets.all(14),
                            child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: const Icon(Icons.my_location, color: AppTheme.primaryGreen),
                            onPressed: _getCurrentLocation,
                          ),
                    filled: true, fillColor: AppTheme.bgCard,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                  ),
                  onChanged: (v) => Future.delayed(
                    const Duration(milliseconds: 600), () => _searchLocation(v)),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: AppTheme.cardDecoration(color: AppTheme.bgCardLight),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (_, i) {
                        final r = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place, color: AppTheme.accentBlue, size: 18),
                          title: Text(r.name, style: AppTheme.body().copyWith(color: AppTheme.textWhite), maxLines: 1),
                          onTap: () => _selectSearchResult(r),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Instruction bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.bgCard,
            child: Row(
              children: [
                const Icon(Icons.touch_app, color: AppTheme.primaryGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _polygonPoints.isEmpty
                        ? 'Tap on the map to mark pond boundary points'
                        : '${_polygonPoints.length} points · ${_areaAcres} acres · Tap more or SAVE',
                    style: AppTheme.bodySmall(),
                  ),
                ),
                if (_polygonPoints.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _polygonPoints.clear()),
                    child: Text('Clear', style: AppTheme.bodySmall().copyWith(color: AppTheme.dangerRed)),
                  ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.googleHybridTemplate,
                  userAgentPackageName: 'com.farmigrow.ai',
                  maxZoom: 20,
                ),
                if (_polygonPoints.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _polygonPoints,
                        color: Colors.blue.withOpacity(0.3),
                        borderColor: Colors.blue,
                        borderStrokeWidth: 2.5,
                      ),
                    ],
                  ),
                PolylineLayer(
                  polylines: [
                    if (_polygonPoints.length >= 2)
                      Polyline(
                        points: [..._polygonPoints, if (_polygonPoints.length >= 3) _polygonPoints.first],
                        color: Colors.blue,
                        strokeWidth: 2,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: _polygonPoints.asMap().entries.map((e) => Marker(
                    point: e.value,
                    width: 14, height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: e.key == 0 ? Colors.blue : Colors.lightBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
