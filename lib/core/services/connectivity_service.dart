import 'package:connectivity_plus/connectivity_plus.dart';

/// True if the device has some network connection (wifi/mobile/etc). Local
/// check only, doesn't confirm internet is actually reachable - lets the
/// app fail fast on an obvious offline state instead of hanging.
Future<bool> hasNetworkConnection() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
