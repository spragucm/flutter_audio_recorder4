import Foundation

enum RecorderState {
    
    case UNSET
    case INITIALIZED
    case RECORDING
    case PAUSED
    case STOPPED
    
    var value: String {
        get {
            switch self {
            case .INITIALIZED:
                return "initialized"
            case .RECORDING:
                return "recording"
            case .PAUSED:
                return "paused"
            case .STOPPED:
                return "stopped"
            default://.UNSET
                return "unset"
            }
        }
    }
}
