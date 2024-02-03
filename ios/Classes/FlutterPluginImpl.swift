import Flutter
import UIKit
import AVFoundation

public class FlutterPluginImpl: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_audio_recorder4", binaryMessenger: registrar.messenger())
        let instance = FlutterAudioRecorder4Plugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(FlutterMethodNotImplemented)
    }
    
}
