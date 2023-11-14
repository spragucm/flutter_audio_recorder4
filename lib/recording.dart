import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter_audio_recorder4/audio_extension.dart';
import 'package:flutter_audio_recorder4/named_arguments.dart';
import 'recorder_state.dart';
import 'audio_format.dart';
import 'audio_metering.dart';

class Recording {

  static String DEFAULT_EXTENSION = AudioExtension.M4A.extension;
  static Duration DEFAULT_DURATION = const Duration();
  static AudioFormat DEFAULT_AUDIO_FORMAT = AudioExtension.M4A.audioFormat;
  static const RecorderState DEFAULT_RECORDER_STATE = RecorderState.UNSET;
  static const int DEFAULT_SAMPLE_RATE_KHZ = 16000;

  String? filepath;
  String? filepathTemp;//Don't try to set this manually! It's value is returned from native calls only
  String extension = DEFAULT_EXTENSION;
  Duration duration = DEFAULT_DURATION;
  AudioFormat audioFormat = DEFAULT_AUDIO_FORMAT;
  RecorderState recorderState = DEFAULT_RECORDER_STATE;
  int sampleRate = DEFAULT_SAMPLE_RATE_KHZ;
  String? message;

  AudioMetering audioMetering = AudioMetering(
      averagePower: AudioMetering.DEFAULT_AVERAGE_POWER,
      peakPower: AudioMetering.DEFAULT_PEAK_POWER,
      meteringEnabled: AudioMetering.DEFAULT_METERING_ENABLED
  );

  bool get needsToBeInitialized => recorderState == RecorderState.UNSET || recorderState == RecorderState.STOPPED;
  bool get isRecording => recorderState == RecorderState.PAUSED || recorderState == RecorderState.RECORDING;
  bool get isStopped => recorderState == RecorderState.STOPPED;
  bool get isPlayable => isStopped && duration.inMilliseconds > 0;
}

extension RecordingExtensionUtils on Map<dynamic, dynamic>? {
  Recording? toRecording() {
    var map = this;
    if (map == null) return null;

    return Recording()
      ..filepath = map[NamedArguments.FILEPATH] as String?
      ..filepathTemp = map[NamedArguments.FILEPATH_TEMP] as String?
      ..extension = map[NamedArguments.EXTENSION] as String? ?? Recording.DEFAULT_EXTENSION
      ..duration = Duration(milliseconds: (map[NamedArguments.DURATION] as int?) ?? 0)
      ..audioFormat = (map[NamedArguments.AUDIO_FORMAT] as String?)?.toAudioFormat() ?? AudioFormat.AAC
      ..recorderState =(map[NamedArguments.RECORDER_STATE] as String?).toRecorderState() ?? RecorderState.UNSET
      ..audioMetering = AudioMetering(
          peakPower: map[NamedArguments.PEAK_POWER] as double? ?? AudioMetering.DEFAULT_PEAK_POWER,
          averagePower: map[NamedArguments.AVERAGE_POWER] as double? ?? AudioMetering.DEFAULT_AVERAGE_POWER,
          meteringEnabled: map[NamedArguments.METERING_ENABLED] as bool? ?? AudioMetering.DEFAULT_METERING_ENABLED
      )
      ..sampleRate = map[NamedArguments.SAMPLE_RATE] as int? ?? Recording.DEFAULT_SAMPLE_RATE_KHZ
      ..message = map[NamedArguments.MESSAGE] as String?;
  }
}

extension FileUtils on LocalFileSystem {
  File? toFile(Recording recording, { bool onlyIfPlayable = false }) {
    // There could technically be an empty file that a caller would like to delete,
    // so, don't account for playable audio
    var filepath = recording.filepath;
    var isPlayable = onlyIfPlayable ? recording.isPlayable : true;
    if (recording.isStopped && filepath != null && isPlayable) {
      return file(filepath);
    } else {
      return null;
    }
  }

  Future<int> fileSizeInBytes(Recording recording) async => await toFile(recording)?.length() ?? -1;
}