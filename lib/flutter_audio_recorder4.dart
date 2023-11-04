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
import 'dart:developer' as developer;

class FlutterAudioRecorder4 {

  static const int DEFAULT_CHANNEL = 0;
  static const MethodChannel CHANNEL = MethodChannel('flutter_audio_recorder');
  static const AudioFormat DEFAULT_AUDIO_FORMAT = AudioFormat.AAC;
  static String DEFAULT_EXTENSION = DEFAULT_AUDIO_FORMAT.extension;
  static const int DEFAULT_SAMPLE_RATE = 16000;//khz
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

  FlutterAudioRecorder4({String? filepath, AudioFormat? audioFormat, int sampleRate = DEFAULT_SAMPLE_RATE }) {
    initRecorder = init(filepath, audioFormat, sampleRate);//TODO - CHRIS - why doesn't the CTOR have to await?
  }

  Future init(String? filepath, AudioFormat? audioFormat, int sampleRate) async {

    Map<String, String?> pathAndExtension = resolvePathAndExtension(filepath, audioFormat);
    filepath = pathAndExtension[NamedArguments.FILEPATH];
    extension = pathAndExtension[NamedArguments.EXTENSION];
    this.sampleRate = sampleRate;

    validateFilepath(filepath);

    await invokeNativeInit();
  }

  Map<String, String?> resolvePathAndExtension(String? filepath, AudioFormat? audioFormat) {

    String? pathExtension = filepath == null ? null : path_library.extension(filepath);
    AudioFormat? extensionAudioFormat = pathExtension?.toAudioFormat();
    bool useExtensionAudioFormat = (extensionAudioFormat != null && audioFormat == null) ||
                                   (extensionAudioFormat != null && audioFormat != null &&  audioFormat == extensionAudioFormat);
    bool isPathExtensionValid = pathExtension?.isValidAudioExtension() ?? false;

    /*
    - If preferred audio format is provided and the file's extension maps to a different audio format,
      then use the extension associated with the preferred audio format
    - If preferred audio format is provided and the file's extension maps to the same audio format,
      then use the file's extension since it has more granularity
    - If there is no preferred audio format, use the file's extension and the associated audio format
    - If the file's extension is not a valid audio format, use the default audio format's associated extension
    */
    var extension = audioFormat?.extension ?? DEFAULT_EXTENSION;
    if (isPathExtensionValid && useExtensionAudioFormat) {
      extension = pathExtension!;
    }

    return {
      NamedArguments.FILEPATH : filepath == null ? filepath : path_library.withoutExtension(filepath) + extension,
      NamedArguments.EXTENSION : extension
    };
  }

  void validateFilepath(String? filepath) async {

    if (filepath == null) {
      developer.log("Filepath is null", name:"com.tcubedstudios.flutter_audio_recorder4");
      return;
    }

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

    RecorderState recorderState = RecorderState.UNSET;
    if (result != false) {
      Map<String, Object> response = Map.from(result);
      String? recorderStateFromResponse = response[NamedArguments.RECORDER_STATE] as String?;
      recorderState = recorderStateFromResponse?.toRecorderState() ?? RecorderState.UNSET;
    }

    recording = Recording()
      ..recorderState = recorderState
      ..audioMetering = AudioMetering(
        averagePower: AudioMetering.DEFAULTS_AVERAGE_POWER,     //TODO - CHRIS - why not grab this from the response?
        peakPower: AudioMetering.DEFAULTS_PEAK_POWER,           //TODO - CHRIS - why not grab this from the response?
        meteringEnabled: AudioMetering.DEFAULTS_METERING_ENABLED//TODO - CHRIS - why not grab this from the response?
      );
  }

  /// Ask for current status of recording
  /// Returns the result of current recording status
  /// Metering level, Duration, Status...
  Future<Recording?> current({int channel = DEFAULT_CHANNEL}) async {
    var result = await CHANNEL.invokeMethod(
        NativeMethodCall.CURRENT.methodName,
        {
          NamedArguments.CHANNEL:channel                          //TODO - CHRIS - why pass channel why Android not using it?
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

  //TODO - CHRIS - what is this?
  Future<String?> getPlatformVersion() {
    return FlutterAudioRecorder4Platform.instance.getPlatformVersion();
  }
}
