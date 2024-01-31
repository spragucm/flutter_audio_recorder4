import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder4/native_method_call.dart';
import 'package:flutter_audio_recorder4/recording.dart';

import 'flutter_audio_recorder4_platform_interface.dart';
import 'named_arguments.dart';

/// An implementation of [FlutterAudioRecorder4Platform] that uses method channels.
class MethodChannelFlutterAudioRecorder4 extends FlutterAudioRecorder4Platform {

  static const String METHOD_CHANNEL_NAME = "flutter_audio_recorder4";

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(METHOD_CHANNEL_NAME);

  @override
  Future<String?> getPlatformVersion() async => await methodChannel.invokeMethod<String>(NativeMethodCall.GET_PLATFORM_VERSION.methodName);

  @override
  Future<bool> hasPermissions() async => await methodChannel.invokeMethod<bool>(NativeMethodCall.HAS_PERMISSIONS.methodName) ?? false;

  @override
  Future revokePermissions() async => await methodChannel.invokeMethod(NativeMethodCall.REVOKE_PERMISSIONS.methodName);

  @override
  Future<dynamic> init(String? filepath, String extension, int sampleRateHz, int iosAudioChannel) async {
    try {
      var result = await methodChannel.invokeMethod(
          NativeMethodCall.INIT.methodName,
          {
            NamedArguments.FILEPATH: filepath,
            NamedArguments.EXTENSION: extension,
            NamedArguments.SAMPLE_RATE_HZ: sampleRateHz,
            NamedArguments.IOS_AUDIO_CHANNEL: iosAudioChannel //Only ios uses the audio channel number
          }
      );
      return _resultToRecording(result);
    } on PlatformException catch (e) {
      return 'PlatformException: platform.current: $e';
    } on MissingPluginException catch(e) {
      return 'MissingPluginException: platform.current: $e';
    }
  }

  @override
  Future<dynamic> current() async  {
    try {
      var result = await methodChannel.invokeMethod(NativeMethodCall.CURRENT.methodName);
      return _resultToRecording(result);
    } on PlatformException catch (e) {
      return 'PlatformException: platform.current: $e';
    } on MissingPluginException catch(e) {
      return 'MissingPluginException: platform.current: $e';
    }
  }

  @override
  Future<dynamic> start() async {
    try {
      var result = await methodChannel.invokeMethod(NativeMethodCall.START.methodName);
      return _resultToRecording(result);
    } on PlatformException catch (e) {
      return 'PlatformException: platform.start: $e';
    } on MissingPluginException catch(e) {
      return 'MissingPluginException: platform.start: $e';
    }
  }

  @override
  Future<dynamic> pause() async {
    try {
      var result = await methodChannel.invokeMethod(NativeMethodCall.PAUSE.methodName);
      return _resultToRecording(result);
    } on PlatformException catch (e) {
      return 'PlatformException: platform.pause: $e';
    } on MissingPluginException catch(e) {
      return 'MissingPluginException: platform.pause: $e';
    }
  }

  @override
  Future<dynamic> resume() async {
    try {
      var result = await methodChannel.invokeMethod(NativeMethodCall.RESUME.methodName);
      return _resultToRecording(result);
    } on PlatformException catch (e) {
      return 'PlatformException: platform.resume: $e';
    } on MissingPluginException catch(e) {
      return 'MissingPluginException: platform.resume: $e';
    }
  }

  @override
  Future<dynamic> stop() async {
    try {
      var result = await methodChannel.invokeMethod(NativeMethodCall.STOP.methodName);
      return _resultToRecording(result);
    } on PlatformException catch (e) {
      return 'PlatformException: platform.stop: $e';
    } on MissingPluginException catch(e) {
      return 'MissingPluginException: platform.stop: $e';
    }
  }

  Recording? _resultToRecording(result) => Map.from(result).toRecording();
}
