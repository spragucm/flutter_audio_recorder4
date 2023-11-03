// Audio Format,
// WAV is lossless audio, recommended
enum AudioFormat {
  AAC(extension: ".m4a"),
  WAV(extension: ".wav");

  final String extension;

  const AudioFormat({
    required this.extension
  });
}