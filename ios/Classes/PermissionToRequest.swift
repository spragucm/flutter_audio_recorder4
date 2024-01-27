import Foundation

struct PermissionToRequest {
    
    static let NO_CONSTRAINT: Int? = nil
    
    var permission: String
    var minSdk: Int? = NO_CONSTRAINT
    var maxSdk: Int? = NO_CONSTRAINT
}
