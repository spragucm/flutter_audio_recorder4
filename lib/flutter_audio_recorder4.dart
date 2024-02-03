import 'package:flutter_audio_recorder4/flutter_audio_recorder4_method_channel.dart';
import 'package:flutter_audio_recorder4/permissions_handler.dart';
import 'package:flutter_audio_recorder4/recorder_state.dart';
import 'package:flutter_audio_recorder4/recording.dart';
import 'package:flutter_audio_recorder4/utils.dart';
import 'audio_metering.dart';
import 'flutter_audio_recorder4_platform_interface.dart';
import 'named_arguments.dart';
import 'audio_extension.dart';
import 'audio_format.dart';
import 'dart:async';
import 'package:file/local.dart';
import 'package:path/path.dart' as path_library;
import 'package:file/file.dart';

class FlutterAudioRecorder4 extends PermissionsHandler {

  static const int DEFAULT_IOS_AUDIO_CHANNEL = 0;

  late LocalFileSystem _localFileSystem;

  //TODO - CHRIS - get most recent recording when recorder supports multiple recordings
  //will likely need to be methods with recording name passed as arg
  Recording recording = Recording();
  String? get filepath => recording.filepath;
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
  bool get isInitialized => recording.isInitialized;
  bool get isRecording => recording.isRecording;
  bool get isPaused => recording.isPaused;
  bool get isStopped => recording.isStopped;
  bool get isPlayable => recording.isPlayable;
  File? recordingFile;
  File? playableRecordingFile;
  int? recordingFileSizeInBytes;
  int recordingUpdateIntervalMillis;

  late Future initialized;
  Function(Recording recording)? onInitializedCallback;
  Function(Recording recording)? onInitializedFailedCallback;
  Function(Recording recording)? onStartedCallback;//TODO - CHRIS - this should probably be onRecordingCallback
  Function(Recording recording)? onStartedFailedCallback;
  Function(Recording recording)? onRecordingUpdatedCallback;
  Function(Recording recording)? onRecordingUpdatedFailedCallback;
  Function(Recording recording)? onPausedCallback;
  Function(Recording recording)? onPausedFailedCallback;
  Function(Recording recording)? onResumeCallback;
  Function(Recording recording)? onResumeFailedCallback;
  Function(Recording recording)? onStoppedCallback;
  Function(Recording recording)? onStoppedFailedCallback;

  Timer? _timer;

  // .wav <---> AudioFormat.WAV
  // .mp4 .m4a .aac <---> AudioFormat.AAC
  // AudioFormat is optional, if given value, will overwrite path extension when there is conflicts.
  FlutterAudioRecorder4(
      String? filepath,
      {
        AudioFormat? audioFormat,
        int sampleRateHz = Recording.DEFAULT_SAMPLE_RATE_HZ,
        LocalFileSystem? localFileSystem,
        bool? automaticallyRequestPermissions = true,
        this.recordingUpdateIntervalMillis = 50,
        Function(bool)? hasPermissionsCallback,
        this.onInitializedCallback,
        this.onInitializedFailedCallback,
        this.onStartedCallback,
        this.onStartedFailedCallback,
        this.onRecordingUpdatedCallback,
        this.onRecordingUpdatedFailedCallback,
        this.onPausedCallback,
        this.onPausedFailedCallback,
        this.onResumeCallback,
        this.onResumeFailedCallback,
        this.onStoppedCallback,
        this.onStoppedFailedCallback
      }
  ) : super(MethodChannelFlutterAudioRecorder4.METHOD_CHANNEL_NAME, hasPermissionsCallback: hasPermissionsCallback) {
    _localFileSystem = localFileSystem ?? const LocalFileSystem();

    initialized = init(filepath, audioFormat, sampleRateHz);

    if (automaticallyRequestPermissions ?? false) hasPermissions();
  }

  Future<Recording> init(String? filepath, AudioFormat? audioFormat, int sampleRateHz) async {

    Map<String, String?> pathAndExtension = await _resolvePathAndExtension(filepath, audioFormat);
    recording.filepath = pathAndExtension[NamedArguments.FILEPATH];
    recording.extension = pathAndExtension[NamedArguments.EXTENSION] ?? Recording.DEFAULT_EXTENSION;
    recording.audioFormat = recording.extension.toAudioFormat() ?? Recording.DEFAULT_AUDIO_FORMAT;
    recording.sampleRateHz = sampleRateHz;

    await _invokeNativeInit();

    return recording;
  }

  Future<Recording> updateFilePathAndInit(String? filepath) {
    // The filepath of the recording in dart should not be written to directly.
    // Instead, init should be called so that the native recorder updates its filepath
    // and returns success if able to update and error otherwise
    return init(filepath, audioFormat, sampleRateHz);
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

  Recording _updateRecording(
      result,
      String? successMessage,
      Function(Recording recording)? successCallback,
      String? errorMessage,
      Function(Recording recording)? errorCallback
  ) {
    //There is an exception that can be thrown though, so maybe add an error state to the recording, to indicate a problem and then just return the recording
    //TODO - CHRIS - handle result.error as well as result.success
    //TODO - CHRIS - return false when result.error was received
    if (result is String) {
      recording.message = "$errorMessage $result"; //TODO - CHRIS - I'd prefer the current recording and success/error be returned in one; not string messages
      errorCallback?.call(recording);
    } else if (result is Recording){
      recording = result;
      recording.message = successMessage;
      successCallback?.call(recording);
    }

    return recording;
  }

  Future<Recording> _invokeNativeInit({int iosAudioChannel = DEFAULT_IOS_AUDIO_CHANNEL}) async {
    var result = await platform.init(recording.filepath, recording.extension, recording.sampleRateHz, iosAudioChannel);
    return _updateRecording(result, "Recorder initialized", onInitializedCallback, "Recorder not initialized", onInitializedFailedCallback);
  }

  /// Ask for current status of recording
  /// Returns the result of current recording status
  /// Metering level, Duration, Status...
  Future<Recording> current({int? channel}) async {
    var result = await FlutterAudioRecorder4Platform.instance.current();
    return _updateRecording(result, "Recording retrieved", onRecordingUpdatedCallback, "Recording not retrieved", onRecordingUpdatedFailedCallback);
  }

  /// Request an initialized recording instance to be [started]
  /// Once executed, audio recording will start working and
  /// a file will be generated in user's file system
  Future<Recording> start() async {
    _destroyOldTimer();
    _createNewTimer(recordingUpdateIntervalMillis);

    var result = await FlutterAudioRecorder4Platform.instance.start();
    return _updateRecording(result, "Recording started", onStartedCallback, "Recording not started", onStartedFailedCallback);
  }

  _createNewTimer(int millis) {

    final interval = Duration(milliseconds: millis);

    _timer = Timer.periodic(interval, (Timer timer) async {
      if (isStopped) {
        timer.cancel();
      }

      await current();
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
    var result = await FlutterAudioRecorder4Platform.instance.pause();
    return _updateRecording(result, "Recording paused", onPausedCallback, "Recording not paused", onPausedFailedCallback);
  }

  /// Request currently [Paused] recording to continue
  Future<Recording> resume() async {
    var result = await FlutterAudioRecorder4Platform.instance.resume();
    return _updateRecording(result, "Recording resumed", onResumeCallback, "Recording not resumed", onResumeFailedCallback);
  }

  /// Request the recording to stop
  /// Once its stopped, the recording file will be finalized and will not start, resume, pause anymore.
  /// Stop may be called as many times as desired, but the recording will only be stopped once.
  Future<Recording> stop() async {
    var result = await FlutterAudioRecorder4Platform.instance.stop();
    var updatedRecording = _updateRecording(result, "Recording stopped", onStoppedCallback, "Recording not stopped", onStoppedFailedCallback);

    recordingFile = _localFileSystem.toFile(recording);
    playableRecordingFile = _localFileSystem.toFile(recording, onlyIfPlayable: true);
    recordingFileSizeInBytes = await _localFileSystem.fileSizeInBytes(recording);

    return updatedRecording;
  }
}