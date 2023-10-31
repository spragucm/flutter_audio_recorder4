
import 'flutter_audio_recorder4_platform_interface.dart';

class FlutterAudioRecorder4 {
  Future<String?> getPlatformVersion() {
    return FlutterAudioRecorder4Platform.instance.getPlatformVersion();
  }
}
