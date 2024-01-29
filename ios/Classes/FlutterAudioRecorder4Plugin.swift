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
    
       
    var channel = 0
    var startTime: Date!
    var settings: [String:Int]!
    
   
    override public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       
        switch call.method.toMethodCall() {
        case .CURRENT:
            result(handleCurrent(result))
        case .INIT:
            result(handleInit(call, result))
        case .START:
            result(handleStart(result))
        case .STOP:
            result(handleStop(result))
        case .PAUSE:
            result(handlePause(result))
        case .RESUME:
            result(handleResume(result))
        default:
            result(super.handle(<#T##call: FlutterMethodCall##FlutterMethodCall#>, result: <#T##FlutterResult##FlutterResult##(Any?) -> Void#>))
        }
    }
    
    
    private func handleInit(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        
        if (recorderState == RecorderState.UNSET || recorderState == RecorderState.INITIALIZED || recorderState == RecorderState.STOPPED) {
            resetRecorder()
            
            let dic = call.arguments as! [String : Any]
            
            filepath = dic[NamedArguments.FILEPATH] as? String ?? ""
            ext = dic[NamedArguments.EXTENSION] as? String ?? ""
            sampleRateHz = dic[NamedArguments.SAMPLE_RATE_HZ] as? Int ?? 16000
            bufferSizeBytes = AudioRecord.getMinBufferSize(sampleRateHz, CHANNEL_IN_MONO, ENCODING_PCM_16BIT)
            recorderState = if (filepath != nil && !filepath.isEmpty) RecorderState.INITIALIZED else RecorderState.UNSET
            message = "Recorder initialized"
        } else {
            result(FlutterError(code: "", message: "Recorder not re-initialized", details: "RecorderState is not UNSET, INITIALIZED, or STOPPED - i.e. currectly recording"))
        }
        
 
        
    
        startTime = Date()
        if (filepath == "") {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            filepath = documentsPath + "/" + String(Int(startTime.timeIntervalSince1970)) + ".m4a"
            print("path: " + (filepath ?? ""))
        }
        
        settings = [
            AVFormatIDKey: getOutputFormatFromString(ext),
            AVSampleRateKey: sampleRateHz,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            #if swift(>=4.2)
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
            #else
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
            #endif
            
            try AVAudioSession.sharedInstance().setActive(true)
            recorder = try AVAudioRecorder(url: URL(string: filepath)!, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            
            let duration = Int(recorder.currentTime * 1000)
            status = "initialized"
            
            var recordingResult = [String : Any]()
            recordingResult["duration"] = duration
            recordingResult["path"] = filepath
            recordingResult["audioFormat"] = ext
            recordingResult["peakPower"] = 0
            recordingResult["averagePower"] = 0
            recordingResult["isMeteringEnabled"] = recorder.isMeteringEnabled
            recordingResult["status"] = status
            
            result(recordingResult)
        } catch {
            print("fail")
            result(FlutterError(code: "", message: "Failed to init", details: error))
        }
    }
        
    private func handleCurrent(_ result: @escaping FlutterResult) {
        print("current")
        if (recorder == nil) {
            result(nil)
        } else {
            let dic = call.arguments as! [String : Any]
            channel = dic["channel"] as? Int ?? 0
            
            recorder.updateMeters()
            let duration = Int(recorder.currentTime * 1000)
            var recordingResult = [String : Any]()
            recordingResult["duration"] = duration
            recordingResult["path"] = filepath
            recordingResult["audioFormat"] = ext
            recordingResult["peakPower"] = recorder.peakPower(forChannel: channel)
            recordingResult["averagePower"] = recorder.averagePower(forChannel: channel)
            recordingResult["isMeteringEnabled"] = recorder.isMeteringEnabled
            recordingResult["status"] = status
            result(recordingResult)
        }
    }
    
    private func handleStart(_ result: @escaping FlutterResult) {
        print("start")
        
        if status == "initialized" {
            recorder.record()
            status = "recording"
        }
        
        result(nil)
    }
    
    private func handlePause(_ result: @escaping FlutterResult) {
   
        if (recorder == nil) {
            result(nil)
        }
        
        if recorderState == RecorderState.RECORDING {
            recorder.pause()
            status = "paused"
        }
        
        result(nil)
    }
    
    private func handleResume(_ result: @escaping FlutterResult) {
        print("resume")
        
        
        if audioRecorder == nil {
            result(nil)
        }
        
        if status == "paused" {
            recorder.record()
            status = "recording"
        }
        
        result(nil)
    }
    
    private func handleStop(_ result: @escaping FlutterResult) {
        print("stop")
        
        if recorder == nil || status == "unset" {
            result(nil)
        } else {
            audioRecorder.updateMeters()
            
            let duration = Int(recorder.currentTime * 1000)
            status = "stopped"
            
            var recordingResult = [String : Any]()
            recordingResult["duration"] = duration
            recordingResult["path"] = filepath
            recordingResult["audioFormat"] = ext
            recordingResult["peakpower"] = recorder.peakPower(forChannel: channel)
            recordingResult["averagePower"] = recorder.averagePower(forChannel: channel)
            recordingResult["isMeteringEnabled"] = recorder.isMeteringEnabled
            recordingResult["status"] = status
            
            recorder.stop()
            recorder = nil
            result(recordingResult)
        }
    }

    
    
    // developer.apple.com/documentation/coreaudiotypes/coreaudiotype_constants/1572096-audio_data_format_identifiers
    func getOutputFormatFromString(_ format : String) -> Int {
        switch format {
        case ".mp4", ".aac", ".m4a":
            return Int(kAudioFormatMPEG4AAC)
        case ".wav":
            return Int(kAudioFormatLinearPCM)
        default:
            return Int(kAudioFormatMPEG4AAC)
        }
    }
    
    private func resetRecorder() {
        peakPower = DEFAULT_PEAK_POWER
        averagePower = DEFAULT_AVERAGE_POWER
        dataSizeBytes = DEFAULT_DATA_SIZE_BYTES
    }
}
