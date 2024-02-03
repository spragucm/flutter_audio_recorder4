import Flutter
import AVFoundation

public class PermissionRequestHandlerPlugin: PlatformInfoHandlerPlugin {
    
    public var hasPermissions = false
 
    override public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method.toMethodCall() {
        case .HAS_PERMISSIONS:
            handleHasPermissions(result: result)
        default:
            super.handle(call, result: result)
        }
    }
    
    private func handleHasPermissions(result: FlutterResult) {
        var permission: AVAudioSession.RecordPermission
        #if (swift(>=4.2))
        permission = AVAudioSession.sharedInstance().recordPermission
        #else
        permission = AVAudioSession.sharedInstance().recordPermission()
        #endif
        
        switch permission {
            case .granted:
                hasPermissions = true
                break
            case .denied:
                hasPermissions = false
                break
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission(){
                    [unowned self] allowed in DispatchQueue.main.async {
                        if allowed {
                            self.hasPermissions = true
                        } else {
                            self.hasPermissions = false
                        }
                    }
                }
                break
            default:
                break
        }
        result(hasPermissions)
    }
}
