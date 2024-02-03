import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_audio_recorder4/flutter_audio_recorder4.dart';
import 'package:flutter_audio_recorder4_example/RecorderExample.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  // Be sure to add this line if `PackageInfo.fromPlatform()` is called before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  String _appName = "Unknown";
  String _packageName = "Unknown";
  String _version = "Unknown";
  String _buildNumber = "Unknown";

  String _platformVersion = "Unknown";

  final _flutterAudioRecorder4Plugin = FlutterAudioRecorder4(null);

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {

    PackageInfo packageInfo = await PackageInfo.fromPlatform();


    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _flutterAudioRecorder4Plugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _appName = packageInfo.appName;
      _packageName = packageInfo.packageName;
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(_appName),
              Text(' $_version +$_buildNumber on $_platformVersion'),
            ],
          )
        ),
        body: const SafeArea(
          child: RecorderExample()
        )
      ),
    );
  }
}
