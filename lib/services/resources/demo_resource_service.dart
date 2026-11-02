import '../../data/interfaces/i_resource_service.dart';
import '../../models/agri_resource.dart';
import 'cold_storage_discovery_service.dart';
import 'mandi_discovery_service.dart';

/// Unified agricultural infrastructure discovery service
/// Integrates real OpenStreetMap Overpass, Nominatim, and accredited directories.
class DemoResourceService implements IResourceService {
  final ColdStorageDiscoveryService _coldStorageService;
  final MandiDiscoveryService _mandiService;

  DemoResourceService({
    ColdStorageDiscoveryService? coldStorageService,
    MandiDiscoveryService? mandiService,
  })  : _coldStorageService = coldStorageService ?? ColdStorageDiscoveryService(),
        _mandiService = mandiService ?? MandiDiscoveryService();

  @override
  bool get isDemonstrationProvider => false;

  @override
  Future<List<AgriResource>> getNearbyResources({
    AgriResourceType? filterType,
    double? maxDistanceKm,
    double? latitude,
    double? longitude,
    String? district,
  }) async {
    final results = <AgriResource>[];
    final radius = maxDistanceKm ?? 50.0;

    if (latitude == null || longitude == null || latitude == 0.0 && longitude == 0.0) {
      return const [];
    }

    try {
      final futures = <Future<void>>[];

      // 1. Fetch Cold Storage if requested
      if (filterType == null || filterType == AgriResourceType.coldStorage) {
        futures.add(
          _coldStorageService.searchColdStorage(
            latitude: latitude,
            longitude: longitude,
            district: district,
            initialRadiusKm: radius,
            maxRadiusKm: 100.0,
          ).then((coldResult) {
            results.addAll(coldResult.facilities);
          }).catchError((_) {}),
        );
      }

      // 2. Fetch Mandis if requested
      if (filterType == null || filterType == AgriResourceType.mandi) {
        futures.add(
          _mandiService.discoverNearbyMandis(
            latitude: latitude,
            longitude: longitude,
            district: district,
            maxRadiusKm: radius,
          ).then((mandis) {
            results.addAll(mandis);
          }).catchError((_) {}),
        );
      }

      await Future.wait(futures);
    } catch (_) {
      // Gracefully return empty list on network error without fabricating fake data
    }

    results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return results;
  }
}
