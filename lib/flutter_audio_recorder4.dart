import 'package:flutter_audio_recorder4/recording.dart';

import 'named_arguments.dart';
import 'recorder_state.dart';
import 'audio_extension.dart';
import 'audio_metering.dart';
import 'audio_format.dart';
import 'flutter_audio_recorder4_platform_interface.dart';
import 'dart:async';
import 'dart:io';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_library;
import 'native_method_call.dart';

class FlutterAudioRecorder4 {

  static const int DEFAULT_CHANNEL = 0;
  static const MethodChannel CHANNEL = MethodChannel('flutter_audio_recorder');
  static const String DEFAULT_EXTENSION = '.m4a';
  static LocalFileSystem LOCAL_FILE_SYSTEM = const LocalFileSystem();

  /// Returns the result of record permission
  /// if not determined(app first launch),
  /// this will ask user to whether grant the permission
  static Future<bool?> get hasPermissions async {
    return await CHANNEL.invokeMethod(NativeMethodCall.HAS_PERMISSIONS.methodName);
  }

  String? filepath;
  String? extension;
  Recording? recording;
  int? sampleRate;

  Future? initRecorder;
  Future? get initialized => initRecorder;
  //Recording? get recording => recording;

  FlutterAudioRecorder4(String filepath, { AudioFormat? audioFormat, int sampleRate = 16000 }) {
    initRecorder = init(filepath, audioFormat, sampleRate);
  }

  Future init(String? filepath, AudioFormat? audioFormat, int sampleRate) async {
    this.sampleRate = sampleRate;

    Map<String, String?> pathAndExtension = resolvePathAndExtension(filepath, audioFormat);
    filepath = pathAndExtension[NamedArguments.FILEPATH];
    extension = pathAndExtension[NamedArguments.EXTENSION];
    validateFilepath(filepath);

    await invokeNativeInit();
  }

  Map<String, String?> resolvePathAndExtension(String? filepath, AudioFormat? audioFormat) {
    var values = { NamedArguments.FILEPATH : filepath, NamedArguments.EXTENSION : DEFAULT_EXTENSION };

    if (filepath == null) return values;

    String extensionInPath = path_library.extension(filepath);

    if (audioFormat != null && extensionInPath.toAudioFormat() != audioFormat) {
      values[NamedArguments.EXTENSION] = audioFormat.extension;
      values[NamedArguments.FILEPATH] = path_library.withoutExtension(filepath) + audioFormat.extension;

    } else if (audioFormat != null) {
      values[NamedArguments.EXTENSION] = path_library.extension(filepath);

    } else if (extensionInPath.isValidAudioExtension()) {
      values[NamedArguments.EXTENSION] = extensionInPath;

    } else {
      values[NamedArguments.FILEPATH] = filepath + DEFAULT_EXTENSION;
    }

    return values;
  }

  void validateFilepath(String? filepath) async {
    //TODO - CHRIS - I added the following exception, but might not be useful since source repo doesn't have it
    if (filepath == null) throw Exception("Filepath cannot be null");

    File file = LOCAL_FILE_SYSTEM.file(filepath);
    if (await file.exists()) {
      throw Exception("A file already exists at the path :$filepath");
    } else if (!await file.parent.exists()) {
      throw Exception("The specified parent directory does not exist");
    }
  }

  Future<void> invokeNativeInit() async {
    var result = await CHANNEL.invokeMethod(
      NativeMethodCall.INIT.methodName,
      {
        NamedArguments.FILEPATH: filepath,
        NamedArguments.EXTENSION: extension,
        NamedArguments.SAMPLE_RATE: sampleRate
      }
    );

    RecorderState? recorderState;
    if (result != false) {
      Map<String, Object> response = Map.from(result);
      String? recorderStateFromResponse = response[NamedArguments.RECORDER_STATE] as String?;
      recorderState = recorderStateFromResponse?.toRecorderState();
    }

    recording = Recording()
      ..recorderState = recorderState
      ..audioMetering = AudioMetering(
        averagePower: AudioMetering.DEFAULTS_AVERAGE_POWER,
        peakPower: AudioMetering.DEFAULTS_PEAK_POWER,
        meteringEnabled: AudioMetering.DEFAULTS_METERING_ENABLED
      );
  }

  /// Request an initialized recording instance to be [started]
  /// Once executed, audio recording will start working and
  /// a file will be generated in user's file system
  Future start() async {
    return CHANNEL.invokeMethod(NativeMethodCall.START.methodName);
  }

  /// Request currently [Recording] recording to be [Paused]
  /// Note: Use [current] to get latest state of recording after [pause]
  Future pause() async {
    return CHANNEL.invokeMethod(NativeMethodCall.PAUSE.methodName);
  }

  /// Request currently [Paused] recording to continue
  Future resume() async {
    return CHANNEL.invokeMethod(NativeMethodCall.RESUME.methodName);
  }

  /// Request the recording to stop
  /// Once its stopped, the recording file will be finalized
  /// and will not be start, resume, pause anymore.
  Future<Recording?> stop() async {
    var result = await CHANNEL.invokeMethod(NativeMethodCall.STOP.methodName);

    if (result != null) {
      Map<String, Object> response = Map.from(result);
      var recordingFromResponse = response.toRecording();
      if (recordingFromResponse != null) {
        recording = recordingFromResponse;
      }
    }

    return recording;
  }

  /// Ask for current status of recording
  /// Returns the result of current recording status
  /// Metering level, Duration, Status...
  Future<Recording?> current({int channel = DEFAULT_CHANNEL}) async {
    var result = await CHANNEL.invokeMethod(
        NativeMethodCall.CURRENT.methodName,
        {
          NamedArguments.CHANNEL:channel
        }
    );

    if (result != null && recording?.recorderState != RecorderState.STOPPED) {
      Map<String, Object> response = Map.from(result);
      var recordingFromResponse = response.toRecording();
      if (recordingFromResponse != null) {
        recording = recordingFromResponse;
      }
    }

    return recording;
  }

  //TODO - CHRIS - what is this?
  Future<String?> getPlatformVersion() {
    return FlutterAudioRecorder4Platform.instance.getPlatformVersion();
  }
}
