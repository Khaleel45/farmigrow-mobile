import 'dart:convert';
import 'package:http/http.dart' as http;

class GeoSearchResult {
  final String name;
  final String fullName;
  final double lat;
  final double lng;
  final String type;
  final String category;

  GeoSearchResult({
    required this.name,
    required this.fullName,
    required this.lat,
    required this.lng,
    this.type = 'place',
    this.category = '',
  });
}

class GeocodingService {
  /// Searches for a place by name, returning landmark-style results
  /// (roads, villages, lakes, colonies, towns etc).
  /// Tries Photon first (lenient rate limits, good for India), then
  /// falls back to Nominatim if Photon returns nothing or fails.
  static Future<List<GeoSearchResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final coordMatch =
        RegExp(r'^\s*(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)\s*$').firstMatch(query);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null) {
        return [
          GeoSearchResult(
            name: 'Coordinates: $lat, $lng',
            fullName: '$lat, $lng',
            lat: lat,
            lng: lng,
            type: 'coordinates',
          )
        ];
      }
    }

    // ─── Try Photon first ───
    try {
      final results = await _searchPhoton(query);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // fall through to Nominatim
    }

    // ─── Fallback: Nominatim ───
    try {
      final results = await _searchNominatim(query);
      if (results.isNotEmpty) return results;
    } catch (_) {
      // both failed
    }

    return [];
  }

  static Future<List<GeoSearchResult>> _searchPhoton(String query) async {
    final url = Uri.parse(
        'https://photon.komoot.io/api/'
        '?q=${Uri.encodeComponent(query)}'
        '&limit=8&lang=en&bbox=68,6,98,37'); // bbox roughly covers India
    final res = await http
        .get(url, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('Photon returned ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final features = data['features'] as List? ?? [];

    return features.map((f) {
      final props = f['properties'] ?? {};
      final coords = f['geometry']?['coordinates'] as List?;
      final lng = (coords != null && coords.isNotEmpty) ? coords[0] as double : 0.0;
      final lat = (coords != null && coords.length > 1) ? coords[1] as double : 0.0;

      // Photon properties: name, street, district, city, county, state,
      // osm_value (e.g. 'lake', 'village', 'residential'), osm_key (e.g. 'natural', 'place', 'highway')
      final parts = <String>[];
      for (final key in ['name', 'street', 'district', 'city', 'county']) {
        final v = props[key];
        if (v != null && v.toString().isNotEmpty && !parts.contains(v)) {
          parts.add(v.toString());
        }
      }
      final label = parts.isNotEmpty ? parts.take(3).join(', ') : 'Unnamed location';

      final fullParts = <String>[];
      for (final key in ['name', 'street', 'district', 'city', 'county', 'state', 'country']) {
        final v = props[key];
        if (v != null && v.toString().isNotEmpty && !fullParts.contains(v)) {
          fullParts.add(v.toString());
        }
      }

      return GeoSearchResult(
        name: label,
        fullName: fullParts.join(', '),
        lat: lat,
        lng: lng,
        type: props['osm_value']?.toString() ?? 'place',
        category: props['osm_key']?.toString() ?? '',
      );
    }).where((r) => r.lat != 0.0 || r.lng != 0.0).toList();
  }

  static Future<List<GeoSearchResult>> _searchNominatim(String query) async {
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=8&countrycodes=in&addressdetails=1');
    final res = await http.get(url, headers: {
      'User-Agent': 'FarmiGrowAI/1.0 (contact: support@farmigrow.ai)',
      'Accept-Language': 'en',
    }).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Nominatim returned ${res.statusCode}');
    }

    final List data = jsonDecode(res.body);
    return data.map<GeoSearchResult>((d) {
      final addr = d['address'] ?? {};
      final parts = <String>[];
      for (final key in [
        'amenity', 'natural', 'water', 'road', 'neighbourhood',
        'suburb', 'village', 'town', 'city', 'county', 'state_district'
      ]) {
        if (addr[key] != null && !parts.contains(addr[key])) {
          parts.add(addr[key]);
        }
      }
      final label = parts.isNotEmpty
          ? parts.take(3).join(', ')
          : (d['display_name'] as String).split(',').take(2).join(',');

      return GeoSearchResult(
        name: label,
        fullName: d['display_name'] ?? '',
        lat: double.parse(d['lat']),
        lng: double.parse(d['lon']),
        type: d['type'] ?? 'place',
        category: d['class'] ?? '',
      );
    }).toList();
  }
}
