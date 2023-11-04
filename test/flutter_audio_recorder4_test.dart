import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_audio_recorder4/flutter_audio_recorder4.dart';
import 'package:flutter_audio_recorder4/flutter_audio_recorder4_platform_interface.dart';
import 'package:flutter_audio_recorder4/flutter_audio_recorder4_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterAudioRecorder4Platform
    with MockPlatformInterfaceMixin
    implements FlutterAudioRecorder4Platform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterAudioRecorder4Platform initialPlatform = FlutterAudioRecorder4Platform.instance;

  test('$MethodChannelFlutterAudioRecorder4 is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterAudioRecorder4>());
  });

  test('getPlatformVersion', () async {
    FlutterAudioRecorder4 flutterAudioRecorder4Plugin = FlutterAudioRecorder4();
    MockFlutterAudioRecorder4Platform fakePlatform = MockFlutterAudioRecorder4Platform();
    FlutterAudioRecorder4Platform.instance = fakePlatform;

    expect(await flutterAudioRecorder4Plugin.getPlatformVersion(), '42');
  });
}
