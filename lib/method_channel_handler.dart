import 'package:flutter/services.dart';
import 'flutter_audio_recorder4_platform_interface.dart';

class MethodChannelHandler {

  late MethodChannel methodChannel;

  FlutterAudioRecorder4Platform platform = FlutterAudioRecorder4Platform.instance;

  MethodChannelHandler(String methodChannelName) {
    methodChannel = MethodChannel(methodChannelName);
    methodChannel.setMethodCallHandler(methodHandler);
  }

  Future<void> methodHandler(MethodCall call) async {}
}