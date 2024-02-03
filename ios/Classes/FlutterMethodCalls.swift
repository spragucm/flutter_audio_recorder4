import Foundation

enum FlutterMethodCalls: CaseIterable {
    
    case HAS_PERMISSIONS
    
    var methodName: String {
        get {
            switch self {
            default: //HAS_PERMISSIONS
                return "hasPermissions"
            }
        }
    }
}

extension String? {
    func toFlutterMethodCall() -> String? {
        return FlutterMethodCalls.allCases.first { $0.methodName == self }?.methodName
    }
}
