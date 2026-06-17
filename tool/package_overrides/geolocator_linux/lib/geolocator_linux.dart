import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

class GeolocatorLinux extends GeolocatorPlatform {
  static void registerWith() {
    GeolocatorPlatform.instance = GeolocatorLinux();
  }
}
