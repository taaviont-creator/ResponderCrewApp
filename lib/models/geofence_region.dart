/// Location is classified only on the phone. Coordinates are never uploaded.
String geofenceRegion({
  required double distance,
  required double accuracy,
  required double inner,
  required double outer,
}) {
  if (!distance.isFinite ||
      !accuracy.isFinite ||
      accuracy < 0 ||
      accuracy > 200 ||
      inner < 300 ||
      outer <= inner) {
    return 'unknown';
  }
  // Do not claim an inner region when the accuracy circle crosses its boundary.
  if (distance + accuracy < inner) return 'inner';
  if (distance - accuracy > outer) return 'outside';
  if (distance - accuracy > inner && distance + accuracy < outer) return 'ring';
  return 'unknown';
}
