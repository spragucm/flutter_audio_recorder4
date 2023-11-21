import 'package:flutter_audio_recorder4/permissions_requester.dart';
import 'package:flutter_audio_recorder4/recorder_state.dart';
import 'package:flutter_audio_recorder4/recording.dart';
import 'package:flutter_audio_recorder4/utils.dart';
import 'audio_metering.dart';
import 'method_channel_handler.dart';
import 'named_arguments.dart';
import 'audio_extension.dart';
import 'audio_format.dart';
import 'dart:async';
import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path_library;
import 'native_method_call.dart';
import 'package:file/file.dart';

class FlutterAudioRecorder4 extends PermissionsRequester {

  static const String METHOD_CHANNEL_NAME = "com.tcubedstudios.flutter_audio_recorder4";
  static const String LOG_NAME = METHOD_CHANNEL_NAME;

  //TODO - CHRIS - required for backwards compatibility, but I really don't like the statics
  /// Returns the result of record permission
  /// if not determined(app first launch),
  /// this will ask user to whether grant the permission
  static Future<bool?> get hasPermissions async => PermissionsRequester.hasPermissions;
  static Future get revokePermissions async => PermissionsRequester.revokePermissions;

  late LocalFileSystem _localFileSystem;

  //TODO - CHRIS - get most recent recording when recorder supports multiple recordings
  //will likely need to be methods with recording name passed as arg
  Recording recording = Recording();
  String? get filepath => recording.filepath;
  set filepath(String? path) => { recording.filepath = path };
  String get extension => recording.extension;
  Duration get duration => recording.duration;
  AudioFormat get audioFormat => recording.audioFormat;
  RecorderState get recorderState => recording.recorderState;
  int get sampleRateHz => recording.sampleRateHz;
  AudioMetering get audioMetering => recording.audioMetering;
  double get averagePower => audioMetering.averagePower;
  double get peakPower => audioMetering.peakPower;
  bool get meteringEnabled => audioMetering.meteringEnabled;
  bool get needsToBeInitialized => recording.needsToBeInitialized;
  bool get isRecording => recording.isRecording;
  bool get isStopped => recording.isStopped;
  bool get isPlayable => recording.isPlayable;
  File? get recordingFile => _localFileSystem.toFile(recording);
  File? get playableRecordingFile => _localFileSystem.toFile(recording, onlyIfPlayable: true);
  Future<int> get recordingFileSizeInBytes => _localFileSystem.fileSizeInBytes(recording);
  int recordingUpdateIntervalMillis;

  late Future initialized;
  Function(Recording recording)? onInitializedCallback;
  Function(Recording recording)? onStartedCallback;//TODO - CHRIS - this should probably be onRecordingCallback
  Function(Recording recording)? onRecordingUpdatedCallback;
  Function(Recording recording)? onPausedCallback;
  Function(Recording recording)? onResumeCallback;
  Function(Recording recording)? onStoppedCallback;

  Timer? _timer;

  // .wav <---> AudioFormat.WAV
  // .mp4 .m4a .aac <---> AudioFormat.AAC
  // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.
  FlutterAudioRecorder4(
      String? filepath,
      {
        AudioFormat? audioFormat,
        int sampleRate = Recording.DEFAULT_SAMPLE_RATE_HZ,//TODO - CHRIS - rename sampleRate to sampleRateHz; this will be a breaking change though
        LocalFileSystem? localFileSystem,
        bool? automaticallyRequestPermissions = true,
        this.recordingUpdateIntervalMillis = 50,
        Function(bool)? hasPermissionsCallback,
        this.onInitializedCallback,
        this.onStartedCallback,
        this.onRecordingUpdatedCallback,
        this.onPausedCallback,
        this.onResumeCallback,
        this.onStoppedCallback
      }
  ) : super("flutter_audio_recorder4", hasPermissionsCallback: hasPermissionsCallback) {
    _localFileSystem = localFileSystem ?? const LocalFileSystem();

    initialized = init(filepath, audioFormat, sampleRate);

    if (automaticallyRequestPermissions ?? false) hasPermissions;
  }

  Future<Recording> init(String? filepath, AudioFormat? audioFormat, int sampleRateHz) async {

    Map<String, String?> pathAndExtension = await _resolvePathAndExtension(filepath, audioFormat);
    recording.filepath = pathAndExtension[NamedArguments.FILEPATH];
    recording.extension = pathAndExtension[NamedArguments.EXTENSION] ?? Recording.DEFAULT_EXTENSION;
    recording.audioFormat = recording.extension.toAudioFormat() ?? Recording.DEFAULT_AUDIO_FORMAT;
    recording.sampleRateHz = sampleRateHz;

    if(await _invokeNativeInit()) {
      onInitializedCallback?.call(recording);
    } else {
      //TODO - CHRIS - handle when init fails and notify callback
    }

    return recording;
  }

  Future<Map<String, String?>> _resolvePathAndExtension(String? filepath, AudioFormat? audioFormat) async {

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

    var resolvedFilepath = filepath == null ? filepath : path_library.withoutExtension(filepath) + extension;
    var message = await _localFileSystem.validateFilepath(resolvedFilepath);

    return {
      NamedArguments.FILEPATH : resolvedFilepath,
      NamedArguments.EXTENSION : extension,
      NamedArguments.MESSAGE : message
    };
  }

  bool _updateRecording(result, String? updatedMessage, String? notUpdatedMessage) {

    recording = Map.from(result).toRecording() ?? recording;

    //There is an exception that can be thrown though, so maybe add an error state to the recording, to indicate a problem and then just return the recording
    //TODO - CHRIS - handle result.error as well as result.success
    //TODO - CHRIS - return false when result.error was received
    var updated = true;
    recording.message = updated ? updatedMessage : notUpdatedMessage;
    return updated;
  }

  Future<bool> _invokeNativeInit() async {//TODO - CHRIS - should this return recording with a message like the rest?
    try {
      //Only passing values to init that are settable by caller
      var result = await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(
          NativeMethodCall.INIT.methodName,
          {
            NamedArguments.FILEPATH: recording.filepath,
            NamedArguments.EXTENSION: recording.extension,
            NamedArguments.SAMPLE_RATE_HZ: recording.sampleRateHz
          }
      );
      return _updateRecording(result, "Recorder initialized", "Recorder not initialized");
    } catch(exception) {
      return false;
    }
  }

  /// Ask for current status of recording
  /// Returns the result of current recording status
  /// Metering level, Duration, Status...
  Future<Recording?> current({int? channel}) async {
    var result = await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(
        NativeMethodCall.CURRENT.methodName,
        {
          NamedArguments.CHANNEL: channel ?? MethodChannelHandler.DEFAULT_CHANNEL //TODO - CHRIS - why pass channel when Android not using it?
        }
    );
    _updateRecording(result, "Recording retrieved", "Recording not retrieved");
    return recording;
  }

  /// Request an initialized recording instance to be [started]
  /// Once executed, audio recording will start working and
  /// a file will be generated in user's file system
  Future<Recording> start() async {
    _destroyOldTimer();
    _createNewTimer(recordingUpdateIntervalMillis);

    var result = await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(NativeMethodCall.START.methodName);
    _updateRecording(result, "Recording started", "Recording not started");

    onStartedCallback?.call(recording);

    return recording;
  }

  _createNewTimer(int millis) {

    final interval = Duration(milliseconds: millis);

    _timer = Timer.periodic(interval, (Timer timer) async {
      if (isStopped) {
        timer.cancel();
      }

      await current(channel: MethodChannelHandler.DEFAULT_CHANNEL);
      onRecordingUpdatedCallback?.call(recording);
    });
  }

  _destroyOldTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Request currently [Recording] recording to be [Paused]
  /// Note: Use [current] to get latest state of recording after [pause]
  Future<Recording> pause() async {
    var result = await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(NativeMethodCall.PAUSE.methodName);
    _updateRecording(result, "Recording paused", "Recording not paused");

    onPausedCallback?.call(recording);

    return recording;
  }

  /// Request currently [Paused] recording to continue
  Future<Recording> resume() async {
    var result = MethodChannelHandler.METHOD_CHANNEL.invokeMethod(NativeMethodCall.RESUME.methodName);
    _updateRecording(result, "Recording resumed", "Recording not resumed");

    onResumeCallback?.call(recording);

    return recording;
  }

  /// Request the recording to stop
  /// Once its stopped, the recording file will be finalized and will not start, resume, pause anymore.
  /// Stop may be called as many times as desired, but the recording will only be stopped once.
  Future<Recording> stop() async {
    var result = await MethodChannelHandler.METHOD_CHANNEL.invokeMethod(NativeMethodCall.STOP.methodName);
    _updateRecording(result, "Recording stopped", "Recording not stopped");

    onStoppedCallback?.call(recording);

    return recording;
  }
}