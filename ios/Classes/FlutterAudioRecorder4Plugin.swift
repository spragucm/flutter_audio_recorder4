import Flutter
import UIKit
import AVFoundation

public class FlutterAudioRecorder4Plugin: PermissionRequestListenerActivityPlugin, AVAudioRecorderDelegate {

    private static let DEFAULT_SAMPLE_RATE_HZ = 16000
    private static let DEFAULT_PEAK_POWER = -120.0
    private static let DEFAULT_AVERAGE_POWER = -120.0
    private static let DEFAULT_DATA_SIZE_BYTES = 0
    private static let DEFAULT_BUFFER_SIZE_BYTES = 1024
    private static let DEFAULT_METERING_ENABLED = true
    private static let DEFAULT_RECORDER_BPP: UInt8 = 16
    private static let DEFAULT_IOS_AUDIO_CHANNEL = 0
    private static let IOS_POWER_LEVEL_FACTOR = 0.25// iOS factor : to match iOS power level
    
    
    private var sampleRateHz = DEFAULT_SAMPLE_RATE_HZ
    private var dataSizeBytes = DEFAULT_DATA_SIZE_BYTES
    private var peakPower = DEFAULT_PEAK_POWER
    private var averagePower = DEFAULT_AVERAGE_POWER
    private var recorderState = RecorderState.UNSET
    private var bufferSizeBytes = DEFAULT_BUFFER_SIZE_BYTES
    private var recorder: AVAudioRecorder?
    private var filepath: String?
    private var ext: String?
    private var meteringEnabled = DEFAULT_METERING_ENABLED
    private var message: String?
    private var iosAudioChannel: Int = DEFAULT_IOS_AUDIO_CHANNEL
    
    private var filepathTemp: String? {
        get {
            return filepath?.plus(".temp")
        }
    }
    
    private var duration: Int = 0
    
    private var recording: [String : Any?] {
        get {
            [
                NamedArguments.FILEPATH: filepath,
                NamedArguments.FILEPATH_TEMP: [filepathTemp, "bla"].compactMap { $0 }.joined(separator:""),
                NamedArguments.EXTENSION: ext,
                NamedArguments.DURATION: duration,
                NamedArguments.AUDIO_FORMAT: ext?.toAudioFormat()?.name,
                NamedArguments.RECORDER_STATE: recorderState.value,
                NamedArguments.METERING_ENABLED: meteringEnabled,
                NamedArguments.PEAK_POWER: peakPower,
                NamedArguments.AVERAGE_POWER: averagePower,
                NamedArguments.SAMPLE_RATE_HZ: sampleRateHz,
                NamedArguments.MESSAGE: message
            ]
        }
    }
    
    private var doProcessAudioStream = false
       
    var startTime: Date!
  
   
    override public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        var methodCall = call.method.toMethodCall()
        
        switch call.method.toMethodCall() {
        case .CURRENT:
            handleCurrent(result)
            break
        case .INIT:
            handleInit(call, result)
            break
        case .START:
            handleStart(result)
            break
        case .STOP:
            handleStop(result)
            break
        case .PAUSE:
            handlePause(result)
            break
        case .RESUME:
            handleResume(result)
            break
        default:
            super.handle(call, result: result)
            break
        }
    }
    
    
    private func handleInit(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        if (recorderState == RecorderState.UNSET || recorderState == RecorderState.INITIALIZED || recorderState == RecorderState.STOPPED) {
            resetRecorder()
            
            let dic = call.arguments as! [String : Any]
            
            filepath = dic[NamedArguments.FILEPATH] as? String
            if (filepath == "") {
                var startTime = Date()
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                filepath = documentsPath + "/" + String(Int(startTime.timeIntervalSince1970)) + ".m4a"
                print("path: " + (filepath ?? ""))
            }
            
            ext = dic[NamedArguments.EXTENSION] as? String
            sampleRateHz = dic[NamedArguments.SAMPLE_RATE_HZ] as? Int ?? sampleRateHz
            recorderState = filepath.isNotNullOrEmpty() && ext.isNotNullOrEmpty() ? RecorderState.INITIALIZED : RecorderState.UNSET
            message = "Recorder initialized"
            iosAudioChannel = dic[NamedArguments.IOS_AUDIO_CHANNEL] as? Int ?? FlutterAudioRecorder4Plugin.DEFAULT_IOS_AUDIO_CHANNEL
            result(recording)
        } else {
            result(FlutterError(code: "", message: "Recorder not re-initialized", details: "RecorderState is not UNSET, INITIALIZED, or STOPPED - i.e. currectly recording"))
        }
    }
        
    private func handleCurrent(_ result: @escaping FlutterResult) {
        result(recording)
    }
    
    private func handleStart(_ result: @escaping FlutterResult) {
        do {
            
            var audioSession = AVAudioSession.sharedInstance()
            
            #if swift(>=4.2)
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            #else
            try audioSession.setCategory(AVAudioSession.CategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            #endif
            
            try audioSession.setActive(true)
            
            if let urlFilepath = filepath {
                
                var settings = [
                    AVFormatIDKey: ext?.toAudioExtension()?.audioFormatIdentifier,
                    AVSampleRateKey: sampleRateHz,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                                
                recorder = try AVAudioRecorder(url: URL(string: urlFilepath)!, settings: settings)
                recorder?.delegate = self
                recorder?.isMeteringEnabled = (recording[NamedArguments.METERING_ENABLED] as? Bool) ?? FlutterAudioRecorder4Plugin.DEFAULT_METERING_ENABLED
                recorder?.prepareToRecord()
               
                startProcessing()
                result(recording)
            } else {
                result(FlutterError(code: "", message: "Recorder not started", details: "Problem with filepath"))
            }
        } catch {
            result(FlutterError(code: "", message: "Recorder not started", details: error))
        }
    }
    
    private func handlePause(_ result: @escaping FlutterResult) {
        recorderState = RecorderState.PAUSED
        stopProcessing(doRelase: false)
        resetPowers()
        result(recording)
    }
    
    private func handleResume(_ result: @escaping FlutterResult) {
        startProcessing()
        result(recording)
    }
    
    private func handleStop(_ result: @escaping FlutterResult) {
        if recorderState == RecorderState.STOPPED {
            result(recording)
        } else {
            recorderState = RecorderState.STOPPED
            stopProcessing(doRelase: true)
        
            result(recording)
        }
    }

    private func resetRecorder() {
        resetPowers()
        dataSizeBytes = FlutterAudioRecorder4Plugin.DEFAULT_DATA_SIZE_BYTES
    }
    
    private func startProcessing() {
        recorderState = RecorderState.RECORDING
        recorder?.record()
        doProcessAudioStream = true
        //TODO - CHRIS - recordingThread = Thread({ processAudioStream() }, "Audio Processing Thread")
        //TODO - CHRIS - recordingThread?.start()
    }
    
    private func stopProcessing(doRelase: Bool) {
        if (doRelase) {
            recorder?.stop()
            recorder = nil
        } else {
            recorder?.pause()
        }
        doProcessAudioStream = false
        
        //TODO - CHRIS - recordingThread = null
    }
    
    private func processAudioStream() {
        if let rec = recorder {
            updatePowers(rec)
            duration = Int(rec.currentTime * 1000)
            meteringEnabled = rec.isMeteringEnabled
        }
    }
    
    private func updatePowers(_ recorder: AVAudioRecorder) {
        recorder.updateMeters()
        peakPower = Double(recorder.peakPower(forChannel: iosAudioChannel))
        averagePower = Double(recorder.averagePower(forChannel: iosAudioChannel))
    }
    
    private func resetPowers() {
        peakPower = FlutterAudioRecorder4Plugin.DEFAULT_PEAK_POWER
        averagePower = FlutterAudioRecorder4Plugin.DEFAULT_AVERAGE_POWER
    }
}
