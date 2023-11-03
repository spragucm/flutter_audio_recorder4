import 'audio_format.dart';

enum AudioExtension {

  AAC(extension:".aac", audioFormat: AudioFormat.AAC),
  M4A(extension:".m4a", audioFormat: AudioFormat.AAC),
  MP4(extension:".mp4", audioFormat: AudioFormat.AAC),
  WAV(extension:".wav", audioFormat: AudioFormat.WAV);

  final String extension;
  final AudioFormat audioFormat;

  const AudioExtension({
    required this.extension,
    required this.audioFormat
  });
}

extension AudioExtensionUtils on String? {
  AudioFormat? toAudioFormat() {
    for (var value in AudioExtension.values) {
      if (this == value.extension) {
        return value.audioFormat;
      }
    }
    return null;
  }

  bool isValidAudioExtension() {
    return AudioExtension.values.any((value) => value.extension == this);
  }
}
