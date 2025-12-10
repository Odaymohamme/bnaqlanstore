import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectionService {
  static final _connectivity = Connectivity();
  static final _controller = StreamController<bool>.broadcast();

  static Stream<bool> get onConnectionChange => _controller.stream;

  static Future<void> initialize() async {
    _connectivity.onConnectivityChanged.listen((result) {
      final hasInternet = result != ConnectivityResult.none;
      _controller.add(hasInternet);
    });
  }

  static Future<bool> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
