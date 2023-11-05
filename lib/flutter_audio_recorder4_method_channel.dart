import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder4/flutter_audio_recorder4.dart';

import 'flutter_audio_recorder4_platform_interface.dart';

/// An implementation of [FlutterAudioRecorder4Platform] that uses method channels.
class MethodChannelFlutterAudioRecorder4 extends FlutterAudioRecorder4Platform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(FlutterAudioRecorder4.METHOD_CHANNEL_NAME);

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
