import Flutter
import AVFoundation

public class PermissionRequestListenerActivityPlugin: ActivityAwarePlugin {
    
    public var hasPermissions = false
 
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasPermissions":
            print("hasPermissions")
            
            
            var permission: AVAudioSession.RecordPermission
            #if (swift(>=4.2))
                permission = AVAudioSession.sharedInstance().recordPermission
            #else
            permission = AVAudioSession.sharedInstance().recordPermission()
            #endif
            
            switch permission {
                case .granted:
                    print("granted")
                    hasPermissions = true
                    result(hasPermissions)
                    break
                case .denied:
                    print("denied")
                    hasPermissions = false
                    result(hasPermissions)
                    break
                case .undetermined:
                    print("undetermined")
                    
                    AVAudioSession.sharedInstance().requestRecordPermission(){
                        [unowned self] allowed in DispatchQueue.main.async {
                            if allowed {
                                self.hasPermissions = true
                                print("undetermined true")
                                result(self.hasPermissions)
                            } else {
                                self.hasPermissions = false
                                print("undetermined false")
                                result(self.hasPermissions)
                            }
                        }
                    }
                    break
                default:
                    result(hasPermissions)
                    break
            }
        default:
            print("default")
            result(FlutterMethodNotImplemented)
        }
    }
}
