import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_audio_recorder4_method_channel.dart';

abstract class FlutterAudioRecorder4Platform extends PlatformInterface {
  /// Constructs a FlutterAudioRecorder4Platform.
  FlutterAudioRecorder4Platform() : super(token: _token);

  static final Object _token = Object();

  static FlutterAudioRecorder4Platform _instance = MethodChannelFlutterAudioRecorder4();

  /// The default instance of [FlutterAudioRecorder4Platform] to use.
  ///
  /// Defaults to [MethodChannelFlutterAudioRecorder4].
  static FlutterAudioRecorder4Platform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterAudioRecorder4Platform] when
  /// they register themselves.
  static set instance(FlutterAudioRecorder4Platform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
