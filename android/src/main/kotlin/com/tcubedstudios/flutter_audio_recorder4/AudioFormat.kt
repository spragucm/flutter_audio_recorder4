package com.tcubedstudios.flutter_audio_recorder4

import com.tcubedstudios.flutter_audio_recorder4.AudioExtension.Companion.toAudioExtension

enum class AudioFormat(val extension: String) {
    AAC(".m4a"),
    WAV(".wav");

    companion object {
        fun String?.toAudioFormat() : AudioFormat? {
            return toAudioExtension()?.audioFormat
        }
    }
}