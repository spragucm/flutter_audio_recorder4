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

  @override
  Future<bool> hasPermissions() => Future.value(true);

  @override
  Future revokePermissions() => Future.value();

  @override
  Future init(String? filePath, String extension, int sampleRateHz, int iosAudioChannel) => Future.value();

  @override
  Future current() => Future.value();

  @override
  Future start() => Future.value();

  @override
  Future pause() => Future.value();

  @override
  Future resume() => Future.value();

  @override
  Future stop() => Future.value();

}

void main() {
  final FlutterAudioRecorder4Platform initialPlatform = FlutterAudioRecorder4Platform.instance;

  test('$MethodChannelFlutterAudioRecorder4 is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterAudioRecorder4>());
  });

  test('getPlatformVersion', () async {
    // Fake platform here, but this is set by android, ios, web, etc. to bind the calls to the native interfaces
    MockFlutterAudioRecorder4Platform fakePlatform = MockFlutterAudioRecorder4Platform();
    FlutterAudioRecorder4Platform.instance = fakePlatform;

    FlutterAudioRecorder4 plugin = FlutterAudioRecorder4(null);
    //TODO - CHRIS - write real tests for the following:
    expect(await plugin.getPlatformVersion(), '42');
    /*await plugin.init();
    await plugin.current();
    await plugin.start();
    await plugin.pause();
    await plugin.resume();
    await plugin.stop();*/

  });
}
