import 'package:flutter_audio_recorder4/audio_extension.dart';
import 'package:flutter_audio_recorder4/named_arguments.dart';

import 'recorder_state.dart';
import 'audio_format.dart';
import 'audio_metering.dart';

class Recording {
  String? filepath;
  String? extension;
  Duration? duration;
  AudioFormat? audioFormat;
  RecorderState? recorderState;
  AudioMetering? audioMetering;
}

extension RecordingExtensionUtils on Map<String, Object>? {
  Recording? toRecording() {
    var map = this;
    if (map == null) return null;

    return Recording()
      ..filepath = map[NamedArguments.FILEPATH] as String?
      ..extension = (map[NamedArguments.EXTENSION] as String?)//TODO - CHRIS - this was looking at AUDIO_FORMAT key
      ..duration = Duration(milliseconds: map[NamedArguments.DURATION] as int)
      ..audioFormat = (map[NamedArguments.AUDIO_FORMAT] as String?)?.toAudioFormat()
      ..recorderState =(map[NamedArguments.RECORDER_STATE] as String?).toRecorderState()
      ..audioMetering = AudioMetering(
        peakPower: map[NamedArguments.PEAK_POWER] as double?,
        averagePower: map[NamedArguments.AVERAGE_POWER] as double?,
        meteringEnabled: map[NamedArguments.METERING_ENABLED] as bool?
      );
  }
}