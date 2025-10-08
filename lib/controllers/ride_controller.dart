import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ride_models.dart';
import '../services/database_service.dart';

class RideController extends GetxController {
  final DatabaseService _db = DatabaseService();

  // state
  var isRecording = false.obs;
  var isPaused = false.obs;
  var currentSpeedKmh = 0.0.obs;
  var avgSpeedKmh = 0.0.obs;
  var maxSpeedKmh = 0.0.obs;
  var distanceKm = 0.0.obs;
  var elapsed = Duration.zero.obs;

  // private
  StreamSubscription<Position>? _posSub;
  Timer? _timer;
  DateTime? _startTime;
  DateTime? _lastPointTime;
  Position? _lastPos;
  double _sumSpeed = 0.0;
  int _speedSamples = 0;
  final List<RidePoint> _points = [];

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> start() async {
    if (isRecording.value) return;
    if (!await _ensurePermission()) {
      Get.snackbar('提示', '需要定位权限', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    isRecording.value = true;
    isPaused.value = false;
    _startTime = DateTime.now();
    _lastPos = null;
    _lastPointTime = null;
    _sumSpeed = 0;
    _speedSamples = 0;
    distanceKm.value = 0;
    avgSpeedKmh.value = 0;
    maxSpeedKmh.value = 0;
    currentSpeedKmh.value = 0;
    _points.clear();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isPaused.value && _startTime != null) {
        elapsed.value = DateTime.now().difference(_startTime!);
      }
    });

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen(_onPosition);
  }

  void pauseResume() {
    if (!isRecording.value) return;
    isPaused.value = !isPaused.value;
  }

  Future<void> stopAndSave(
      {String deviceId = '', String deviceName = ''}) async {
    if (!isRecording.value) return;
    isRecording.value = false;
    _posSub?.cancel();
    _timer?.cancel();

    final end = DateTime.now();
    final start = _startTime ?? end;
    final ride = RideSession(
      deviceId: deviceId,
      deviceName: deviceName,
      startTime: start,
      endTime: end,
      durationSeconds: end.difference(start).inSeconds,
      distanceKm: distanceKm.value,
      avgSpeedKmh: avgSpeedKmh.value,
      maxSpeedKmh: maxSpeedKmh.value,
      totalClimbM: 0,
    );
    final rideId = await _db.insertRide(ride);
    await _db.insertRidePoints(rideId, _points);
    Get.snackbar('已保存', '骑行记录已保存', snackPosition: SnackPosition.BOTTOM);
  }

  void _onPosition(Position p) {
    if (!isRecording.value || isPaused.value) return;

    final speedKmh = (p.speed.isFinite ? p.speed : 0.0) * 3.6;
    currentSpeedKmh.value = double.parse(speedKmh.toStringAsFixed(2));
    _sumSpeed += speedKmh;
    _speedSamples += 1;
    avgSpeedKmh.value = _speedSamples == 0
        ? 0
        : double.parse((_sumSpeed / _speedSamples).toStringAsFixed(2));
    if (speedKmh > maxSpeedKmh.value)
      maxSpeedKmh.value = double.parse(speedKmh.toStringAsFixed(2));

    if (_lastPos != null) {
      final d = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        p.latitude,
        p.longitude,
      );
      distanceKm.value += d / 1000.0;
    }
    _lastPos = p;
    _lastPointTime = DateTime.now();
    _points.add(RidePoint(
      rideId: -1,
      timestamp: _lastPointTime!,
      latitude: p.latitude,
      longitude: p.longitude,
      speedKmh: currentSpeedKmh.value,
      altitudeM: (p.altitude.isFinite ? p.altitude : 0.0),
    ));
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _timer?.cancel();
    super.onClose();
  }
}
