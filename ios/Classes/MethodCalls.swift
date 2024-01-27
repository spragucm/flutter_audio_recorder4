import Foundation

enum MethodCalls: CaseIterable {
    
    case HAS_PERMISSIONS
    case REVOKE_PERMISSIONS
    case INIT
    case CURRENT
    case START
    case PAUSE
    case RESUME
    case STOP
    
    var methodName: String {
        get {
            switch self {
            case .HAS_PERMISSIONS:
                return "hasPermissions"
            case .REVOKE_PERMISSIONS:
                return "revokePermissions"
            case .INIT:
                return "init"
            case .CURRENT:
                return "current"
            case .START:
                return "start"
            case .PAUSE:
                return "pause"
            case .RESUME:
                return "resume"
            default:
                return "stop"
            }
        }
    }
}

extension String? {
    func toMethodCall() -> String? {
        return MethodCalls.AllCases().first { $0.methodName == self }?.methodName
    }
}
