import '../../models/agri_resource.dart';

/// Clean interface for nearby agricultural infrastructure discovery
/// (Cold Storages, Warehouses, APMC Mandis).
abstract class IResourceService {
  Future<List<AgriResource>> getNearbyResources({
    AgriResourceType? filterType,
    double? maxDistanceKm,
    double? latitude,
    double? longitude,
    String? district,
  });

  bool get isDemonstrationProvider;
}
