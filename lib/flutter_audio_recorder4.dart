import 'package:flutter_audio_recorder4/recording.dart';
import 'flutter_method_call.dart';
import 'named_arguments.dart';
import 'audio_extension.dart';
import 'audio_format.dart';
import 'flutter_audio_recorder4_platform_interface.dart';
import 'dart:async';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_library;
import 'native_method_call.dart';
import 'package:file/file.dart';
import 'dart:developer' as developer;

class FlutterAudioRecorder4 {

  static const String METHOD_CHANNEL_NAME = "flutter_audio_recorder4";
  static const MethodChannel METHOD_CHANNEL = MethodChannel(METHOD_CHANNEL_NAME);
  static const int DEFAULT_CHANNEL = 0;

  static LocalFileSystem LOCAL_FILE_SYSTEM = const LocalFileSystem();
  static const String LOG_NAME = "com.tcubedstudios.flutter_audio_recorder4";

  //This is static because hasPermissions and revokePermissions are static - the prior API is driving this
  static bool ALL_PERMISSIONS_GRANTED = false;
  static Function(bool hasPermissions)? _hasPermissionsExternalCallback;
  static Function(bool hasPermissions) HAS_PERMISSIONS_CALLBACK = (bool hasPermissions){
      ALL_PERMISSIONS_GRANTED = hasPermissions;
      _hasPermissionsExternalCallback?.call(ALL_PERMISSIONS_GRANTED);
  };

  /// Returns the result of record permission
  /// if not determined(app first launch),
  /// this will ask user to whether grant the permission
  static Future<bool?> get hasPermissions async {
    var allPermissionsGranted = await METHOD_CHANNEL.invokeMethod(NativeMethodCall.HAS_PERMISSIONS.methodName);
    HAS_PERMISSIONS_CALLBACK(allPermissionsGranted);
    return ALL_PERMISSIONS_GRANTED;
  }

  // This is static because hasPermissions is static - the prior API is driving this
  static Future get revokePermissions async {
    return await METHOD_CHANNEL.invokeMethod(NativeMethodCall.REVOKE_PERMISSIONS.methodName);
  }

  late LocalFileSystem _localFileSystem;

  //TODO - CHRIS - get most recent recording when recorder supports multiple recordings
  Recording recording = Recording();
  File? get recordingFile => _localFileSystem.toFile(recording);
  File? get playableRecordingFile => _localFileSystem.toFile(recording, onlyIfPlayable: true);
  Future<int> get recordingFileSizeInBytes => _localFileSystem.fileSizeInBytes(recording);

  late Future initialized;

  //TODO - CHRIS - when recorder supports multiple files, select the most recent file
  bool get needsToBeInitialized => recording.needsToBeInitialized;
  bool get isRecording => recording.isRecording;
  bool get isStopped => recording.isStopped;
  bool get hasPlayableAudio => recording.isPlayable;

  // .wav <---> AudioFormat.WAV
  // .mp4 .m4a .aac <---> AudioFormat.AAC
  // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.
  FlutterAudioRecorder4(
      String? filepath,
      {
        AudioFormat? audioFormat,
        int sampleRate = Recording.DEFAULT_SAMPLE_RATE_KHZ,
        LocalFileSystem? localFileSystem,
        bool? automaticallyRequestPermissions = true,
        Function(bool)? hasPermissionsCallback
      }
  ) {
    _localFileSystem = localFileSystem ?? const LocalFileSystem();
    _hasPermissionsExternalCallback = hasPermissionsCallback ?? HAS_PERMISSIONS_CALLBACK;
    METHOD_CHANNEL.setMethodCallHandler(methodHandler);

    initialized = init(filepath, audioFormat, sampleRate);

    if (automaticallyRequestPermissions ?? false) hasPermissions;
  }

  Future init(String? filepath, AudioFormat? audioFormat, int sampleRate) async {

    Map<String, String?> pathAndExtension = resolvePathAndExtension(filepath, audioFormat);
    recording.filepath = pathAndExtension[NamedArguments.FILEPATH];
    recording.extension = pathAndExtension[NamedArguments.EXTENSION] ?? Recording.DEFAULT_EXTENSION;
    recording.audioFormat = recording.extension.toAudioFormat() ?? Recording.DEFAULT_AUDIO_FORMAT;
    recording.sampleRate = sampleRate;

    validateFilepath(filepath);

    //TODO - CHRIS - should handle when init fails and notify callback
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
    var extension = audioFormat?.extension ?? Recording.DEFAULT_EXTENSION;
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
      developer.log("Filepath is null", name: LOG_NAME);
      return;
    }

    File file = LOCAL_FILE_SYSTEM.file(filepath);
    if (await file.exists()) {
      throw Exception("A file already exists at the path :$filepath");
    } else if (!await file.parent.exists()) {
      throw Exception("The specified parent directory does not exist");
    }
  }

  Future<bool> invokeNativeInit() async {
    try {
      //TODO - CHRIS - is there any reason all recording values should not be passed to init?
      var result = await METHOD_CHANNEL.invokeMethod(
          NativeMethodCall.INIT.methodName,
          {
            NamedArguments.FILEPATH: recording.filepath,
            NamedArguments.EXTENSION: recording.extension,
            NamedArguments.SAMPLE_RATE: recording.sampleRate
          }
      );

      recording = Map.from(result).toRecording() ?? recording;

      return true;
    } catch(exception) {
      return false;
    }
  }

  /// Ask for current status of recording
  /// Returns the result of current recording status
  /// Metering level, Duration, Status...
  Future<Recording?> current({int channel = DEFAULT_CHANNEL}) async {
    var result = await METHOD_CHANNEL.invokeMethod(
        NativeMethodCall.CURRENT.methodName,
        {
          NamedArguments.CHANNEL:channel                          //TODO - CHRIS - why pass channel when Android not using it?
        }
    );
    recording = Map.from(result).toRecording() ?? recording;
    return recording;
  }

  /// Request an initialized recording instance to be [started]
  /// Once executed, audio recording will start working and
  /// a file will be generated in user's file system
  Future start() async {
    //TODO - CHRIS - should recording be returned from start or should null? Currently it's null and I'm trying to avoid changing it
    //There is an exception that can be thrown though, so maybe add an error state to the recording, to indicate a problem and then just return the recording
    await METHOD_CHANNEL.invokeMethod(NativeMethodCall.START.methodName);
    recording = await current() ?? recording;
  }

  /// Request currently [Recording] recording to be [Paused]
  /// Note: Use [current] to get latest state of recording after [pause]
  Future pause() async => METHOD_CHANNEL.invokeMethod(NativeMethodCall.PAUSE.methodName);

  /// Request currently [Paused] recording to continue
  Future resume() async => METHOD_CHANNEL.invokeMethod(NativeMethodCall.RESUME.methodName);

  /// Request the recording to stop
  /// Once its stopped, the recording file will be finalized and will not start, resume, pause anymore.
  /// Stop may be called as many times as desired, but the recording will only be stopped once.
  Future<Recording> stop() async {
    var result = await METHOD_CHANNEL.invokeMethod(NativeMethodCall.STOP.methodName);
    recording = Map.from(result).toRecording() ?? recording;//result will be null if recording is already stopped, so the current recording will be returned
    return recording;
  }

  Future<String> getPlatformVersion() async => await FlutterAudioRecorder4Platform.instance.getPlatformVersion() ?? "Unknown platform version";
  
  Future<void> methodHandler(MethodCall call) async {
    if (call.method == FlutterMethodCall.HAS_PERMISSIONS.methodName) {
      handleHasPermissions(call.arguments);
    } else {
      developer.log("Unhandled method call:${call.method}");
    }
  }

  void handleHasPermissions(bool hasPermissions) {
    HAS_PERMISSIONS_CALLBACK?.call(hasPermissions);
  }
}