package com.tcubedstudios.flutter_audio_recorder4

enum class AudioExtension(val extension: String, val audioFormat: AudioFormat) {
    AAC(".aac", AudioFormat.AAC),
    M4A(".m4a", AudioFormat.AAC),
    MP4(".mp4", AudioFormat.AAC),
    WAV(".wav", AudioFormat.WAV);

    companion object {
        fun String?.toAudioFormat() : AudioFormat? {
            return AudioExtension.values().firstOrNull { it.extension == this }?.audioFormat
        }
    }
}