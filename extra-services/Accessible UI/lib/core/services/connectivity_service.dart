import 'package:connectivity_plus/connectivity_plus.dart';

/// Returns true if the device currently appears to have *some* network
/// connection (wifi, mobile data, ethernet, etc).
///
/// This is a quick, local check — it does not guarantee the internet is
/// actually reachable, but it lets the app fail fast with a clear message
/// instead of hanging on a request for 30 seconds when the device is
/// obviously offline (e.g. airplane mode, no SIM, wifi off).
Future<bool> hasNetworkConnection() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
