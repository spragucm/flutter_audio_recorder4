package com.tcubedstudios.flutter_audio_recorder4_example

import android.os.Bundle
import com.tcubedstudios.flutter_audio_recorder4.FlutterAudioRecorder4Plugin
import io.flutter.embedding.android.FlutterActivity

// Supports older Flutter projects that still use Android v1 embedding
class EmbeddingV1Activity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // TODO - CHRIS
        // The following doc indicates we should register this way to allow Android v1 embedding on older projects.
        // But, no idea how to get registrarFor as it's a compile error and BatteryPlus example doesn't do this
        // https://docs.flutter.dev/release/breaking-changes/plugin-api-migration
        FlutterAudioRecorder4Plugin.registerWith(registrarFor("com.tcubedstudios.flutter_audio_recorder4.FlutterAudioRecorder4Plugin"));
    }
}