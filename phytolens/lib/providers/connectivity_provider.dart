// lib/providers/connectivity_provider.dart
//
// Reactive connectivity state using Riverpod.
// Provides a single source of truth for online/offline status across the app.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network connection.
/// This is a reactive stream — UI will rebuild automatically.
final connectivityProvider = StreamNotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);

class ConnectivityNotifier extends StreamNotifier<bool> {
  @override
  Stream<bool> build() async* {
    // Emit initial state
    final initial = await Connectivity().checkConnectivity();
    yield _isConnected(initial);

    // Then listen for changes
    await for (final results in Connectivity().onConnectivityChanged) {
      yield _isConnected(results);
    }
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }
}
