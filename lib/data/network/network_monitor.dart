import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class NetworkMonitor {
  Stream<bool> get changes;
  Future<bool> get isNetworkAvailable;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  ConnectivityNetworkMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_available).distinct();

  @override
  Future<bool> get isNetworkAvailable async =>
      _available(await _connectivity.checkConnectivity());

  bool _available(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
