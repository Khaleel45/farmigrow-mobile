/// Central map configuration.
/// Google Maps tile URLs for flutter_map.
///
/// flutter_map replaces {z}/{x}/{y} in the URL template automatically.
/// Google Maps tile API accepts exactly this format.
class MapConfig {
  static const String googleMapsApiKey = 'AIzaSyDEZ8sWoKH7F_MdapfM29JfyQxz1OrGO7g';

  /// Google Maps Hybrid — satellite imagery + road/village/place labels.
  /// lyrs=y → hybrid (satellite + labels in one tile)
  /// This is the correct flutter_map tile URL format for Google Maps.
  static const String googleHybridTemplate =
      'https://mt0.google.com/vt/lyrs=y&hl=en&x={x}&y={y}&z={z}&s=Ga&key=$googleMapsApiKey';

  /// Satellite only — no labels. Used for NDVI band overlay views.
  static const String googleSatelliteTemplate =
      'https://mt0.google.com/vt/lyrs=s&hl=en&x={x}&y={y}&z={z}&s=Ga&key=$googleMapsApiKey';

  /// Dark street map for non-satellite "Map" mode in Add Farm screen.
  static const String cartoDarkTemplate =
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
}
