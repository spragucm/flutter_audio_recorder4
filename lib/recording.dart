import 'package:file/local.dart';
import 'package:file/src/interface/file.dart';
import 'package:flutter_audio_recorder4/audio_extension.dart';
import 'package:flutter_audio_recorder4/named_arguments.dart';

import 'recorder_state.dart';
import 'audio_format.dart';
import 'audio_metering.dart';

class Recording {

  static createDefaultRecording() {
    Recording getDefaultRecording() => Recording()
      ..recorderState = RecorderState.UNSET
      ..audioMetering = AudioMetering(
          averagePower: AudioMetering.DEFAULTS_AVERAGE_POWER,
          peakPower: AudioMetering.DEFAULTS_PEAK_POWER,
          meteringEnabled: AudioMetering.DEFAULTS_METERING_ENABLED
      );
  }

  String? filepath;
  String? extension;
  Duration? duration;
  AudioFormat? audioFormat;
  RecorderState? recorderState;
  AudioMetering? audioMetering;
  late LocalFileSystem _localFileSystem;

  File? get file {
    // There could technically be an empty file that a caller would like to delete,
    // so, don't account for playable audio
    if (isRecordingStopped()) {
      return filepath == null ? null : _localFileSystem.file(filepath);
    } else {
      return null;
    }
  }

  File? get playableFile {
    if (hasPlayableAudio()) {
      return file;
    } else {
      return null;
    }
  }

  Recording({ LocalFileSystem? localFileSystem}) {
    _localFileSystem = localFileSystem ?? const LocalFileSystem();
  }

  bool isRecording() => recorderState == RecorderState.PAUSED || recorderState == RecorderState.RECORDING;
  bool isRecordingStopped() => recorderState == RecorderState.STOPPED;
  bool hasPlayableAudio() => isRecordingStopped() && (duration?.inMilliseconds ?? 0) > 0;
  Future<int> fileSizeInBytes() async => await file?.length() ?? -1;
}

extension RecordingExtensionUtils on Map<dynamic, dynamic>? {
  Recording? toRecording({LocalFileSystem? localFileSystem}) {
    var map = this;
    if (map == null) return null;

    return Recording(localFileSystem: localFileSystem)
      ..filepath = map[NamedArguments.FILEPATH] as String?
      ..extension = (map[NamedArguments.EXTENSION] as String?)
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