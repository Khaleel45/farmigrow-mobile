import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/screens/add_farm_screen.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/farm_storage.dart';
import 'package:farmigrow_ai/services/geocoding_service.dart';
import 'package:farmigrow_ai/services/satellite_metadata_service.dart';
import 'package:farmigrow_ai/services/api_service.dart';
import 'package:farmigrow_ai/services/scan_history_storage.dart';
import 'package:farmigrow_ai/constants/map_config.dart';

class SatelliteScreen extends StatefulWidget {
  final String? farmName;
  const SatelliteScreen({super.key, this.farmName});
  @override
  State<SatelliteScreen> createState() => _SatelliteScreenState();
}

Timer? _satSearchDebounce;

class _SatelliteScreenState extends State<SatelliteScreen> {
  String _selectedBand = 'NDVI';
  Farm? _selectedFarm;
  List<Farm> _allFarms = [];
  SatelliteMetadata? _imageryMetadata;
  bool _loadingMetadata = false;
  bool _scanning = false;
  bool _loading = true;
  final MapController _mapController = MapController();

  final TextEditingController _searchController = TextEditingController();
  List<GeoSearchResult> _searchResults = [];
  bool _searching = false;
  LatLng? _searchedLocation; // when set, map centers here instead of farm

  final List<Map<String, dynamic>> _bands = [
    {'name': 'NDVI', 'icon': Icons.eco, 'color': const Color(0xFF00C853)},
    {'name': 'Water', 'icon': Icons.water_drop, 'color': Colors.blue},
    {'name': 'Pest', 'icon': Icons.bug_report, 'color': Colors.orange},
    {'name': 'Disease', 'icon': Icons.coronavirus, 'color': Colors.purple},
    {'name': 'Flooding', 'icon': Icons.waves, 'color': Colors.indigo},
  ];

  final Map<String, String> _bandDescriptions = {
    'NDVI': 'Normalized Difference Vegetation Index\nCurrent indices map a localized vigor decay of 12% in the northwest slope. Possible initial dry root block.',
    'Water': 'Normalized Difference Water Index\nSoil moisture levels indicate moderate irrigation deficit in north-east quadrant.',
    'Pest': 'Pest Colonization Risk Index\nSecondary NDVI anomalies suggest potential Jassid hotspot on western borders.',
    'Disease': 'Blast Fungus Disease Threat Index\nHumidity-driven spore dispersal risk is elevated. Monitor leaf surface.',
    'Flooding': 'Standing Water & Flood Zone Detection\nNo active waterlogging detected. Drainage channels functional.',
  };

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  @override
  void dispose() {
    _satSearchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFarms() async {
    final farms = await FarmStorage.getUserFarms();
    setState(() {
      _allFarms = farms;
      _loading = false;
      if (farms.isEmpty) {
        _selectedFarm = null;
      } else if (widget.farmName != null) {
        _selectedFarm = farms.firstWhere(
          (f) => f.name == widget.farmName,
          orElse: () => farms.first,
        );
      } else {
        _selectedFarm = farms.first;
      }
    });
    if (_selectedFarm != null) {
      _mapController.move(LatLng(_selectedFarm!.latitude, _selectedFarm!.longitude), 14);
      _fetchImageryMetadata(_selectedFarm!);
    }
    _syncFarmsInBackground();
  }

  /// Pulls cloud farms after the initial local-only load, refreshing
  /// the list without resetting which farm is currently selected.
  /// Shows a prominent dialog when a zone-level hotspot is detected.
  /// Tells the farmer exactly which part of their farm needs attention
  /// without revealing the internal zone-splitting mechanism.
  void _showZoneAlertDialog(
    String summary,
    List hotspots,
    Farm farm,
    int zonesScanned,
    Map weather,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLG)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: AppTheme.amber, size: 24),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(child: Text('Scan Complete', style: AppTheme.h1())),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Farm health
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${farm.name}', style: AppTheme.h3()),
                    Text('Health: ${farm.healthScore}% · ${farm.healthStatus}',
                        style: AppTheme.bodySmall()),
                    Text('Scanned ${farm.areaAcres} acres in detail',
                        style: AppTheme.caption()),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // Summary
              Text(summary, style: AppTheme.body()),
              const SizedBox(height: AppTheme.spaceMD),

              // Hotspot zones
              if (hotspots.isNotEmpty) ...[
                Text('AREAS NEEDING ATTENTION', style: AppTheme.label()),
                const SizedBox(height: AppTheme.spaceSM),
                ...hotspots.map((h) {
                  final sev = h['severity']?.toString() ?? 'Moderate';
                  final color = sev == 'High' ? AppTheme.dangerRed : AppTheme.amber;
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                    padding: const EdgeInsets.all(AppTheme.spaceMD),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: color, size: 18),
                        const SizedBox(width: AppTheme.spaceSM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${h['zone']} Zone — $sev Risk',
                                style: AppTheme.h3().copyWith(color: color),
                              ),
                              if (h['pest_risk'] != null && h['pest_risk'] > 0)
                                Text(
                                  'Pest risk: ${h['pest_risk']}%',
                                  style: AppTheme.bodySmall(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // Weather
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                '🌡️ ${weather["temperature"] ?? "-"}°C · '
                '💧 ${weather["humidity"] ?? "-"}% humidity · '
                '🌧 ${weather["rainfall_7d"] ?? "-"}mm rain/7d',
                style: AppTheme.caption(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: AppTheme.button().copyWith(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Future<void> _syncFarmsInBackground() async {
    final synced = await FarmStorage.syncFromCloud();
    if (!mounted) return;
    setState(() => _allFarms = synced);
    // Keep the same selected farm if it still exists in the synced list
    if (_selectedFarm != null) {
      final stillExists = synced.where((f) => f.id == _selectedFarm!.id);
      if (stillExists.isNotEmpty) {
        setState(() => _selectedFarm = stillExists.first);
      }
    }
  }

  Color get _bandColor =>
      _bands.firstWhere((b) => b['name'] == _selectedBand)['color'] as Color;

  List<LatLng> _polygonForFarm(Farm farm) {
    if (farm.gpsPolygon != null && farm.gpsPolygon!.length >= 3) {
      return farm.gpsPolygon!
          .map((p) => LatLng(p['lat']!, p['lng']!))
          .toList();
    }
    const delta = 0.004;
    return [
      LatLng(farm.latitude + delta, farm.longitude - delta),
      LatLng(farm.latitude + delta, farm.longitude + delta),
      LatLng(farm.latitude - delta, farm.longitude + delta),
      LatLng(farm.latitude - delta, farm.longitude - delta),
    ];
  }

  void _onFarmSelected(Farm farm) {
    setState(() {
      _selectedFarm = farm;
      _searchedLocation = null;
      _searchController.clear();
      _searchResults = [];
    });
    _mapController.move(LatLng(farm.latitude, farm.longitude), 14);
    _fetchImageryMetadata(farm);
  }

  Future<void> _fetchImageryMetadata(Farm farm) async {
    setState(() => _loadingMetadata = true);
    final meta = await SatelliteMetadataService.getMetadataForLocation(
        farm.latitude, farm.longitude);
    if (mounted) {
      setState(() {
        _imageryMetadata = meta;
        _loadingMetadata = false;
      });
    }
  }

  /// Triggers a real Sentinel-2/Sentinel-1 scan for the currently
  /// selected farm via the backend, then refreshes local + cloud
  /// storage with the updated health/water-stress fields.
  Future<void> _scanSelectedFarm() async {
    final farm = _selectedFarm;
    if (farm == null || _scanning) return;

    if (farm.gpsPolygon == null || farm.gpsPolygon!.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ This farm has no drawn boundary. Go to Add Farm and draw the field boundary first.'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _scanning = true);

    // Always sync the farm to the backend first so it exists in
    // Railway's database when the scan runs. This prevents the
    // "Not Found" 404 error caused by farms that only existed
    // in local storage but never reached the server.
    await ApiService.syncFarm(farm);

    final result = await ApiService.scanFarm(farm.id);
    setState(() => _scanning = false);

    if (!mounted) return;

    if (result['success'] == true) {
      if (result['warning'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ ${result['warning']}'),
            backgroundColor: AppTheme.amber,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }

      // Extract all 6 risk dimensions from the full pipeline response
      final healthScore = (result['health_score'] as num?)?.toInt() ?? farm.healthScore;
      final healthStatus = result['health_status']?.toString() ?? farm.healthStatus;
      final waterStress = result['water_stress_level']?.toString() ?? farm.waterStressLevel;
      final waterlogging = result['waterlogging_severity']?.toString() ?? farm.waterloggingSeverity;
      final scanDate = result['ndvi']?['date']?.toString() ?? result['last_scan_date']?.toString() ?? farm.lastScanDate;

      // Pest data
      final pestPercent = (result['pest_risk_percent'] as num?)?.toInt() ?? farm.pestRiskPercent;
      final pestDetail = result['pest_detail'] as Map? ?? {};
      final topPest = pestDetail['top_pest_name']?.toString() ?? '';
      final pestRec = pestDetail['pest_recommendation']?.toString() ?? '';

      // Disease data
      final diseaseLevel = result['disease_risk_level']?.toString() ?? farm.diseaseRiskLevel;
      final diseaseDetail = result['disease_detail'] as Map? ?? {};
      final diseaseElevated = diseaseDetail['disease_risk_elevated'] as bool? ?? farm.diseaseRiskElevated;
      final diseaseNotes = diseaseDetail['disease_risk_notes']?.toString() ?? farm.diseaseRiskNotes;

      // Water stress detail
      final waterDetail = result['water_detail'] as Map? ?? {};
      final waterConf = (waterDetail['water_stress_confidence'] as num?)?.toInt() ?? farm.waterStressConfidence;
      final waterRec = waterDetail['water_stress_recommendation']?.toString() ?? farm.waterStressArea;

      final updatedFarm = Farm(
        id: farm.id,
        name: farm.name,
        cropType: farm.cropType,
        cropTypeTelugu: farm.cropTypeTelugu,
        sowingDate: farm.sowingDate,
        areaAcres: farm.areaAcres,
        locationName: farm.locationName,
        locationNameTelugu: farm.locationNameTelugu,
        latitude: farm.latitude,
        longitude: farm.longitude,
        gpsPolygon: farm.gpsPolygon,
        polygonPoints: farm.polygonPoints,
        // All 6 risk dimensions updated by satellite + weather pipeline:
        healthScore: healthScore,
        healthStatus: healthStatus,
        waterStressLevel: waterStress,
        waterStressConfidence: waterConf,
        waterStressArea: waterRec,
        waterStressAreaTelugu: farm.waterStressAreaTelugu,
        waterloggingSeverity: waterlogging,
        waterloggingArea: farm.waterloggingArea,
        pestRiskPercent: pestPercent,
        pestConfidence: pestPercent,
        pestHotspots: topPest.isNotEmpty && topPest != 'None' ? [topPest] : farm.pestHotspots,
        diseaseRiskLevel: diseaseLevel,
        diseaseRiskElevated: diseaseElevated,
        diseaseRiskNotes: diseaseNotes.isNotEmpty ? diseaseNotes : pestRec,
        healthStatusTelugu: farm.healthStatusTelugu,
        diseaseRiskNotesTelugu: farm.diseaseRiskNotesTelugu,
        lastScanDate: scanDate,
      );

      await FarmStorage.saveFarm(updatedFarm);

      // Save to scan history for trend charts
      await ScanHistoryStorage.addRecord(
        updatedFarm.id,
        ScanRecord(
          date: scanDate.replaceAll('TEST-', ''),
          healthScore: updatedFarm.healthScore,
          pestRiskPercent: updatedFarm.pestRiskPercent,
          waterStressLevel: updatedFarm.waterStressLevel,
          diseaseRiskLevel: updatedFarm.diseaseRiskLevel,
        ),
      );

      setState(() {
        _selectedFarm = updatedFarm;
        final idx = _allFarms.indexWhere((f) => f.id == updatedFarm.id);
        if (idx >= 0) _allFarms[idx] = updatedFarm;
      });

      // Extract zone analysis
      final zoneAnalysis = result['zone_analysis'] as Map? ?? {};
      final hotspots = (zoneAnalysis['hotspot_zones'] as List? ?? []);
      final summary = zoneAnalysis['summary']?.toString() ?? '';
      final zonesScanned = zoneAnalysis['zones_scanned'] ?? 1;
      final weather = result['weather'] as Map? ?? {};

      // Show zone-aware result
      if (hotspots.isNotEmpty && summary.isNotEmpty) {
        _showZoneAlertDialog(summary, hotspots, updatedFarm, zonesScanned, weather);
      } else {
        final sentinelUsed = result['sentinel_available'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Scan complete!\n'
              '${sentinelUsed ? "🛰️ Real Sentinel-2 satellite data" : "🌤️ Weather-based estimate (no cloud-free satellite pass)"}\n'
              'Health: $healthScore% · Water: $waterStress\n'
              'Pest: $pestPercent% · Disease: $diseaseLevel\n'
              '🌡️ ${weather["temperature"] ?? "-"}°C · 💧${weather["humidity"] ?? "-"}% humidity',
            ),
            backgroundColor: sentinelUsed ? AppTheme.primaryGreen : AppTheme.amber,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } else {
      final error = result['error']?.toString() ?? 'Scan failed';
      // Show the real error so we can diagnose it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.contains('not configured')
                ? '🛰️ Sentinel credentials not set on Railway yet. Add SENTINEL_CLIENT_ID and SENTINEL_CLIENT_SECRET in Railway → Variables.'
                : error.contains('no drawn boundary') || error.contains('3 points')
                    ? '⚠️ Draw the farm boundary first (at least 3 points) then scan.'
                    : '⚠️ $error',
          ),
          backgroundColor: AppTheme.dangerRed,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // ─── LOCATION / LANDMARK SEARCH ───────────────────────
  void _onSearchChanged(String v) {
    _satSearchDebounce?.cancel();
    _satSearchDebounce = Timer(const Duration(milliseconds: 600), () => _searchLocation(v));
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
      _searchedLocation = loc;
      _searchResults = [];
      _searchController.text = result.name;
    });
    _mapController.move(loc, 16);
    FocusScope.of(context).unfocus();
  }

  IconData _iconForResultType(String type, String category) {
    if (category == 'water' || type.contains('lake') || type.contains('water')) return Icons.water;
    if (category == 'highway' || type == 'road') return Icons.add_road;
    if (type == 'village' || type == 'hamlet') return Icons.holiday_village;
    if (type == 'town' || type == 'city') return Icons.location_city;
    if (category == 'landuse' || type == 'farmland') return Icons.agriculture;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_selectedFarm == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(Icons.arrow_back_ios, color: AppTheme.textWhite, size: 18),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text('Satellite Index', style: AppTheme.h1()),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceXXL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.satellite_alt, color: AppTheme.textGrey, size: 48),
                        const SizedBox(height: AppTheme.spaceLG),
                        Text('No farms to show yet', style: AppTheme.h1()),
                        const SizedBox(height: AppTheme.spaceSM),
                        Text(
                          'Draw your first farm boundary to see satellite imagery and analysis here.',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySmall(),
                        ),
                        const SizedBox(height: AppTheme.spaceXL),
                        SizedBox(
                          width: double.infinity,
                          height: AppTheme.buttonHeight,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddFarmScreen()),
                              );
                              if (result != null && result is Farm) {
                                await FarmStorage.saveFarm(result);
                                await _loadFarms();
                              }
                            },
                            icon: const Icon(Icons.edit_location_alt),
                            label: Text('Draw New Farm Boundary', style: AppTheme.button()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final farm = _selectedFarm!;
    final mapCenter = _searchedLocation ?? LatLng(farm.latitude, farm.longitude);
    final areaHectares = (farm.areaAcres / 2.471).toStringAsFixed(2);
    final perimeterEstimate = (farm.areaAcres * 63.6).round();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back_ios,
                        color: AppTheme.textWhite, size: 18),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  Text('Satellite Index', style: AppTheme.h1()),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FARM SELECTOR DROPDOWN
                    Text('SELECT FARM', style: AppTheme.label()),
                    const SizedBox(height: AppTheme.spaceSM),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: AppTheme.cardDecoration(
                        borderColor_: AppTheme.primaryGreen.withOpacity(0.5),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Farm>(
                          value: farm,
                          isExpanded: true,
                          dropdownColor: AppTheme.bgCardLight,
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.unfold_more, color: AppTheme.primaryGreen, size: 20),
                          ),
                          selectedItemBuilder: (context) => _allFarms
                              .map((f) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: AppTheme.iconBoxSM, height: AppTheme.iconBoxSM,
                                            decoration: BoxDecoration(
                                              color: f.healthColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                            ),
                                            child: Icon(Icons.agriculture, color: f.healthColor, size: 18),
                                          ),
                                          const SizedBox(width: AppTheme.spaceMD),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(f.name,
                                                    style: AppTheme.h3(),
                                                    overflow: TextOverflow.ellipsis),
                                                Text('${f.cropType} · ${f.areaAcres} acres',
                                                    style: AppTheme.caption()),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ))
                              .toList(),
                          items: _allFarms
                              .map((f) => DropdownMenuItem<Farm>(
                                    value: f,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10, height: 10,
                                          decoration: BoxDecoration(color: f.healthColor, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: AppTheme.spaceSM),
                                        Expanded(
                                          child: Text(f.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTheme.body().copyWith(color: AppTheme.textWhite)),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (f) {
                            if (f != null) _onFarmSelected(f);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),

                    // LOCATION SEARCH (villages, roads, lakes, colonies etc)
                    Text('SEARCH LOCATION', style: AppTheme.label()),
                    const SizedBox(height: AppTheme.spaceSM),
                    TextField(
                      controller: _searchController,
                      style: AppTheme.body().copyWith(color: AppTheme.textWhite),
                      decoration: InputDecoration(
                        hintText: 'Village, road, lake, colony or lat,lng',
                        hintStyle: AppTheme.bodySmall(),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.accentBlue),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: AppTheme.textGrey, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchResults = [];
                                        _searchedLocation = null;
                                      });
                                    },
                                  )
                                : null,
                        filled: true,
                        fillColor: AppTheme.bgCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          borderSide: const BorderSide(color: AppTheme.borderColor),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: AppTheme.spaceSM),
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: AppTheme.cardDecoration(color: AppTheme.bgCardLight),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, i) {
                            final r = _searchResults[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                _iconForResultType(r.type, r.category),
                                color: AppTheme.accentBlue, size: 18),
                              title: Text(r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTheme.body().copyWith(color: AppTheme.textWhite)),
                              subtitle: r.fullName.isNotEmpty
                                  ? Text(r.fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTheme.caption())
                                  : null,
                              onTap: () => _selectSearchResult(r),
                            );
                          },
                        ),
                      ),
                    if (_searchedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceSM),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 13, color: AppTheme.amber),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text('Showing searched location. Farm boundary below still reflects "${farm.name}".',
                                  style: AppTheme.caption()),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: AppTheme.spaceLG),

                    // GIS Boundary Telemetry Card
                    Container(
                      padding: AppTheme.cardPadding,
                      decoration: AppTheme.cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('GIS BOUNDARY TELEMETRY', style: AppTheme.label()),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
                                ),
                                child: Text('Calculated',
                                    style: AppTheme.caption().copyWith(
                                        color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceMD),
                          Row(
                            children: [
                              _gisStatBox('AREA (ACRES)', farm.areaAcres.toStringAsFixed(1)),
                              _gisStatBox('AREA\n(HECTARES)', areaHectares),
                              _gisStatBox('PERIMETER', '$perimeterEstimate m'),
                              _gisStatBox('SCAN\nZONES', _zoneCount(farm.areaAcres)),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spaceSM),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.grid_view, size: 12, color: AppTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Text(
                                  'Farm will be divided into ${_zoneCount(farm.areaAcres)} zones for detailed scanning. '
                                  'Each zone is analysed independently to detect localised pest/disease hotspots.',
                                  style: AppTheme.caption(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spaceMD),
                          _buildImageryFreshnessRow(),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // Real Sentinel-2/Sentinel-1 scan button — this is
                    // what actually computes NDVI/NDWI for this farm's
                    // drawn boundary and updates its health/water-stress
                    // fields, replacing the defaults set when the farm
                    // was first drawn.
                    SizedBox(
                      width: double.infinity,
                      height: AppTheme.buttonHeight,
                      child: ElevatedButton.icon(
                        onPressed: _scanning ? null : _scanSelectedFarm,
                        icon: _scanning
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.satellite_alt),
                        label: Text(
                          _scanning ? 'Scanning via Sentinel-2...' : 'Scan Real Satellite Data',
                          style: AppTheme.button(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),

                    // TEST button — uses fake data to verify the full
                    // pipeline (backend → database → app → UI) works.
                    // If this updates health score but the real scan
                    // doesn't, the problem is Sentinel credentials only.
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: _scanning ? null : () async {
                          final farm = _selectedFarm;
                          if (farm == null) return;
                          setState(() => _scanning = true);
                          // Sync farm to backend first so it exists in Railway DB
                          await ApiService.syncFarm(farm);
                          final result = await ApiService.testScan(farm.id);
                          setState(() => _scanning = false);
                          if (!mounted) return;
                          if (result['success'] == true) {
                            final updatedFarm = Farm(
                              id: farm.id, name: farm.name,
                              cropType: farm.cropType, cropTypeTelugu: farm.cropTypeTelugu,
                              sowingDate: farm.sowingDate, areaAcres: farm.areaAcres,
                              locationName: farm.locationName, locationNameTelugu: farm.locationNameTelugu,
                              latitude: farm.latitude, longitude: farm.longitude,
                              gpsPolygon: farm.gpsPolygon, polygonPoints: farm.polygonPoints,
                              healthScore: (result['health_score'] as num).toInt(),
                              healthStatus: result['health_status'].toString(),
                              waterStressLevel: result['water_stress_level'].toString(),
                              waterloggingSeverity: result['waterlogging_severity'].toString(),
                              lastScanDate: result['last_scan_date']?.toString() ?? farm.lastScanDate,
                              waterStressConfidence: farm.waterStressConfidence,
                              waterStressArea: farm.waterStressArea,
                              waterStressAreaTelugu: farm.waterStressAreaTelugu,
                              waterloggingArea: farm.waterloggingArea,
                              pestRiskPercent: farm.pestRiskPercent,
                              pestConfidence: farm.pestConfidence,
                              pestHotspots: farm.pestHotspots,
                              diseaseRiskLevel: farm.diseaseRiskLevel,
                              diseaseRiskElevated: farm.diseaseRiskElevated,
                              diseaseRiskNotes: farm.diseaseRiskNotes,
                              healthStatusTelugu: farm.healthStatusTelugu,
                              diseaseRiskNotesTelugu: farm.diseaseRiskNotesTelugu,
                            );
                            await FarmStorage.saveFarm(updatedFarm);
                            setState(() {
                              _selectedFarm = updatedFarm;
                              final idx = _allFarms.indexWhere((f) => f.id == updatedFarm.id);
                              if (idx >= 0) _allFarms[idx] = updatedFarm;
                            });
                            final za = result['zone_analysis'] as Map? ?? {};
                            final hotspots = (za['hotspot_zones'] as List? ?? []);
                            final summary = za['summary']?.toString() ?? '';
                            final weather = result['weather'] as Map? ?? {};
                            if (hotspots.isNotEmpty && summary.isNotEmpty) {
                              _showZoneAlertDialog(summary, hotspots, updatedFarm, za['zones_scanned'] ?? 1, weather);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ TEST scan complete! Health: ${result['health_score']}% · ${za['zones_scanned'] ?? 1} zones analysed. All zones healthy.'),
                                  backgroundColor: AppTheme.accentBlue,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ Test failed: ${result['error']}'), backgroundColor: AppTheme.dangerRed),
                            );
                          }
                        },
                        icon: const Icon(Icons.science, size: 16, color: AppTheme.textGrey),
                        label: Text('Test Pipeline (Fake Data)', style: AppTheme.bodySmall().copyWith(color: AppTheme.textGrey)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),

                    Text('TOGGLE SATELLITE BAND OVERLAYS', style: AppTheme.label()),
                    const SizedBox(height: AppTheme.spaceMD),

                    Row(
                      children: _bands.map((band) {
                        final name = band['name'] as String;
                        final color = band['color'] as Color;
                        final selected = name == _selectedBand;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedBand = name),
                            child: Container(
                              height: 64,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: selected ? color.withOpacity(0.2) : AppTheme.bgCard,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                border: Border.all(color: selected ? color : AppTheme.borderColor),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(band['icon'] as IconData,
                                      color: selected ? color : AppTheme.textGrey, size: 18),
                                  const SizedBox(height: 4),
                                  Text(name,
                                      style: AppTheme.caption().copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: selected ? color : AppTheme.textGrey)),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    Container(
                      padding: AppTheme.cardPadding,
                      decoration: AppTheme.cardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedBand == 'NDVI'
                              ? 'Normalized Difference Vegetation Index'
                              : _selectedBand == 'Water'
                                  ? 'Water Stress Index'
                                  : _selectedBand == 'Pest'
                                      ? 'Pest Colonization Risk'
                                      : _selectedBand == 'Disease'
                                          ? 'Disease Threat Index'
                                          : 'Flood Detection Layer',
                              style: AppTheme.h3().copyWith(color: _bandColor)),
                          const SizedBox(height: AppTheme.spaceXS),
                          Text(_bandDescriptions[_selectedBand] ?? '', style: AppTheme.bodySmall()),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // Map
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      child: SizedBox(
                        height: 260,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: mapCenter,
                            initialZoom: 14,
                            // Google Maps supports zoom up to 20-21 for
                            // most areas including rural India. Setting
                            // 20 here allows the full zoom range.
                            maxZoom: 20,
                          ),
                          children: [
                            // Google Maps Hybrid — satellite imagery with
                            // road names, village names, and place labels
                            // all in one tile layer. Sharper and more
                            // recent than Esri for Indian farmland.
                            TileLayer(
                              urlTemplate: MapConfig.googleHybridTemplate,
                              userAgentPackageName: 'com.farmigrow.ai',
                              maxZoom: 20,
                              maxNativeZoom: 20,
                              errorTileCallback: (tile, error, stackTrace) {
                                // Falls through to nothing — Google tiles
                                // are extremely reliable globally.
                              },
                            ),
                            PolygonLayer(
                              polygons: [
                                ..._allFarms.where((f) => f.id != farm.id).map((f) => Polygon(
                                      points: _polygonForFarm(f),
                                      color: Colors.white.withOpacity(0.08),
                                      borderColor: Colors.white.withOpacity(0.3),
                                      borderStrokeWidth: 1,
                                    )),
                                Polygon(
                                  points: _polygonForFarm(farm),
                                  color: _bandColor.withOpacity(0.35),
                                  borderColor: _bandColor,
                                  borderStrokeWidth: 2.5,
                                ),
                              ],
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(farm.latitude, farm.longitude),
                                  width: 120,
                                  height: 24,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _bandColor.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(farm.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                if (_searchedLocation != null)
                                  Marker(
                                    point: _searchedLocation!,
                                    width: 26, height: 26,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentBlue,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(color: AppTheme.accentBlue.withOpacity(0.5), blurRadius: 8, spreadRadius: 2),
                                        ],
                                      ),
                                      child: const Icon(Icons.place, color: Colors.white, size: 14),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // Draw New Farm Boundary button
                    SizedBox(
                      width: double.infinity,
                      height: AppTheme.buttonHeight,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AddFarmScreen()),
                          );
                          if (result != null && result is Farm) {
                            await FarmStorage.saveFarm(result);
                            await _loadFarms();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ ${result.name} saved successfully!'),
                                  backgroundColor: AppTheme.primaryGreen,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.edit_location_alt, color: AppTheme.primaryGreen),
                        label: Text('Draw New Farm Boundary', style: AppTheme.button().copyWith(color: AppTheme.primaryGreen)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageryFreshnessRow() {
    if (_loadingMetadata) {
      return Row(
        children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textGrey),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Text('Checking imagery source...', style: AppTheme.caption()),
        ],
      );
    }

    final meta = _imageryMetadata;
    final hasInfo = meta != null && meta.found && (meta.captureDate != null || meta.source != null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        children: [
          Icon(hasInfo ? Icons.satellite_alt : Icons.info_outline,
              size: 13, color: AppTheme.textGrey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasInfo
                  ? 'Imagery: ${meta!.source ?? "Esri World Imagery"}'
                      '${meta.captureDate != null ? " · captured ${meta.captureDate}" : ""}'
                  : 'Showing the latest available satellite imagery for this area. '
                      'Free imagery providers update on their own schedule (weeks to '
                      'months), not in real time.',
              style: AppTheme.caption(),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns how many zones the farm will be split into for scanning
  String _zoneCount(double acres) {
    if (acres < 5) return '4';
    if (acres <= 20) return '9';
    return '16';
  }

  Widget _gisStatBox(String label, String value) {
    return Expanded(
      child: Container(
        height: 64,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.bgCardLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.caption().copyWith(fontSize: 8)),
            Text(value, style: AppTheme.h2()),
          ],
        ),
      ),
    );
  }
}
