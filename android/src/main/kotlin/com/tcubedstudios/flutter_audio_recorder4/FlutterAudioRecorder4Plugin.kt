package com.tcubedstudios.flutter_audio_recorder4

import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.AUDIO_FORMAT
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.AVERAGE_POWER
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.DURATION
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.EXTENSION
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.FILEPATH
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.METERING_ENABLED
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.PEAK_POWER
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.RECORDER_STATE
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.SAMPLE_RATE_HZ
import android.Manifest.permission.RECORD_AUDIO
import android.Manifest.permission.WRITE_EXTERNAL_STORAGE
import android.media.AudioFormat.CHANNEL_IN_MONO
import android.media.AudioFormat.ENCODING_PCM_16BIT
import android.media.AudioRecord
import android.media.MediaRecorder.AudioSource.MIC
import android.os.Build.VERSION_CODES
import com.tcubedstudios.flutter_audio_recorder4.AudioFormat.Companion.toAudioFormat
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.*
import com.tcubedstudios.flutter_audio_recorder4.MethodCalls.Companion.toMethodCall
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.FILEPATH_TEMP
import com.tcubedstudios.flutter_audio_recorder4.NamedArguments.MESSAGE
import com.tcubedstudios.flutter_audio_recorder4.RecorderState.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import java.io.File
import java.io.FileInputStream
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import kotlin.math.abs
import kotlin.math.ln

//TODO - CHRIS - use a state machine
//https://github.com/Tinder/StateMachine -> supports kotlin and swift
//Init, start, stop, etc all need to look at the state and return error if request is made in wrong state

//Registrar is passed for Android plugin v1 compatibility
class FlutterAudioRecorder4Plugin(
    registrar: Registrar? = null,
    methodChannel: MethodChannel? = null
) : PermissionRequestHandlerPlugin(registrar, methodChannel) {

  //TODO - CHRIS
  // If recorder is ever expected to operate in a background service, implement ServiceAware interface.

  //region Defaults
  companion object {
    private const val DEFAULT_SAMPLE_RATE_HZ = 16000L
    private const val DEFAULT_PEAK_POWER = -120.0
    private const val DEFAULT_AVERAGE_POWER = -120.0
    private const val DEFAULT_DATA_SIZE_BYTES = 0L
    private const val DEFAULT_BUFFER_SIZE_BYTES = 1024
    private const val DEFAULT_METERING_ENABLED = true
    private const val RECORDER_BPP: Byte = 16;
    private const val IOS_POWER_LEVEL_FACTOR = 0.25// iOS factor : to match iOS power level
  }
  //endregion

  //region Fields
  override val permissionsToRequest = listOf(
    PermissionToRequest(RECORD_AUDIO),
    PermissionToRequest(WRITE_EXTERNAL_STORAGE, maxSdk = VERSION_CODES.LOLLIPOP_MR1)//WR_EX_ST was removed in M, so last allowed version is LP_MR1
  )

  private var sampleRateHz = DEFAULT_SAMPLE_RATE_HZ
  private var dataSizeBytes = DEFAULT_DATA_SIZE_BYTES
  private var peakPower = DEFAULT_PEAK_POWER
  private var averagePower = DEFAULT_AVERAGE_POWER
  private var recorderState = UNSET
  private var bufferSizeBytes = DEFAULT_BUFFER_SIZE_BYTES
  private var fileOutputStream: FileOutputStream? = null
  private var recordingThread: Thread? = null
  private var recorder: AudioRecord? = null
  private var filepath: String? = null
  private var extension: String? = null
  private var meteringEnabled = DEFAULT_METERING_ENABLED
  private var message: String? = null

  private val filepathTemp: String?
    get() = filepath?.plus(".temp")
  private val duration: Int
    get() = (dataSizeBytes / (sampleRateHz * 2 * 1)).toInt()
  private val recording: Map<String, Any?>
    get() = mapOf(
      FILEPATH to filepath,
      FILEPATH_TEMP to filepathTemp,
      EXTENSION to extension,
      DURATION to duration * 1000,
      AUDIO_FORMAT to extension?.toAudioFormat()?.name,
      RECORDER_STATE to recorderState.value,
      METERING_ENABLED to meteringEnabled,
      PEAK_POWER to peakPower,
      AVERAGE_POWER to averagePower,
      SAMPLE_RATE_HZ to sampleRateHz,
      MESSAGE to message
    )

  private var processAudioStream = false
  //endregion

  //region Handle method calls from flutter
  override fun onMethodCall(call: MethodCall, result: Result) {
    when(call.method.toMethodCall()) {
      INIT -> handleInit(call, result)
      CURRENT -> handleCurrent(result)
      START -> handleStart(result)
      PAUSE -> handlePause(result)
      RESUME -> handleResume(result)
      STOP -> handleStop(result)
      else -> super.onMethodCall(call, result)
    }
  }
  //endregion

  //region Recorder
  private fun handleInit(call: MethodCall, result: Result) {
    if (recorderState == UNSET || recorderState == INITIALIZED || recorderState == STOPPED) {
      resetRecorder()

      filepath = call.argument<Any?>(FILEPATH)?.toString()
      extension = call.argument<Any?>(EXTENSION)?.toString()
      sampleRateHz = call.argument<Any?>(SAMPLE_RATE_HZ)?.toString()?.toLong() ?: sampleRateHz
      bufferSizeBytes = AudioRecord.getMinBufferSize(sampleRateHz.toInt(), CHANNEL_IN_MONO, ENCODING_PCM_16BIT)
      recorderState = if (filepath.isNullOrBlank().not() && extension.isNullOrBlank().not()) INITIALIZED else UNSET
      message = "Recorder initialized"
      result.success(recording)
    } else {
      result.error("", "Recorder not re-initialized", "RecorderState is not UNSET, INITIALIZED, or STOPPED - i.e. currently recording")
    }
  }

  private fun handleCurrent(result: Result) = result.success(recording)

  private fun handleStart(result: Result) {
    recorder = AudioRecord(MIC, sampleRateHz.toInt(), CHANNEL_IN_MONO, ENCODING_PCM_16BIT, bufferSizeBytes)

    try {
      fileOutputStream = FileOutputStream(filepathTemp)
    } catch (exception: FileNotFoundException) {
      result.error("", "Recorder not started", "Cannot find the file at $filepathTemp")
      return
    }

    startProcessing()
    result.success(recording)
  }

  private fun handlePause(result: Result) {
    recorderState = PAUSED
    stopProcessing(false)
    resetPowers()
    result.success(recording)
  }

  private fun handleResume(result: Result) {
    startProcessing()
    result.success(recording)
  }

  private fun handleStop(result: Result) {
    if (recorderState == STOPPED) {
      result.success(recording)
    } else {
      recorderState = STOPPED

      stopProcessing(true)

      var exception: IOException? = null
      try {
        fileOutputStream?.close()
      } catch (e: IOException) {
        exception = e
      }

      filepathTemp?.let { tempFileName ->
        filepath?.let { filePath ->
          copyWaveFile(tempFileName, filePath)
        }
      }

      deleteTempFile()

      if (exception == null) {
        result.success(recording)
      } else {
        result.error("", "Recorder stopped with error", exception.message)
      }
    }
  }

  private fun resetRecorder() {
    resetPowers()
    dataSizeBytes = DEFAULT_DATA_SIZE_BYTES
  }
  //endregion

  //region Audio Stream
  private fun startProcessing() {
    recorderState = RECORDING
    recorder?.startRecording()
    processAudioStream = true
    recordingThread = Thread({ processAudioStream() }, "Audio Processing Thread")
    recordingThread?.start()
  }

  private fun stopProcessing(doRelease: Boolean) {
    recorder?.stop()
    if (doRelease) {
      recorder?.release()
      recorder = null
    }
    processAudioStream = false
    recordingThread = null
  }

  private fun processAudioStream() {
    val audioData = ByteArray(bufferSizeBytes)

    while (processAudioStream) {
      recorder?.read(audioData, 0, audioData.size)
      dataSizeBytes += audioData.size.toLong()
      updatePowers(audioData)

      try {
        fileOutputStream?.write(audioData)
      } catch (e: IOException) {
        e.printStackTrace()
      }
    }
  }

  private fun updatePowers(byteArray: ByteArray) {
    val shortArray = byteArray.toShortArray()
    val sampleVal: Short = shortArray.last()
    val escapeRecorderStateList = arrayOf(PAUSED, STOPPED, INITIALIZED, UNSET)

    averagePower = if (sampleVal == 0.toShort() || escapeRecorderStateList.contains(recorderState)) {
      DEFAULT_AVERAGE_POWER //to match iOS silent case
    } else {
      20 * ln(abs(sampleVal.toDouble()) / 32768.0) * IOS_POWER_LEVEL_FACTOR
    }

    peakPower = averagePower
  }

  private fun resetPowers() {
    peakPower = DEFAULT_PEAK_POWER
    averagePower = DEFAULT_AVERAGE_POWER
  }
  //endregion

  //region Files
  private fun deleteTempFile() {
    filepathTemp?.let {
      val file = File(it)
      if (file.exists()) file.delete()
    }
  }

  private fun copyWaveFile(inputFileName: String, outputFileName: String) {
    try {
      val inputFileStream = FileInputStream(inputFileName)
      val outputFileStream = FileOutputStream(outputFileName)
      val totalAudioLength = inputFileStream.channel.size()
      val totalDataLength = totalAudioLength + 36

      val channels = 1
      val byteRate = RECORDER_BPP * sampleRateHz * channels / 8
      writeWaveFileHeader(outputFileStream, totalAudioLength, totalDataLength, sampleRateHz, channels, byteRate)

      val data = ByteArray(bufferSizeBytes)
      while (inputFileStream.read(data) != -1) {
        outputFileStream.write(data)
      }

      inputFileStream.close()
      outputFileStream.close()

    } catch (exception: FileNotFoundException) {
      exception.printStackTrace()
    } catch (exception: IOException) {
      exception.printStackTrace()
    }
  }

  @Throws (IOException::class)
  private fun writeWaveFileHeader(
    out: FileOutputStream,
    totalAudioLength: Long,
    totalDataLength: Long,
    longSampleRate: Long,
    channels: Int,
    byteRate: Long
  ) {
    try {
      val header = ByteArray(44)

      header[0] = 'R'.code.toByte() // RIFF/WAVE header

      header[1] = 'I'.code.toByte()
      header[2] = 'F'.code.toByte()
      header[3] = 'F'.code.toByte()
      header[4] = (totalDataLength and 0xffL).toByte()
      header[5] = (totalDataLength shr 8 and 0xffL).toByte()
      header[6] = (totalDataLength shr 16 and 0xffL).toByte()
      header[7] = (totalDataLength shr 24 and 0xffL).toByte()
      header[8] = 'W'.code.toByte()
      header[9] = 'A'.code.toByte()
      header[10] = 'V'.code.toByte()
      header[11] = 'E'.code.toByte()
      header[12] = 'f'.code.toByte() // 'fmt ' chunk

      header[13] = 'm'.code.toByte()
      header[14] = 't'.code.toByte()
      header[15] = ' '.code.toByte()
      header[16] = 16 // 4 bytes: size of 'fmt ' chunk

      header[17] = 0
      header[18] = 0
      header[19] = 0
      header[20] = 1 // format = 1

      header[21] = 0
      header[22] = channels.toByte()
      header[23] = 0
      header[24] = (longSampleRate and 0xffL).toByte()
      header[25] = (longSampleRate shr 8 and 0xffL).toByte()
      header[26] = (longSampleRate shr 16 and 0xffL).toByte()
      header[27] = (longSampleRate shr 24 and 0xffL).toByte()
      header[28] = (byteRate and 0xffL).toByte()
      header[29] = (byteRate shr 8 and 0xffL).toByte()
      header[30] = (byteRate shr 16 and 0xffL).toByte()
      header[31] = (byteRate shr 24 and 0xffL).toByte()
      header[32] = (channels * RECORDER_BPP.toInt() shr 3).toByte()
      header[33] = (channels * RECORDER_BPP.toInt() shr 11).toByte()
      header[34] = RECORDER_BPP // bits per sample

      header[35] = 0
      header[36] = 'd'.code.toByte()
      header[37] = 'a'.code.toByte()
      header[38] = 't'.code.toByte()
      header[39] = 'a'.code.toByte()
      header[40] = (totalAudioLength and 0xffL).toByte()
      header[41] = (totalAudioLength shr 8 and 0xffL).toByte()
      header[42] = (totalAudioLength shr 16 and 0xffL).toByte()
      header[43] = (totalAudioLength shr 24 and 0xffL).toByte()

      out.write(header, 0, 44)
    } catch (exception: IOException) {
      throw exception
    }
  }
  //endregion
}
