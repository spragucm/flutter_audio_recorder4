import 'dart:async';
import 'dart:io' as io;

import 'package:audioplayers/audioplayers.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder4/audio_format.dart';
import 'package:flutter_audio_recorder4/flutter_audio_recorder4.dart';
import 'package:flutter_audio_recorder4/recorder_state.dart';
import 'package:flutter_audio_recorder4/recording.dart';
import 'package:flutter_audio_recorder4_example/utils.dart';
import 'package:restart_app/restart_app.dart';
import 'dart:developer' as developer;

import 'package:path_provider/path_provider.dart';

class RecorderExample extends StatefulWidget {

  final LocalFileSystem localFileSystem;

  const RecorderExample({super.key, localFileSystem}) : localFileSystem = localFileSystem ?? const LocalFileSystem();

  @override
  State<StatefulWidget> createState() => RecorderExampleState(localFileSystem: localFileSystem);
}

//TODO - CHRIS - to make it easier to use this library, make a super State class that users can inherit so that they can inherit the boiler plate
class RecorderExampleState extends State<RecorderExample> {

  late FlutterAudioRecorder4 recorder;

  String platformVersion = "";
  String libraryVersion = "TODO";

  bool hasPermissions = false;
  bool isRevoked = false;

  RecorderExampleState({LocalFileSystem? localFileSystem }) {
    recorder = FlutterAudioRecorder4(
        null,                                           // No need to avoid a null filepath; recorder won't break, but it won't initialize either
        audioFormat: AudioFormat.AAC,
        localFileSystem: localFileSystem,
        automaticallyRequestPermissions: true,          // This is true by default, just highlighting it so that callers can disable if desired
        hasPermissionsCallback: hasPermissionsCallback  // If a callback was passed into CTOR, it will be triggered with the result, so no need to wait
    );
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    // Waiting until init() to determine path because ctor isn't async
    io.Directory? appDocDirectory = await getAppDocDirectory();
    if (appDocDirectory != null) {
      recorder.filepath = '${appDocDirectory.path}/flutter_audio_recorder_${DateTime.now().millisecondsSinceEpoch}';
    } else {
      showSnackBarMessage("Could not get app doc directory");
    }
    updatePlatformVersion();
  }

  Future<void> updatePlatformVersion() async {
    var platformVersion = await recorder.getPlatformVersion();
    setState((){
      this.platformVersion = platformVersion;
    });
  }

  Future<void> hasPermissionsCallback(hasPermissions) async {
    var message = hasPermissions ? "All permissions accepted." : "You mus accept all permissions";
    showSnackBarMessage("$message. RecorderState:${recorder.recorderState}");

    setState(() {
      this.hasPermissions = hasPermissions;
    });
  }

  showSnackBarMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message))
  );

  //TODO - CHRIS - there is no reason to wait to init the recorder until permissions are accepted
  //Instead, when the user goes to record, show the snackbar notification
  /*try {
  await recorder.initialized;
  await updateRecording();
  } catch(exception) {
  developer.log("Initialized exception:$exception");
  }// Recorder should now be INITIALIZED if everything is working*/

  void start() async {
    try {
      await recorder.start();

    showSnackBarMessage(await recorder.start());

      //TODO - CHRIS - this ticker should be in recorder and caller should be able to set a callback if they're interested
      const tick = Duration(milliseconds: 50);
      Timer.periodic(tick, (Timer timer) async {
        if (recorder.isStopped) {
          timer.cancel();
        }

        await updateRecording();
      });

    } catch(exception) {
      developer.log("RecorderExample start exception:$exception");
    }
  }

  void resume() async {
    showSnackBarMessage(await recorder.resume());
    triggerStateRefresh();
  }

  void pause() async {
    showSnackBarMessage(await recorder.pause());
    triggerStateRefresh();
  }

  void stop() async {
    var recording = await recorder.stop();

    var filepath = recording.filepath;
    var duration = recording.duration;

    developer.log("Stop recording: path:$filepath");
    developer.log("Stop recording: duration:$duration");

    if (filepath == null) {
      developer.log("Stop recording and filepath is null");
    } else {
      File? playableRecordingFile = recorder.playableRecordingFile;
      var fileSizeInBytes = await recorder.recordingFileSizeInBytes;
      developer.log("Stop recording and file length is $fileSizeInBytes");
    }
    triggerStateRefresh();
  }

  //TODO - CHRIS - might need to change fields for real
  void triggerStateRefresh() => setState((){});

  //TODO - CHRIS - I'd prefer that the recorder also have the audio playback, but that might not be desirable for everybody
  void onPlayAudio() async {
    var playableRecordingFile = recorder.playableRecordingFile;
    if (playableRecordingFile == null) {//TODO - CHRIS - snackbar the user
      developer.log("OnPlayAudio filepath is null");
    } else {
      await AudioPlayer().play(DeviceFileSource(playableRecordingFile.path));//TODO - CHRIS - for the initial migration, don't add this dependency to the library; then, for 2.0.0, add to library
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: buildEdgeInsets(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            buildPermissionsRow(),
            buildVersionsRow(),
            buildRecorderRow(),
            buildRecorderStateRow(),
            buildAveragePowerRow(),
            buildPeakPowerRow(),
            buildFilepathRow(),
            buildAudioFormatRow(),
            buildMeteringEnabledRow(),
            buildExtensionRow(),
            buildDurationRow()
          ]
        )
      )
    );
  }

  Widget buildPermissionsRow() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text("Has permissions:$hasPermissions"),
      buildGetPermissionsButton(),
      buildRevokePermissionsButton()
    ],
  );

  Widget buildVersionsRow() => Text('Library version $libraryVersion running on platform version $platformVersion');

  Widget buildRecorderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[

        if (recorder.needsToBeInitialized)...[
          buildInitializeButton()
        ],
        if (recorder.isRecording)...[
          buildStopButton()
        ],
        if (recorder.playableRecordingFile != null) ... [
          buildPlayButton()
        ]
      ]
    );
  }

  EdgeInsets buildEdgeInsets() => const EdgeInsets.all(8.0);

  Widget buildVerticalSpacer() => const SizedBox(width: 8);

  Widget buildInitializeButton() => TextButton(
      onPressed: () async {
        await recorder.initialized;
      },
      style: buildButtonStyle(),
      child: Text("Stop", style: buildButtonTextStyle())
  );

  Widget buildStopButton() => TextButton(
      onPressed: stop,
      style: buildButtonStyle(),
      child: Text("Stop", style: buildButtonTextStyle())
  );

  Widget buildGetPermissionsButton() => TextButton(
    onPressed: () async {
      FlutterAudioRecorder4.hasPermissions;// No need to await; all is handled by hasPermissionsCallback
    },
    style: buildButtonStyle(),
    child: Text("Request Permissions", style: buildButtonTextStyle())
  );

  Widget buildRevokePermissionsButton() => TextButton(
      onPressed: () async {
        isRevoked = await FlutterAudioRecorder4.revokePermissions ?? false;
        setState((){
          hasPermissions = !isRevoked;
        });
        await Restart.restartApp();//Must restart for revoked permissions to take affect
      },
      style: buildButtonStyle(),
      child: Text(isRevoked ? "Revoked Permissions. Must restart app." : "Revoke Permissions", style: buildButtonTextStyle())
  );

  Widget buildPlayButton() => TextButton(
    onPressed: onPlayAudio,
    style: buildButtonStyle(),
    child: Text("Play", style: buildButtonTextStyle())
  );

  Widget buildNextRecorderStateButton() {
    return Padding(
      padding: buildEdgeInsets(),
      child: TextButton(
        onPressed: (){
          switch(recorder.recorderState) {//TODO - CHRIS - it's probably best to have each button and logic for when to show the button instead of a button like this
            case RecorderState.INITIALIZED: start();
            case RecorderState.RECORDING: pause();
            case RecorderState.PAUSED: resume();
            case RecorderState.STOPPED: init();
            default: break;
          }
        },
        style: buildButtonStyle(),
        child: Text(recorder.recorderState.nexStateDisplayText, style: buildButtonTextStyle())
      )
    );
  }

  ButtonStyle buildButtonStyle() => ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(
        Colors.blueAccent.withOpacity(0.5),
      )
  );

  TextStyle buildButtonTextStyle() => const TextStyle(color: Colors.white);

  Widget buildFilepathRow() => Text("Filepath:${recorder.filepath}");
  Widget buildExtensionRow() => Text("Extension:${recorder.extension}");
  Widget buildDurationRow() => Text("Duration:${recorder.duration}");
  Widget buildAudioFormatRow() => Text("Audio Format:${recorder.audioFormat}");
  Widget buildRecorderStateRow() => Text("Recorder State:${recorder.recorderState}");
  Widget buildPeakPowerRow() => Text("Peak Power:${recorder.peakPower}");
  Widget buildAveragePowerRow() => Text("Average Power:${recorder.averagePower}");
  Widget buildMeteringEnabledRow() => Text("Metering Enabled:${recorder.meteringEnabled}");
}