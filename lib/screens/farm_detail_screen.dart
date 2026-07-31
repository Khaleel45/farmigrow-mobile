import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/models/farm_model.dart';
import 'package:farmigrow_ai/screens/satellite_screen.dart';

class FarmDetailScreen extends StatelessWidget {
  final Farm farm;
  const FarmDetailScreen({super.key, required this.farm});

  @override
  Widget build(BuildContext context) {
    final color = farm.healthColor;
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(farm.name,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.satellite_alt, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SatelliteScreen(farmName: farm.name)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(farm.healthStatus,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            if (farm.healthStatusTelugu.isNotEmpty)
                              Text(farm.healthStatusTelugu,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('${farm.healthScore}%',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: farm.healthScore / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick info
            _section('Farm Information', [
              _infoRow('Crop', '${farm.cropType}${farm.cropTypeTelugu.isNotEmpty ? " · ${farm.cropTypeTelugu}" : ""}', Icons.grass),
              _infoRow('Area', '${farm.areaAcres} acres', Icons.crop_square),
              _infoRow('Sowing Date', farm.sowingDate, Icons.calendar_today),
              _infoRow('Location', farm.locationName, Icons.location_on),
              _infoRow('Last Satellite Scan', farm.lastScanDate, Icons.satellite_alt),
            ]),

            const SizedBox(height: 16),

            // Water Stress
            _detailMetricCard(
              icon: Icons.water_drop,
              title: 'Water Stress Analysis',
              level: farm.waterStressLevel,
              levelColor: farm.waterStressLevel == 'High' ? Colors.red :
                  farm.waterStressLevel == 'Moderate' ? Colors.orange : Colors.green,
              confidence: farm.waterStressConfidence,
              detail: 'Affected area: ${farm.waterStressArea}',
            ),
            const SizedBox(height: 12),

            // Pest Risk
            _detailMetricCard(
              icon: Icons.bug_report,
              title: 'Pest Risk Analysis',
              level: '${farm.pestRiskPercent}%',
              levelColor: farm.pestRiskPercent > 35 ? Colors.red :
                  farm.pestRiskPercent > 15 ? Colors.orange : Colors.green,
              confidence: farm.pestConfidence,
              detail: farm.pestHotspots.isNotEmpty
                  ? 'Hotspots: ${farm.pestHotspots.join(", ")}'
                  : 'No hotspots detected',
            ),
            const SizedBox(height: 12),

            // Disease Risk
            _detailMetricCard(
              icon: Icons.coronavirus,
              title: 'Disease Risk Analysis',
              level: farm.diseaseRiskLevel,
              levelColor: farm.diseaseRiskLevel == 'Critical' || farm.diseaseRiskLevel == 'High' ? Colors.red :
                  farm.diseaseRiskLevel == 'Moderate' ? Colors.orange : Colors.green,
              confidence: 85,
              detail: farm.diseaseRiskNotes,
            ),
            const SizedBox(height: 12),

            // Waterlogging
            if (farm.waterloggingSeverity != 'None')
              _detailMetricCard(
                icon: Icons.waves,
                title: 'Waterlogging Detection',
                level: farm.waterloggingSeverity,
                levelColor: farm.waterloggingSeverity == 'Severe' ? Colors.red : Colors.orange,
                confidence: 80,
                detail: 'Area: ${farm.waterloggingArea}',
              ),

            const SizedBox(height: 20),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SatelliteScreen(farmName: farm.name)),
                ),
                icon: const Icon(Icons.satellite_alt),
                label: Text('View Satellite Analysis',
                    style: GoogleFonts.poppins(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textGrey)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AppTheme.textGrey)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _detailMetricCard({
    required IconData icon,
    required String title,
    required String level,
    required Color levelColor,
    required int confidence,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: levelColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(level,
                    style: GoogleFonts.poppins(
                        color: levelColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(detail,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: AppTheme.textGrey, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.verified, size: 13, color: AppTheme.textGrey),
              const SizedBox(width: 4),
              Text('AI Confidence: $confidence%',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: AppTheme.textGrey)),
            ],
          ),
        ],
      ),
    );
  }
}
