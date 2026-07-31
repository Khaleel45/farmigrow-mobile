import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/services/farm_storage.dart';
import 'package:farmigrow_ai/services/notification_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<FarmAlert> _alerts = [];
  String _filter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  /// Builds real alerts from each saved farm's stored risk fields
  /// (waterStressLevel, pestRiskPercent, diseaseRiskLevel,
  /// waterloggingSeverity). These fields currently come from the
  /// values set when a farm is created/edited; once Sentinel-2/
  /// weather integration is live, this same function will read the
  /// satellite-derived values that overwrite those fields.
  Future<void> _loadAlerts() async {
    setState(() => _loading = true);
    final farms = await FarmStorage.getUserFarms();
    final generated = <FarmAlert>[];

    for (final farm in farms) {
      if (farm.waterStressLevel == 'High') {
        generated.add(FarmAlert(
          id: '${farm.id}_water',
          type: 'water_stress',
          title: '⚠ Water Stress Detected',
          message: '${farm.name} shows high water stress.'
              '${farm.waterStressArea.isNotEmpty ? " Affected area: ${farm.waterStressArea}." : ""}',
          severity: 'high',
          affectedArea: farm.waterStressArea.isNotEmpty ? farm.waterStressArea : farm.locationName,
          recommendation: 'Irrigate within 48 hours to prevent yield loss.',
          date: 'Based on last scan: ${farm.lastScanDate}',
        ));
      } else if (farm.waterStressLevel == 'Moderate') {
        generated.add(FarmAlert(
          id: '${farm.id}_water',
          type: 'water_stress',
          title: 'Moderate Water Stress',
          message: '${farm.name} shows moderate water stress levels.',
          severity: 'medium',
          affectedArea: farm.waterStressArea.isNotEmpty ? farm.waterStressArea : farm.locationName,
          recommendation: 'Monitor soil moisture closely over the next few days.',
          date: 'Based on last scan: ${farm.lastScanDate}',
        ));
      }

      if (farm.pestRiskPercent >= 35) {
        generated.add(FarmAlert(
          id: '${farm.id}_pest',
          type: 'pest_infestation',
          title: '⚠ High Pest Risk',
          message: '${farm.name} shows elevated pest risk (${farm.pestRiskPercent}%).'
              '${farm.pestHotspots.isNotEmpty ? " Hotspots: ${farm.pestHotspots.join(", ")}." : ""}',
          severity: 'high',
          affectedArea: farm.pestHotspots.isNotEmpty ? farm.pestHotspots.join(', ') : farm.locationName,
          recommendation: 'Inspect hotspot areas closely and consider preventive spray.',
          date: 'Based on last scan: ${farm.lastScanDate}',
        ));
      } else if (farm.pestRiskPercent >= 15) {
        generated.add(FarmAlert(
          id: '${farm.id}_pest',
          type: 'pest_infestation',
          title: 'Moderate Pest Risk',
          message: '${farm.name} shows pest risk of ${farm.pestRiskPercent}%.',
          severity: 'medium',
          affectedArea: farm.locationName,
          recommendation: 'Continue routine field inspection over the coming week.',
          date: 'Based on last scan: ${farm.lastScanDate}',
        ));
      }

      if (farm.diseaseRiskLevel == 'High' || farm.diseaseRiskLevel == 'Critical' || farm.diseaseRiskElevated) {
        generated.add(FarmAlert(
          id: '${farm.id}_disease',
          type: 'disease_risk',
          title: '⚠ Disease Risk Elevated',
          message: '${farm.name}: ${farm.diseaseRiskNotes.isNotEmpty ? farm.diseaseRiskNotes : "Conditions are favourable for disease spread."}',
          severity: 'high',
          affectedArea: farm.locationName,
          recommendation: 'Apply preventive fungicide and monitor leaf surfaces for early symptoms.',
          date: 'Based on last scan: ${farm.lastScanDate}',
        ));
      }

      if (farm.waterloggingSeverity != 'None' && farm.waterloggingSeverity.isNotEmpty) {
        generated.add(FarmAlert(
          id: '${farm.id}_waterlogging',
          type: 'waterlogging',
          title: 'Waterlogging Detected',
          message: '${farm.name} shows ${farm.waterloggingSeverity.toLowerCase()} waterlogging.'
              '${farm.waterloggingArea.isNotEmpty ? " Area: ${farm.waterloggingArea}." : ""}',
          severity: farm.waterloggingSeverity == 'Severe' ? 'high' : 'medium',
          affectedArea: farm.waterloggingArea.isNotEmpty ? farm.waterloggingArea : farm.locationName,
          recommendation: 'Check drainage channels and avoid further irrigation until water recedes.',
          date: 'Based on last scan: ${farm.lastScanDate}',
        ));
      }
    }

    setState(() {
      _alerts = generated;
      _loading = false;
    });

    _notifyHighSeverityAlerts();
  }

  Future<void> _notifyHighSeverityAlerts() async {
    final critical = _alerts.where((a) => !a.resolved && a.severity == 'high').toList();
    if (critical.isNotEmpty) {
      await NotificationService.showAlertNotification(
        title: critical.first.title,
        body: critical.first.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'All'
        ? _alerts
        : _alerts.where((a) => a.severity == _filter.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        title: Text('Smart Alerts',
            style: GoogleFonts.poppins(
                color: AppTheme.textWhite, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
            onPressed: _loadAlerts,
          ),
          if (_alerts.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  for (var a in _alerts) a.resolved = true;
                });
              },
              child: Text('Clear All',
                  style: GoogleFonts.poppins(
                      color: AppTheme.primaryGreen, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : Column(
              children: [
                // Filter chips
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'High', 'Medium', 'Low']
                          .map((f) => GestureDetector(
                                onTap: () => setState(() => _filter = f),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _filter == f
                                        ? AppTheme.primaryGreen
                                        : AppTheme.bgCard,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _filter == f
                                          ? AppTheme.primaryGreen
                                          : AppTheme.borderColor,
                                    ),
                                  ),
                                  child: Text(f,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _filter == f
                                              ? Colors.black
                                              : AppTheme.textGrey)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadAlerts,
                          color: AppTheme.primaryGreen,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.55,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppTheme.spaceXXL),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.notifications_off_outlined,
                                            color: AppTheme.textGrey, size: 40),
                                        const SizedBox(height: AppTheme.spaceLG),
                                        Text(
                                          _alerts.isEmpty && _filter == 'All'
                                              ? 'No alerts right now'
                                              : 'No $_filter alerts',
                                          style: AppTheme.h2(),
                                        ),
                                        const SizedBox(height: AppTheme.spaceSM),
                                        Text(
                                          'Alerts are generated automatically from your '
                                          'farms\' water, pest, and disease risk levels. '
                                          'Add a farm or pull down to refresh.',
                                          textAlign: TextAlign.center,
                                          style: AppTheme.bodySmall(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadAlerts,
                          color: AppTheme.primaryGreen,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) =>
                                _buildAlertCard(context, filtered[i]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAlertCard(BuildContext context, FarmAlert alert) {
    final color = alert.severityColor;
    return GestureDetector(
      onTap: () => _showDetail(context, alert),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 4),
            top: BorderSide(color: AppTheme.borderColor),
            right: BorderSide(color: AppTheme.borderColor),
            bottom: BorderSide(color: AppTheme.borderColor),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(alert.type), color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.title,
                      style: GoogleFonts.poppins(
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(alert.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: AppTheme.textGrey, fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(alert.date,
                          style: GoogleFonts.poppins(
                              color: AppTheme.textGrey, fontSize: 10)),
                      const Spacer(),
                      Text('Tap for details →',
                          style: GoogleFonts.poppins(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'water_stress': return Icons.water_drop;
      case 'pest_infestation': return Icons.bug_report;
      case 'disease_risk': return Icons.coronavirus;
      case 'waterlogging': return Icons.waves;
      case 'weather_warning': return Icons.thunderstorm;
      default: return Icons.info;
    }
  }

  void _showDetail(BuildContext context, FarmAlert alert) {
    final color = alert.severityColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_iconFor(alert.type), color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(alert.title,
                    style: GoogleFonts.poppins(
                        color: AppTheme.textWhite,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 ${alert.affectedArea}',
                      style: GoogleFonts.poppins(
                          color: AppTheme.textWhite, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('💡 ${alert.recommendation}',
                      style: GoogleFonts.poppins(
                          color: AppTheme.textWhite,
                          fontSize: 13,
                          height: 1.5)),
                  if (alert.recommendationTelugu.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(alert.recommendationTelugu,
                        style: GoogleFonts.poppins(
                            color: AppTheme.textGrey,
                            fontSize: 12,
                            height: 1.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => alert.resolved = true);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Mark as Resolved',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
