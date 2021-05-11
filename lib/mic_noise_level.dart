import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:permission_handler/permission_handler.dart';

//------------------------------------------------------------------------------

const String EVENT_CHANNEL_NAME = 'mic_noise_level.eventChannel';

typedef DataHandler = void Function(double data);
typedef ErrorHandler = void Function(dynamic error);

class MicNoiseLevel {
  bool _isMeasuring = false;
  Stream<double>? _stream;
  StreamSubscription<dynamic>? _subscription;

  static const EventChannel _micNoiseLevelChannel =
      const EventChannel(EVENT_CHANNEL_NAME);

  //----------------------------------------------------------------------------
  // Permission helpers
  //----------------------------------------------------------------------------

  /// Verify that it was granted
  Future<bool> checkPermission() async =>
      Permission.microphone.request().isGranted;

  /// Request the microphone permission
  Future<void> requestPermission() async => Permission.microphone.request();

  //----------------------------------------------------------------------------
  // Stream initialization
  //----------------------------------------------------------------------------

  void _createNoiseStream(ErrorHandler? errorHandler) {
    if (_stream == null) {
      _stream = _micNoiseLevelChannel
          .receiveBroadcastStream()
          .handleError((error) => _onError(error, errorHandler))
          .map((buffer) => double.parse('$buffer'));
    }
  }

  //----------------------------------------------------------------------------
  // Handlers
  //----------------------------------------------------------------------------

  void _onError(dynamic error, ErrorHandler? errorHandler) {
    _isMeasuring = false;
    _stream = null;
    if (errorHandler != null) {
      errorHandler(error);
    }
  }

  void _onData(double data, DataHandler? dataHandler) {
    // NOTE: Additional transformation can be applied here if needed
    if (dataHandler != null) {
      dataHandler(data);
    }
  }

  //----------------------------------------------------------------------------
  // Actions
  //----------------------------------------------------------------------------

  Future<Stream<double>> start(
      DataHandler? dataHandler, ErrorHandler? errorHandler) async {
    if (_isMeasuring) {
      return _stream!;
    }

    final granted = await checkPermission();

    if (!granted) {
      await requestPermission();
      start(dataHandler, errorHandler);
    }

    try {
      _createNoiseStream(errorHandler);
      _subscription = _stream!.listen((data) => _onData(data, dataHandler));
      _isMeasuring = true;
    } catch (err) {
      debugPrint('MicNoiseLevel: start() error: $err');
    }

    return _stream!;
  }

  Future<bool> stop() async {
    try {
      _subscription?.cancel();
      _subscription = null;

      _isMeasuring = false;
    } catch (err) {
      debugPrint('MicNoiseLevel: stopRecorder() error: $err');
    }

    return _isMeasuring;
  }
}
