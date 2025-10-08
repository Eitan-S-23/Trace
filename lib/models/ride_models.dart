class RideSession {
  final int? id;
  final String deviceId;
  final String deviceName;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double totalClimbM;

  RideSession({
    this.id,
    required this.deviceId,
    required this.deviceName,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.totalClimbM,
  });
}

class RidePoint {
  final int? id;
  final int rideId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double altitudeM;

  RidePoint({
    this.id,
    required this.rideId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.altitudeM,
  });
}
