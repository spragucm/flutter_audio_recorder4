import Flutter
import AVFoundation

public class PlatformInfoHandlerPlugin : ActivityAwarePlugin {
    
    override public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method.toMethodCall() {
        case .GET_PLATFORM_VERSION:
            getPlatformVersion(result)
        default:
            super.handle(call, result: result)
        }
    }
    
    private func getPlatformVersion(_ result: @escaping FlutterResult) {
//        let appVersionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
//        let appBuildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        
        let osVersion = getOsVersion()
        let appVersion = getAppVersionAndBuild()
        let appName = getAppName()
        
        result("iOS \(osVersion)")
    }
}
