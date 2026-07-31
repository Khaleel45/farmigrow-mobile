import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/farm_storage.dart';
import 'package:farmigrow_ai/services/pond_storage.dart';
import 'package:farmigrow_ai/services/api_service.dart';
import 'package:farmigrow_ai/screens/leaf_doctor_screen.dart';
import 'package:farmigrow_ai/screens/agri_ai_screen.dart';
import 'package:farmigrow_ai/screens/satellite_screen.dart';
import 'package:farmigrow_ai/screens/alerts_screen.dart';
import 'package:farmigrow_ai/screens/farm_detail_screen.dart';
import 'package:farmigrow_ai/screens/add_pond_screen.dart';
import 'dart:math' as math;

class DashboardScreen extends StatefulWidget {
  final bool isAgri;
  const DashboardScreen({super.key, required this.isAgri});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedFarmIndex = 0;
  bool _telugu = false;
  List<Farm> _userFarms = [];
  List<AquaPond> _userPonds = [];
  // Cache weather per farm to avoid re-fetching on every rebuild
  final Map<String, Map<String, dynamic>> _weatherCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserFarms();
    // Pre-populate weather with seasonal fallback immediately
    _initWeatherFallback();
  }

  void _initWeatherFallback() {
    final month = DateTime.now().month;
    final isMonsoon = month >= 6 && month <= 9;
    // Store a default under a special key used before farms load
    _weatherCache['_default'] = {
      'available': false,
      'temperature': isMonsoon ? '29.0' : '33.0',
      'humidity': isMonsoon ? '82.0' : '52.0',
      'rainfall_today': isMonsoon ? '8.5' : '0.0',
      'rainfall_7d': isMonsoon ? '45.0' : '2.0',
      'wind_speed': '12.0',
      'et0': isMonsoon ? '3.8' : '5.2',
      'leaf_wetness_hours': isMonsoon ? 8 : 0,
    };
  }

  Future<void> _prefetchWeather(String id, double lat, double lng) async {
    if (_weatherCache.containsKey(id) &&
        _weatherCache[id]!['available'] == true) return;
    // Set fallback first
    if (!_weatherCache.containsKey(id)) {
      _weatherCache[id] = _weatherCache['_default']!;
    }
    if (lat == 0 || lng == 0) return;
    // Fake farm object just to pass lat/lng to _fetchWeather
    final proxy = Farm(
      id: id, name: '', cropType: '', sowingDate: '',
      areaAcres: 0, locationName: '', healthScore: 0,
      healthStatus: '', latitude: lat, longitude: lng,
      waterStressLevel: 'Low', lastScanDate: '',
    );
    final data = await _fetchWeather(proxy);
    if (mounted) setState(() => _weatherCache[id] = data);
  }

  Future<void> _loadUserFarms() async {
    final localFarms = await FarmStorage.getUserFarms();
    final localPonds = await PondStorage.getUserPonds();
    setState(() {
      _userFarms = localFarms;
      _userPonds = localPonds;
    });
    // Background cloud sync
    final synced = await FarmStorage.syncFromCloud();
    final syncedPonds = await PondStorage.syncFromCloud();
    if (mounted) {
      setState(() {
        if (synced.length != localFarms.length) _userFarms = synced;
        if (syncedPonds.length != localPonds.length) _userPonds = syncedPonds;
      });
      // Prefetch weather for selected farm and pond in background
      final farm = _userFarms.isNotEmpty ? _userFarms[0] : null;
      if (farm != null) _prefetchWeather(farm.id, farm.latitude, farm.longitude);
      final pond = _userPonds.isNotEmpty ? _userPonds[0] : null;
      if (pond != null) _prefetchWeather(pond.id, pond.latitude, pond.longitude);
    }
  }

  List<Farm> get _allFarms => _userFarms;
  Farm? get _selectedFarm =>
      _allFarms.isEmpty ? null : _allFarms[_selectedFarmIndex.clamp(0, _allFarms.length - 1)];

  @override
  Widget build(BuildContext context) {
    if (widget.isAgri) return _buildAgriDashboard();
    return _buildAquaDashboard();
  }

  Widget _buildAgriDashboard() {
    final farm = _selectedFarm;

    if (farm == null) {
      return RefreshIndicator(
        onRefresh: _loadUserFarms,
        color: AppTheme.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceXXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.agriculture, color: AppTheme.primaryGreen, size: 40),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                    Text('No farms added yet', style: AppTheme.h1()),
                    const SizedBox(height: AppTheme.spaceSM),
                    Text(
                      'Go to the Satellite tab and tap "Draw New Farm Boundary"\nto add your first farm and start tracking it.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserFarms,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildFarmSelector(farm),
            const SizedBox(height: 16),
            _buildHealthScoreCard(farm),
            const SizedBox(height: 12),
            _buildQuickActions(farm),
            const SizedBox(height: 16),
            _buildSectionHeader('SECTOR DIAGNOSTIC CARDS', 'Live Telemetry'),
            const SizedBox(height: 10),
            _buildDiagnosticGrid(farm),
            const SizedBox(height: 12),
            _buildWeatherCard(farm),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmSelector(Farm farm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Hello Farmer 👋', style: AppTheme.body().copyWith(color: AppTheme.textGrey, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _telugu = !_telugu),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Text(_telugu ? 'English' : 'తెలుగు',
                    style: AppTheme.bodySmall().copyWith(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSM),
        // Tap to open a dropdown list of farms instead of side-scroll chips
        GestureDetector(
          onTap: () => _showFarmPicker(),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceSM),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: AppTheme.iconBoxSM, height: AppTheme.iconBoxSM,
                  decoration: BoxDecoration(
                    color: farm.healthColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Icon(Icons.agriculture, color: farm.healthColor, size: 18),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farm.name, style: AppTheme.h1().copyWith(fontSize: 18), overflow: TextOverflow.ellipsis),
                      Text('${farm.cropType} · ${farm.areaAcres} acres', style: AppTheme.bodySmall()),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_allFarms.length} farms', style: AppTheme.caption().copyWith(color: AppTheme.primaryGreen)),
                      const SizedBox(width: 2),
                      const Icon(Icons.unfold_more, size: 14, color: AppTheme.primaryGreen),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFarmPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: AppTheme.spaceMD),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Select Farm', style: AppTheme.h1()),
                  const Spacer(),
                  Text('${_allFarms.length} total', style: AppTheme.bodySmall()),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _allFarms.length,
                itemBuilder: (context, i) {
                  final f = _allFarms[i];
                  final selected = i == _selectedFarmIndex;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFarmIndex = i);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                      padding: AppTheme.cardPaddingSmall,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryGreen.withOpacity(0.1) : AppTheme.bgCardLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        border: Border.all(color: selected ? AppTheme.primaryGreen : AppTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: AppTheme.iconBoxMD, height: AppTheme.iconBoxMD,
                            decoration: BoxDecoration(
                              color: f.healthColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: Icon(Icons.agriculture, color: f.healthColor, size: 20),
                          ),
                          const SizedBox(width: AppTheme.spaceMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.name, style: AppTheme.h3()),
                                Text('${f.cropType} · ${f.areaAcres} acres · ${f.locationName}',
                                    style: AppTheme.caption(), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${f.healthScore}%', style: AppTheme.statValue(color: f.healthColor)),
                              if (selected) const Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthScoreCard(Farm farm) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FarmDetailScreen(farm: farm)),
      ).then((_) => _loadUserFarms()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('FARM HEALTH SCORE',
                    style: GoogleFonts.poppins(
                        color: AppTheme.textGrey,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textGrey),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${farm.healthScore}',
                            style: GoogleFonts.poppins(
                                color: AppTheme.textWhite, fontSize: 52, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: '/100',
                            style: GoogleFonts.poppins(
                                color: AppTheme.textGrey, fontSize: 18, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: farm.healthColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: farm.healthColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        _telugu && farm.healthStatusTelugu.isNotEmpty
                            ? farm.healthStatusTelugu
                            : farm.healthStatus,
                        style: GoogleFonts.poppins(
                            color: farm.healthColor, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.satellite_alt, size: 13, color: AppTheme.textGrey),
                        const SizedBox(width: 4),
                        Text('Last Satellite Scan ',
                            style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 11)),
                        Text(farm.lastScanDate,
                            style: GoogleFonts.poppins(
                                color: AppTheme.textWhite, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 100, height: 100,
                  child: CustomPaint(
                    painter: _CircularScorePainter(
                        score: farm.healthScore / 100, color: farm.healthColor),
                    child: Center(
                      child: Text('${farm.healthScore}%',
                          style: GoogleFonts.poppins(
                              color: farm.healthColor, fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(Farm farm) {
    final actions = [
      {
        'icon': Icons.document_scanner,
        'label': 'Upload\nDoctor',
        'color': Colors.green,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const LeafDoctorScreen()));
        },
      },
      {
        'icon': Icons.smart_toy,
        'label': 'Ask AI\nChat',
        'color': Colors.blue,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AgriAIScreen()));
        },
      },
      {
        'icon': Icons.satellite_alt,
        'label': 'Satellite\nMap',
        'color': Colors.orange,
        'onTap': () {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => SatelliteScreen(farmName: farm.name)));
        },
      },
      {
        'icon': Icons.notifications_active,
        'label': 'Smart\nAlerts',
        'color': Colors.red,
        'onTap': () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
        },
      },
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: actions.map((a) {
        final color = a['color'] as Color;
        return GestureDetector(
          onTap: a['onTap'] as VoidCallback,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(a['icon'] as IconData, color: color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(a['label'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textGrey, height: 1.3)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Text(title,
            style: GoogleFonts.poppins(
                color: AppTheme.textGrey, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.w600)),
        const Spacer(),
        Container(
          width: 6, height: 6,
          decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(subtitle,
            style: GoogleFonts.poppins(
                color: AppTheme.primaryGreen, fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDiagnosticGrid(Farm farm) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _diagCard(
              icon: Icons.eco,
              title: _telugu ? 'పంట ఆరోగ్యం' : 'Farm Health',
              value: 'High Vigor\nIndex',
              valueColor: AppTheme.primaryGreen,
              subtitle: 'NDVI scale: 0.74',
              fullDesc: 'NDVI (Normalized Difference Vegetation Index) measures plant chlorophyll activity from satellite imagery. Current reading of 0.74 indicates strong vegetative vigor across most of the field. Areas above 0.7 are considered excellent for active growth stage crops.',
              recommendation: 'Continue current irrigation and fertilization schedule. No immediate action needed.',
            )),
            const SizedBox(width: 10),
            Expanded(child: _diagCard(
              icon: Icons.water_drop,
              title: _telugu ? 'నీటి ప్రమాదం' : 'Water Risk',
              value: farm.waterStressLevel == 'Low' ? 'Nominal' :
                     farm.waterStressLevel == 'High' ? 'Critical' : 'Moderate',
              valueColor: farm.waterStressLevel == 'Low' ? AppTheme.primaryGreen :
                          farm.waterStressLevel == 'High' ? AppTheme.dangerRed : AppTheme.amber,
              subtitle: 'NDWI scale: 0.19',
              fullDesc: 'NDWI (Normalized Difference Water Index) tracks canopy water content using satellite SWIR bands. ${farm.waterStressArea.isNotEmpty ? "Affected area: ${farm.waterStressArea}." : ""} Current confidence: ${farm.waterStressConfidence}%.',
              recommendation: farm.waterStressLevel == 'High'
                  ? 'Irrigate within 48 hours to prevent yield loss.'
                  : 'Water levels are within acceptable range. Monitor weekly.',
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _diagCard(
              icon: Icons.bug_report,
              title: _telugu ? 'పురుగు ప్రమాదం' : 'Pest Risk',
              value: '${farm.pestRiskPercent}% (${farm.pestRiskPercent < 20 ? "Low" : farm.pestRiskPercent < 40 ? "Moderate" : "High"})',
              valueColor: farm.pestRiskPercent < 20 ? AppTheme.primaryGreen :
                          farm.pestRiskPercent < 40 ? AppTheme.amber : AppTheme.dangerRed,
              subtitle: 'Confidence: ${farm.pestConfidence}%',
              fullDesc: 'AI vision model analyzes leaf reflectance patterns and historical outbreak data. ${farm.pestHotspots.isNotEmpty ? "Hotspots detected: ${farm.pestHotspots.join(", ")}." : "No active hotspots detected."}',
              recommendation: farm.pestRiskPercent > 30
                  ? 'Inspect hotspot areas closely. Consider preventive spray.'
                  : 'Risk is low. Continue routine field inspection.',
            )),
            const SizedBox(width: 10),
            Expanded(child: _diagCard(
              icon: Icons.coronavirus,
              title: _telugu ? 'తెగులు ప్రమాదం' : 'Disease Risk',
              value: farm.diseaseRiskLevel,
              valueColor: farm.diseaseRiskLevel == 'Low' ? AppTheme.primaryGreen :
                          farm.diseaseRiskLevel == 'Moderate' ? AppTheme.amber : AppTheme.dangerRed,
              subtitle: farm.diseaseRiskNotes.isNotEmpty
                  ? farm.diseaseRiskNotes.split('.')[0]
                  : 'Conditions are dry...',
              fullDesc: farm.diseaseRiskNotes.isNotEmpty ? farm.diseaseRiskNotes : 'Conditions monitored for fungal/bacterial spread based on humidity, temperature and rainfall patterns.',
              recommendation: farm.diseaseRiskElevated
                  ? 'Apply preventive fungicide. Monitor leaf surfaces for early symptoms.'
                  : 'Conditions are not favorable for disease spread currently.',
            )),
          ],
        ),
      ],
    );
  }

  Widget _diagCard({
    required IconData icon,
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
    required String fullDesc,
    required String recommendation,
  }) {
    return GestureDetector(
      onTap: () => _showDiagnosticDetail(icon, title, value, valueColor, fullDesc, recommendation),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.textGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.poppins(
                          color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.w500)),
                ),
                const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.textGrey),
              ],
            ),
            Text(value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    color: valueColor, fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),
            Text(subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  void _showDiagnosticDetail(IconData icon, String title, String value, Color color, String desc, String recommendation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.poppins(color: AppTheme.textWhite, fontWeight: FontWeight.w700, fontSize: 16)),
                      Text(value, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Analysis', style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(desc, style: GoogleFonts.poppins(color: AppTheme.textWhite, fontSize: 13, height: 1.6)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, color: AppTheme.amber, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(recommendation,
                        style: GoogleFonts.poppins(color: AppTheme.textWhite, fontSize: 13, height: 1.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildWeatherCard(Farm farm) {
    final w = _weatherCache[farm.id] ?? _weatherCache['_default'];
    if (w == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.wb_sunny, size: 16, color: AppTheme.amber),
            const SizedBox(width: 6),
            Text('Live Weather', style: GoogleFonts.poppins(
                color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(w['available'] == true ? '🟢 Live' : '🟡 Seasonal estimate',
                style: GoogleFonts.poppins(fontSize: 10, color: AppTheme.textGrey)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _weatherStat('Temp', '${w['temperature']}°C', Colors.orange),
            _weatherStat('Humidity', '${w['humidity']}%', Colors.blue),
            _weatherStat('Rain 7d', '${w['rainfall_7d']}mm', AppTheme.accentBlue),
            _weatherStat('Wind', '${w['wind_speed']}km/h', AppTheme.textGrey),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _weatherStat('Rain Today', '${w['rainfall_today']}mm', AppTheme.accentBlue),
            _weatherStat('ET0', '${w['et0']}mm', Colors.green),
            _weatherStat('Leaf Wet', '${w['leaf_wetness_hours']}h', Colors.teal),
            _weatherStat('UV Risk',
                (double.tryParse(w['temperature'].toString()) ?? 30) > 35 ? 'High' : 'Moderate',
                AppTheme.amber),
          ]),
        ],
      ),
    );
  }


  String _uvRisk(dynamic temp, dynamic humidity) {
    if (temp == null) return '--';
    final t = (temp as num).toDouble();
    final h = (humidity as num? ?? 65).toDouble();
    if (t > 38) return 'Very High';
    if (t > 33) return 'High';
    if (t > 28) return 'Moderate';
    return 'Low';
  }

  String _weatherAdvisory(Map<String, dynamic>? w) {
    if (w == null) return 'Fetching weather...';
    final temp = (w['temperature'] as num?)?.toDouble() ?? 30;
    final humidity = (w['humidity'] as num?)?.toDouble() ?? 65;
    final rain = (w['rainfall_7d'] as num?)?.toDouble() ?? 0;
    final lw = (w['leaf_wetness_hours'] as num?)?.toInt() ?? 0;

    if (lw > 8 && humidity > 85) return '⚠️ High leaf wetness — disease pressure elevated. Avoid spraying.';
    if (temp > 38) return '🌡️ Extreme heat — irrigate early morning or evening only.';
    if (rain > 50) return '🌧️ Heavy rainfall week — check drainage, delay fertiliser.';
    if (humidity < 40) return '💨 Low humidity + dry conditions — increase irrigation frequency.';
    if (rain < 5 && temp > 33) return '☀️ Hot and dry — monitor water stress daily.';
    return '✅ Weather conditions are suitable for normal field operations.';
  }

  Future<Map<String, dynamic>> _fetchWeather(Farm farm) async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${farm.latitude}&longitude=${farm.longitude}'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,'
        'wind_speed_10m_max,et0_fao_evapotranspiration'
        '&hourly=relative_humidity_2m,precipitation'
        '&timezone=Asia%2FKolkata'
        '&forecast_days=1'
      )).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'] ?? {};
        final hourly = data['hourly'] ?? {};

        final tempsMax = (daily['temperature_2m_max'] as List?) ?? [];
        final tempsMin = (daily['temperature_2m_min'] as List?) ?? [];
        final rainfall = (daily['precipitation_sum'] as List?) ?? [];
        final wind = (daily['wind_speed_10m_max'] as List?) ?? [];
        final et0 = (daily['et0_fao_evapotranspiration'] as List?) ?? [];
        final hourlyHumidity = (hourly['relative_humidity_2m'] as List?) ?? [];
        final hourlyRain = (hourly['precipitation'] as List?) ?? [];

        double temp = tempsMax.isNotEmpty && tempsMin.isNotEmpty
            ? ((tempsMax[0] as num) + (tempsMin[0] as num)) / 2
            : 30.0;
        double humidity = hourlyHumidity.isNotEmpty
            ? (hourlyHumidity.take(24).whereType<num>().fold(0.0, (a, b) => a + b)) /
              hourlyHumidity.take(24).whereType<num>().length
            : 65.0;
        int leafWetHours = 0;
        for (int i = 0; i < hourlyHumidity.length && i < 24; i++) {
          final h = hourlyHumidity[i] as num? ?? 0;
          final r = hourlyRain[i] as num? ?? 0;
          if (h > 80 || r > 0.1) leafWetHours++;
        }

        return {
          'available': true,
          'temperature': temp.toStringAsFixed(1),
          'humidity': humidity.toStringAsFixed(1),
          'rainfall_today': rainfall.isNotEmpty ? (rainfall[0] as num).toStringAsFixed(1) : '0.0',
          'rainfall_7d': (rainfall.whereType<num>().fold(0.0, (a, b) => a + b)).toStringAsFixed(1),
          'wind_speed': wind.isNotEmpty ? (wind[0] as num).toStringAsFixed(1) : '--',
          'et0': et0.isNotEmpty ? (et0[0] as num).toStringAsFixed(2) : '--',
          'leaf_wetness_hours': leafWetHours,
        };
      }
    } catch (e) {
      print('Weather fetch error: $e');
    }

    // Seasonal fallback for India
    final month = DateTime.now().month;
    final isMonsoon = month >= 6 && month <= 9;
    return {
      'available': false,
      'temperature': isMonsoon ? '29.0' : '33.0',
      'humidity': isMonsoon ? '82.0' : '52.0',
      'rainfall_today': isMonsoon ? '8.5' : '0.0',
      'rainfall_7d': isMonsoon ? '45.0' : '2.0',
      'wind_speed': '12.0',
      'et0': isMonsoon ? '3.8' : '5.2',
      'leaf_wetness_hours': isMonsoon ? 8 : 0,
    };
  }

  Widget _weatherStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 9)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.poppins(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard(Farm farm) {
    final insight = _telugu
        ? 'పొడి వాతావరణం గుర్తించబడింది. వచ్చే 48 గంటల్లో నీటి తడి ఇవ్వండి.'
        : 'Dry spell identified. Monitor soil cracking metrics and irrigate northwest rows within 48 hours.';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgriAIScreen())),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2A1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb, color: AppTheme.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Farmer Insight:',
                      style: GoogleFonts.poppins(
                          color: AppTheme.amber, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(insight, style: GoogleFonts.poppins(color: AppTheme.textWhite, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Selected pond index (mirrors _selectedFarmIndex for Agri)
  int _selectedPondIndex = 0;
  AquaPond? get _selectedPond => _userPonds.isEmpty ? null
      : _userPonds[_selectedPondIndex.clamp(0, _userPonds.length - 1)];

  Widget _buildAquaDashboard() {
    // Show pond picker sheet - mirrors _showFarmPicker in Agri
    void showPondPicker() {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.bgCard,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('Select Pond', style: AppTheme.h1()),
                    const Spacer(),
                    Text('${_userPonds.length} total', style: AppTheme.bodySmall()),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: _userPonds.length,
                  itemBuilder: (context, i) {
                    final p = _userPonds[i];
                    final selected = i == _selectedPondIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedPondIndex = i);
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: AppTheme.cardPaddingSmall,
                        decoration: BoxDecoration(
                          color: selected ? Colors.blue.withOpacity(0.1) : AppTheme.bgCardLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(color: selected ? Colors.blue : AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.water, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: AppTheme.h3()),
                                Text('${p.species} · ${p.areaAcres} acres',
                                    style: AppTheme.caption()),
                              ],
                            )),
                            if (selected) const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pond = _selectedPond;

    return RefreshIndicator(
      onRefresh: _loadUserFarms,
      color: AppTheme.primaryGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Pond selector - same style as farm selector in Agri
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: pond != null ? showPondPicker : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: AppTheme.cardDecoration(),
                      child: Row(
                        children: [
                          const Icon(Icons.water, color: Colors.blue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pond?.name ?? 'No ponds yet',
                                  style: AppTheme.h1().copyWith(fontSize: 16)),
                              Text(pond != null
                                  ? '${pond.species} · ${pond.areaAcres} acres'
                                  : 'Tap + Add Pond to get started',
                                  style: AppTheme.bodySmall()),
                            ],
                          )),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('${_userPonds.length} ponds',
                                  style: AppTheme.caption().copyWith(color: Colors.blue)),
                              const SizedBox(width: 2),
                              const Icon(Icons.unfold_more, size: 14, color: Colors.blue),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const AddPondScreen()));
                    if (result != null && result is AquaPond) {
                      await PondStorage.savePond(result);
                      await _loadUserFarms();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  child: const Icon(Icons.add, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (pond == null)
              Container(
                padding: AppTheme.cardPadding,
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  children: [
                    const Icon(Icons.water, color: Colors.blue, size: 48),
                    const SizedBox(height: 12),
                    Text('No ponds added yet', style: AppTheme.h2()),
                    const SizedBox(height: 4),
                    Text('Tap + to add your first pond. Once added, satellite + weather data will track water quality, algae bloom risk, dissolved oxygen, and mortality risk.',
                        textAlign: TextAlign.center, style: AppTheme.bodySmall()),
                  ],
                ),
              )
            else ...[
              // DO Score card - same style as Farm Health Score card
              _buildPondScoreCard(pond),
              const SizedBox(height: 12),
              // Quick actions same as Agri
              _buildPondQuickActions(pond),
              const SizedBox(height: 16),
              _buildSectionHeader('POND DIAGNOSTIC CARDS', 'Live Monitoring'),
              const SizedBox(height: 10),
              _buildPondDiagnosticGrid(pond),
              const SizedBox(height: 12),
              _buildWeatherCardForPond(pond),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }


  // ─── POND DASHBOARD WIDGETS (mirror of Agri widgets) ─────────────────────

  /// Mirrors _buildHealthScoreCard — shows DO as the primary metric
  Widget _buildPondScoreCard(AquaPond pond) {
    final doScore = ((pond.dissolvedOxygen / 12.0) * 100).clamp(0.0, 100.0);
    final doColor = pond.dissolvedOxygen < 4 ? AppTheme.dangerRed
        : pond.dissolvedOxygen < 6 ? AppTheme.amber
        : AppTheme.primaryGreen;
    final mortalityColor = pond.mortalityRisk == 'High' ? AppTheme.dangerRed
        : pond.mortalityRisk == 'Moderate' ? AppTheme.amber : AppTheme.primaryGreen;

    return Container(
      padding: AppTheme.cardPadding,
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          // DO gauge - mirrors health score gauge
          SizedBox(
            width: 90, height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90, height: 90,
                  child: CircularProgressIndicator(
                    value: doScore / 100,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation(doColor),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${pond.dissolvedOxygen}',
                      style: GoogleFonts.poppins(color: doColor,
                          fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('mg/L', style: AppTheme.caption()),
                  Text('O₂', style: AppTheme.caption()),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pond.mortalityRisk == 'High' ? 'Critical Risk'
                    : pond.mortalityRisk == 'Moderate' ? 'Needs Attention' : 'Healthy',
                    style: GoogleFonts.poppins(color: mortalityColor,
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text('Last scan: ${pond.lastScanDate}', style: AppTheme.caption()),
                const SizedBox(height: 8),
                Row(children: [
                  _pondStat('Water', '${pond.waterSpreadPercent}%', Colors.blue),
                  _pondStat('Temp', '${pond.temperatureCelsius}°C',
                      pond.temperatureCelsius > 32 ? AppTheme.dangerRed : AppTheme.primaryGreen),
                  _pondStat('pH', '${pond.phLevel}',
                      (pond.phLevel < 6.5 || pond.phLevel > 8.5) ? AppTheme.amber : AppTheme.primaryGreen),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mirrors _buildQuickActions for ponds
  Widget _buildPondQuickActions(AquaPond pond) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _scanPond(pond),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: Colors.blue.withOpacity(0.4)),
              ),
              child: Column(children: [
                const Icon(Icons.satellite_alt, color: Colors.blue, size: 20),
                const SizedBox(height: 4),
                Text('Scan Pond', style: AppTheme.caption().copyWith(color: Colors.blue)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => _showPondDetail(pond),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(children: [
                const Icon(Icons.bar_chart, color: AppTheme.textGrey, size: 20),
                const SizedBox(height: 4),
                Text('Full Report', style: AppTheme.caption()),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.bgCard,
                  title: Text('Delete Pond?', style: AppTheme.h2()),
                  content: Text('This will remove ${pond.name} permanently.',
                      style: AppTheme.body()),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: AppTheme.body().copyWith(color: AppTheme.textGrey))),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: Text('Delete', style: AppTheme.body().copyWith(color: AppTheme.dangerRed))),
                  ],
                ),
              );
              if (confirm == true) {
                await PondStorage.deletePond(pond.id);
                setState(() {
                  _selectedPondIndex = 0;
                });
                await _loadUserFarms();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
              ),
              child: Column(children: [
                const Icon(Icons.delete_outline, color: AppTheme.dangerRed, size: 20),
                const SizedBox(height: 4),
                Text('Remove', style: AppTheme.caption().copyWith(color: AppTheme.dangerRed)),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  /// Mirrors _buildDiagnosticGrid for pond parameters
  Widget _buildPondDiagnosticGrid(AquaPond pond) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _diagCard(
              icon: Icons.water,
              title: 'Dissolved O₂',
              value: '${pond.dissolvedOxygen} mg/L',
              valueColor: pond.dissolvedOxygen < 4 ? AppTheme.dangerRed
                  : pond.dissolvedOxygen < 6 ? AppTheme.amber : AppTheme.primaryGreen,
              subtitle: 'Normal: 6-9 mg/L',
              fullDesc: 'Dissolved oxygen is the most critical parameter for aquaculture. '
                  'Below 4 mg/L causes stress and mortality. '
                  'Above 9 mg/L indicates algae supersaturation.',
              recommendation: pond.dissolvedOxygen < 4
                  ? 'Critical: Run aerators immediately. Check for algae bloom.'
                  : pond.dissolvedOxygen < 6
                      ? 'Low DO: Increase aeration, reduce feeding, check for overcrowding.'
                      : 'DO levels are healthy. Continue normal management.',
            )),
            const SizedBox(width: 10),
            Expanded(child: _diagCard(
              icon: Icons.thermostat,
              title: 'Water Temp',
              value: '${pond.temperatureCelsius}°C',
              valueColor: pond.temperatureCelsius > 35 ? AppTheme.dangerRed
                  : pond.temperatureCelsius > 30 ? AppTheme.amber : AppTheme.primaryGreen,
              subtitle: 'Heat: ${pond.heatStressRisk}',
              fullDesc: 'Water temperature affects metabolism, oxygen solubility, and disease susceptibility. '
                  'Optimal range varies by species: Fish 25-30°C, Shrimp 26-30°C.',
              recommendation: pond.heatStressRisk == 'High'
                  ? 'Increase water exchange, reduce feeding by 30%, add shade netting.'
                  : 'Temperature within acceptable range for ${pond.species}.',
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _diagCard(
              icon: Icons.grass,
              title: 'Algae Risk',
              value: pond.algaeBloomRisk,
              valueColor: pond.algaeBloomRisk == 'High' ? AppTheme.dangerRed
                  : pond.algaeBloomRisk == 'Moderate' ? AppTheme.amber : AppTheme.primaryGreen,
              subtitle: 'pH: ${pond.phLevel}',
              fullDesc: 'Algae blooms reduce oxygen at night and produce toxins. '
                  'Satellite detects greenish water surface. '
                  'High pH (>8.5) confirms active algae photosynthesis.',
              recommendation: pond.algaeBloomRisk == 'High'
                  ? 'Apply algaecide. Increase water exchange. Monitor DO at dawn.'
                  : pond.algaeBloomRisk == 'Moderate'
                      ? 'Reduce fertilizer input. Improve water circulation.'
                      : 'Algae levels are normal. Maintain current management.',
            )),
            const SizedBox(width: 10),
            Expanded(child: _diagCard(
              icon: Icons.warning_amber,
              title: 'Mortality Risk',
              value: pond.mortalityRisk,
              valueColor: pond.mortalityRisk == 'High' ? AppTheme.dangerRed
                  : pond.mortalityRisk == 'Moderate' ? AppTheme.amber : AppTheme.primaryGreen,
              subtitle: '${pond.species} · ${pond.waterTrend}',
              fullDesc: 'Combined risk score based on dissolved oxygen, temperature, algae levels, and pH. '
                  'High mortality risk requires immediate intervention.',
              recommendation: pond.mortalityRisk == 'High'
                  ? 'Emergency: Check pond immediately. Run aerators. Reduce stocking density if possible.'
                  : pond.mortalityRisk == 'Moderate'
                      ? 'Monitor closely. Increase aeration and reduce feeding.'
                      : 'Pond conditions are good for ${pond.species} health.',
            )),
          ],
        ),
      ],
    );
  }

  /// Mirrors _buildWeatherCard but uses pond lat/lng
  Widget _buildWeatherCardForPond(AquaPond pond) {
    // Ensure weather is being fetched for this pond
    if (!_weatherCache.containsKey(pond.id)) {
      Future.microtask(() => _prefetchWeather(pond.id, pond.latitude, pond.longitude));
    }
    final farmProxy = Farm(
      id: pond.id, name: pond.name, cropType: pond.species,
      sowingDate: pond.stockingDate, areaAcres: pond.areaAcres,
      locationName: pond.locationName, healthScore: 70, healthStatus: 'N/A',
      latitude: pond.latitude, longitude: pond.longitude,
      waterStressLevel: 'Low', lastScanDate: pond.lastScanDate,
    );
    return _buildWeatherCard(farmProxy);
  }

  Widget _buildPondCard(AquaPond pond) {
    final mortalityColor = pond.mortalityRisk == 'High'
        ? AppTheme.dangerRed
        : pond.mortalityRisk == 'Moderate' ? AppTheme.amber : AppTheme.primaryGreen;

    // Convert dissolved oxygen to a 0-100 score for the gauge
    final doScore = ((pond.dissolvedOxygen / 12.0) * 100).clamp(0, 100).toInt();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — matches farm health card style
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.water, color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pond.name,
                          style: GoogleFonts.poppins(color: AppTheme.textWhite,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('${pond.species} · ${pond.areaAcres} acres · ${pond.waterTrend}',
                          style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: mortalityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: mortalityColor.withOpacity(0.4)),
                  ),
                  child: Text('${pond.mortalityRisk} Risk',
                      style: GoogleFonts.poppins(color: mortalityColor,
                          fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // DO gauge + key metrics — mirrors agri health score layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Circular DO gauge (like health score gauge in agri)
                SizedBox(
                  width: 90, height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90, height: 90,
                        child: CircularProgressIndicator(
                          value: doScore / 100,
                          strokeWidth: 8,
                          backgroundColor: AppTheme.borderColor,
                          valueColor: AlwaysStoppedAnimation(
                            pond.dissolvedOxygen < 4 ? AppTheme.dangerRed
                            : pond.dissolvedOxygen < 6 ? AppTheme.amber
                            : AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${pond.dissolvedOxygen}',
                              style: GoogleFonts.poppins(color: AppTheme.textWhite,
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('mg/L O₂',
                              style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Key metrics — 2x2 grid
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _pondStat('Water', '${pond.waterSpreadPercent}%', Colors.blue),
                          _pondStat('Temp', '${pond.temperatureCelsius}°C',
                              pond.temperatureCelsius > 32 ? AppTheme.dangerRed : AppTheme.primaryGreen),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _pondStat('pH', '${pond.phLevel}',
                              (pond.phLevel < 6.5 || pond.phLevel > 8.5) ? AppTheme.amber : AppTheme.primaryGreen),
                          _pondStat('Algae', pond.algaeBloomRisk,
                              pond.algaeBloomRisk == 'High' ? AppTheme.dangerRed
                              : pond.algaeBloomRisk == 'Moderate' ? AppTheme.amber : AppTheme.primaryGreen),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Risk badges row — matches agri diagnostic cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _riskBadge('Algae', pond.algaeBloomRisk),
                const SizedBox(width: 6),
                _riskBadge('Heat', pond.heatStressRisk),
                const SizedBox(width: 6),
                _riskBadge('Water', pond.waterTrend == 'Reducing' ? 'High' : 'Low'),
                const SizedBox(width: 6),
                _riskBadge('Mortality', pond.mortalityRisk),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Last scan: ${pond.lastScanDate}',
                style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 10)),
          ),
          const SizedBox(height: 12),

          // Action buttons — same layout as agri farm cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _scanPond(pond),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.satellite_alt, color: Colors.blue, size: 14),
                          const SizedBox(width: 4),
                          Text('Scan Pond',
                              style: GoogleFonts.poppins(color: Colors.blue,
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showPondDetail(pond),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text('Details',
                        style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    await PondStorage.deletePond(pond.id);
                    await _loadUserFarms();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dangerRed.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppTheme.dangerRed, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanPond(AquaPond pond) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🛰️ Scanning ${pond.name}...')),
    );
    // Sync to backend first so it exists in Railway DB
    await ApiService.syncPond(pond);
    final result = await ApiService.scanPond(pond.id);
    if (!mounted) return;
    if (result['success'] == true) {
      final updated = AquaPond.fromJson(Map<String, dynamic>.from(result));
      await PondStorage.savePond(updated);
      await _loadUserFarms();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${pond.name} scan complete!\n'
            'DO: ${updated.dissolvedOxygen} mg/L · Temp: ${updated.temperatureCelsius}°C\n'
            'Algae: ${updated.algaeBloomRisk} · Mortality: ${updated.mortalityRisk}',
          ),
          backgroundColor: AppTheme.primaryGreen,
          duration: const Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Scan failed: ${result['error']}'),
          backgroundColor: AppTheme.amber,
        ),
      );
    }
  }

  void _showPondDetail(AquaPond pond) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.borderColor, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(pond.name, style: GoogleFonts.poppins(color: AppTheme.textWhite, fontWeight: FontWeight.w700, fontSize: 20)),
              Text('${pond.areaAcres} acres · Last scan: ${pond.lastScanDate}', style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 12)),
              const SizedBox(height: 20),
              _pondDetailRow('Water Spread', '${pond.waterSpreadPercent}%', Icons.water, Colors.blue),
              _pondDetailRow('Temperature', '${pond.temperatureCelsius}°C', Icons.thermostat, pond.temperatureCelsius > 30 ? AppTheme.dangerRed : AppTheme.primaryGreen),
              _pondDetailRow('Dissolved Oxygen', '${pond.dissolvedOxygen} mg/L', Icons.bubble_chart, pond.dissolvedOxygen < 4 ? AppTheme.dangerRed : AppTheme.primaryGreen),
              _pondDetailRow('pH Level', '${pond.phLevel}', Icons.science, (pond.phLevel < 6.5 || pond.phLevel > 8.5) ? AppTheme.amber : AppTheme.primaryGreen),
              _pondDetailRow('Algae Bloom Risk', pond.algaeBloomRisk, Icons.grass, pond.algaeBloomRisk == 'High' ? AppTheme.dangerRed : AppTheme.amber),
              _pondDetailRow('Heat Stress Risk', pond.heatStressRisk, Icons.local_fire_department, pond.heatStressRisk == 'High' ? AppTheme.dangerRed : AppTheme.amber),
              _pondDetailRow('Mortality Risk', pond.mortalityRisk, Icons.warning, pond.mortalityRisk == 'High' ? AppTheme.dangerRed : AppTheme.primaryGreen),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppTheme.dangerRed.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3))),
                child: Text(
                  pond.mortalityRisk == 'High'
                      ? '⚠️ Critical: Increase aeration immediately. Reduce feeding by 30%. Check water exchange systems.'
                      : '✅ Pond conditions are stable. Continue routine monitoring twice daily.',
                  style: GoogleFonts.poppins(color: AppTheme.textWhite, fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pondDetailRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 13))),
          Text(value, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _pondStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.poppins(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(label, style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _riskBadge(String label, String risk) {
    final color = risk == 'High' || risk == 'Critical' ? AppTheme.dangerRed : risk == 'Moderate' ? AppTheme.amber : AppTheme.primaryGreen;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 9)),
            Text(risk, style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _CircularScorePainter extends CustomPainter {
  final double score;
  final Color color;
  _CircularScorePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final bgPaint = Paint()..color = AppTheme.borderColor..style = PaintingStyle.stroke..strokeWidth = 8;
    final fgPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, 2 * math.pi * score, false, fgPaint);
  }

  @override
  bool shouldRepaint(_CircularScorePainter old) => old.score != score || old.color != color;
}
