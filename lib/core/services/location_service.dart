import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../errors/app_error.dart';

class PlaceResult {
  const PlaceResult({required this.name, required this.latitude, required this.longitude});
  final String name;
  final double latitude, longitude;
}

class LocationService {
  /// Asks for permission if needed. Throws [AppError] with friendly copy.
  Future<Position> position({bool allowStale = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppError('Location services are turned off on this device.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw const AppError('Location permission was not granted.');
    if (perm == LocationPermission.deniedForever) {
      throw const AppError('Location is blocked for this app. You can allow it in your device settings.');
    }
    if (allowStale) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
    );
  }

  Future<PlaceResult> current() async {
    final pos = await position(allowStale: false);
    var name = 'Current location';
    try {
      final marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final parts = [m.locality, m.subAdministrativeArea, m.country].where((e) => e != null && e.isNotEmpty).cast<String>().toList();
        if (parts.isNotEmpty) name = parts.take(2).join(', ');
      }
    } catch (_) {
      // reverse geocoding is a nicety; coordinates are enough
    }
    return PlaceResult(name: name, latitude: pos.latitude, longitude: pos.longitude);
  }
}
