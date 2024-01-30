import 'package:flutter/services.dart';
import 'flutter_audio_recorder4_platform_interface.dart';

class MethodChannelHandler {

  static MethodChannel METHOD_CHANNEL = MethodChannel("");

  MethodChannelHandler(
      String methodChannelName,
      {
        int? defaultChannel
      }
  ) {
    METHOD_CHANNEL = MethodChannel(methodChannelName);
    METHOD_CHANNEL.setMethodCallHandler(methodHandler);
  }

  Future<void> methodHandler(MethodCall call) async {}

  Future<String> getPlatformVersion() async => await FlutterAudioRecorder4Platform.instance.getPlatformVersion() ?? "Unknown platform version";
}