import 'package:flutter/material.dart';

class Farm {
  final String id;
  final String name;
  final String cropType;
  final String cropTypeTelugu;
  final String sowingDate;
  final double areaAcres;
  final String locationName;
  final String locationNameTelugu;
  final int healthScore;
  final String healthStatus;
  final String healthStatusTelugu;
  final double latitude;
  final double longitude;
  final String waterStressLevel;
  final int waterStressConfidence;
  final String waterStressArea;
  final String waterStressAreaTelugu;
  final String waterloggingSeverity;
  final String waterloggingArea;
  final int pestRiskPercent;
  final int pestConfidence;
  final List<String> pestHotspots;
  final String diseaseRiskLevel;
  final bool diseaseRiskElevated;
  final String diseaseRiskNotes;
  final String diseaseRiskNotesTelugu;
  final List<List<double>> polygonPoints;
  final String lastScanDate;
  final List<Map<String, double>>? gpsPolygon; // For user-drawn farms

  Farm({
    required this.id,
    required this.name,
    required this.cropType,
    this.cropTypeTelugu = '',
    required this.sowingDate,
    required this.areaAcres,
    required this.locationName,
    this.locationNameTelugu = '',
    required this.healthScore,
    required this.healthStatus,
    this.healthStatusTelugu = '',
    required this.latitude,
    required this.longitude,
    required this.waterStressLevel,
    this.waterStressConfidence = 80,
    this.waterStressArea = '',
    this.waterStressAreaTelugu = '',
    this.waterloggingSeverity = 'None',
    this.waterloggingArea = '',
    this.pestRiskPercent = 0,
    this.pestConfidence = 0,
    this.pestHotspots = const [],
    this.diseaseRiskLevel = 'Low',
    this.diseaseRiskElevated = false,
    this.diseaseRiskNotes = '',
    this.diseaseRiskNotesTelugu = '',
    this.polygonPoints = const [],
    required this.lastScanDate,
    this.gpsPolygon,
  });

  Color get healthColor {
    if (healthScore >= 85) return const Color(0xFF2E7D32);
    if (healthScore >= 70) return const Color(0xFF689F38);
    if (healthScore >= 50) return const Color(0xFFFFA000);
    return const Color(0xFFD32F2F);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cropType': cropType,
        'sowingDate': sowingDate,
        'areaAcres': areaAcres,
        'locationName': locationName,
        'healthScore': healthScore,
        'healthStatus': healthStatus,
        'latitude': latitude,
        'longitude': longitude,
        'waterStressLevel': waterStressLevel,
        'pestRiskPercent': pestRiskPercent,
        'diseaseRiskLevel': diseaseRiskLevel,
        'lastScanDate': lastScanDate,
        'gpsPolygon': gpsPolygon,
      };

  factory Farm.fromJson(Map<String, dynamic> j) => Farm(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        cropType: j['cropType'] ?? '',
        sowingDate: j['sowingDate'] ?? '',
        areaAcres: (j['areaAcres'] ?? 0).toDouble(),
        locationName: j['locationName'] ?? '',
        healthScore: j['healthScore'] ?? 78,
        healthStatus: j['healthStatus'] ?? 'Good',
        latitude: (j['latitude'] ?? 17.385).toDouble(),
        longitude: (j['longitude'] ?? 78.486).toDouble(),
        waterStressLevel: j['waterStressLevel'] ?? 'Low',
        pestRiskPercent: j['pestRiskPercent'] ?? 0,
        diseaseRiskLevel: j['diseaseRiskLevel'] ?? 'Low',
        lastScanDate: j['lastScanDate'] ?? 'Just now',
        gpsPolygon: j['gpsPolygon'] != null
            ? List<Map<String, double>>.from(
                (j['gpsPolygon'] as List).map((p) =>
                    Map<String, double>.from(p as Map)))
            : null,
      );
}

class FarmAlert {
  final String id;
  final String type;
  final String title;
  final String titleTelugu;
  final String message;
  final String messageTelugu;
  final String severity;
  final String affectedArea;
  final String recommendation;
  final String recommendationTelugu;
  final String date;
  bool resolved;

  FarmAlert({
    required this.id,
    required this.type,
    required this.title,
    this.titleTelugu = '',
    required this.message,
    this.messageTelugu = '',
    required this.severity,
    required this.affectedArea,
    required this.recommendation,
    this.recommendationTelugu = '',
    required this.date,
    this.resolved = false,
  });

  Color get severityColor {
    switch (severity) {
      case 'critical': return const Color(0xFFD32F2F);
      case 'high': return const Color(0xFFE65100);
      case 'medium': return const Color(0xFFFFA000);
      default: return const Color(0xFF1976D2);
    }
  }
}

class AquaPond {
  final String id;
  final String name;
  final double areaAcres;
  final String locationName;
  final double latitude;
  final double longitude;
  final List<Map<String, double>>? gpsPolygon;
  final String species;
  final String stockingDate;
  final int waterSpreadPercent;
  final String waterTrend;
  final String algaeBloomRisk;
  final String heatStressRisk;
  final String mortalityRisk;
  final double dissolvedOxygen;
  final double temperatureCelsius;
  final double phLevel;
  final String lastScanDate;

  AquaPond({
    required this.id,
    required this.name,
    this.areaAcres = 0.0,
    this.locationName = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.gpsPolygon,
    this.species = 'Fish',
    this.stockingDate = '',
    this.waterSpreadPercent = 85,
    this.waterTrend = 'Stable',
    this.algaeBloomRisk = 'Low',
    this.heatStressRisk = 'Low',
    this.mortalityRisk = 'Low',
    this.dissolvedOxygen = 6.5,
    this.temperatureCelsius = 28.0,
    this.phLevel = 7.5,
    this.lastScanDate = 'Not scanned yet',
  });

  Color get mortalityColor {
    if (mortalityRisk == 'High') return const Color(0xFFE53935);
    if (mortalityRisk == 'Moderate') return const Color(0xFFFFA000);
    return const Color(0xFF00C853);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'areaAcres': areaAcres,
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'gpsPolygon': gpsPolygon,
    'species': species,
    'stockingDate': stockingDate,
    'waterSpreadPercent': waterSpreadPercent,
    'waterTrend': waterTrend,
    'algaeBloomRisk': algaeBloomRisk,
    'heatStressRisk': heatStressRisk,
    'mortalityRisk': mortalityRisk,
    'dissolvedOxygen': dissolvedOxygen,
    'temperatureCelsius': temperatureCelsius,
    'phLevel': phLevel,
    'lastScanDate': lastScanDate,
  };

  factory AquaPond.fromJson(Map<String, dynamic> j) => AquaPond(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    areaAcres: (j['areaAcres'] as num?)?.toDouble() ?? 0.0,
    locationName: j['locationName'] ?? '',
    latitude: (j['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (j['longitude'] as num?)?.toDouble() ?? 0.0,
    gpsPolygon: (j['gpsPolygon'] as List?)
        ?.map((p) => Map<String, double>.from(
            (p as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))))
        .toList(),
    species: j['species'] ?? 'Fish',
    stockingDate: j['stockingDate'] ?? '',
    waterSpreadPercent: (j['waterSpreadPercent'] as num?)?.toInt() ?? 85,
    waterTrend: j['waterTrend'] ?? 'Stable',
    algaeBloomRisk: j['algaeBloomRisk'] ?? 'Low',
    heatStressRisk: j['heatStressRisk'] ?? 'Low',
    mortalityRisk: j['mortalityRisk'] ?? 'Low',
    dissolvedOxygen: (j['dissolvedOxygen'] as num?)?.toDouble() ?? 6.5,
    temperatureCelsius: (j['temperatureCelsius'] as num?)?.toDouble() ?? 28.0,
    phLevel: (j['phLevel'] as num?)?.toDouble() ?? 7.5,
    lastScanDate: j['lastScanDate'] ?? 'Not scanned yet',
  );
}

