import 'dart:convert';
import 'package:http/http.dart' as http;

class SatelliteMetadata {
  final String? source; // e.g. "Maxar", "Airbus", "USDA/NAIP"
  final String? captureDate; // raw date string from provider, if available
  final bool found;

  SatelliteMetadata({this.source, this.captureDate, this.found = false});

  factory SatelliteMetadata.unknown() => SatelliteMetadata(found: false);
}

/// Queries Esri's World Imagery "identify" endpoint to find out which
/// underlying source image (and its capture date, when the provider
/// publishes one) is showing at a given lat/lng. World Imagery is a
/// patchwork mosaic from many providers (Maxar, Airbus, USDA NAIP,
/// etc) refreshed on a rolling basis — there is no free service that
/// gives true real-time satellite imagery, so this is the most honest
/// thing we can show: exactly which source/date is actually on screen.
class SatelliteMetadataService {
  static Future<SatelliteMetadata> getMetadataForLocation(
      double lat, double lng) async {
    try {
      final url = Uri.parse(
          'https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/identify'
          '?geometry=%7B%22x%22%3A$lng%2C%22y%22%3A$lat%7D'
          '&geometryType=esriGeometryPoint'
          '&sr=4326'
          '&tolerance=1'
          '&mapExtent=${lng - 0.01},${lat - 0.01},${lng + 0.01},${lat + 0.01}'
          '&imageDisplay=400,400,96'
          '&returnGeometry=false'
          '&f=json');

      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final results = data['results'] as List? ?? [];
        if (results.isNotEmpty) {
          final attrs = results[0]['attributes'] ?? {};
          // Esri's attribute keys vary by mosaic dataset; check the
          // common ones used in the World Imagery service.
          final source = attrs['NICE_NAME'] ?? attrs['SRC_DESC'] ?? attrs['DATASET_NAME'];
          final date = attrs['SRC_DATE'] ?? attrs['CAPTURE_DATE'] ?? attrs['DATE'];
          return SatelliteMetadata(
            source: source?.toString(),
            captureDate: date?.toString(),
            found: source != null || date != null,
          );
        }
      }
    } catch (_) {
      // Network unreachable or service changed shape — fail quietly,
      // caller shows a generic "imagery may not be the latest" notice.
    }
    return SatelliteMetadata.unknown();
  }
}
