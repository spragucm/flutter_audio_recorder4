extension String {
    func plus(_ str: String?) -> String? {
        //Swift is so dumb!
        //We need to "unwrap" the string if null, eh hem, "nil"
        if let concatStr = str {
            return "\(self)\(concatStr)"
        } else {
            return self
        }
    }
    
    func isNullOrEmpty() -> Bool {
        return isEmpty
    }
    
    func isNotNullOrEmpty() -> Bool {
        return !isEmpty
    }
}

extension String? {
    func isNullOrEmpty() -> Bool {
        return self == nil || self!.isEmpty
    }
    
    func isNotNullOrEmpty() -> Bool {
        return self != nil && !(self!.isEmpty)
    }
}

/*extension String? {
    func plus(_ str: String?) -> String? {
        //Swift is so dumb!
        //We need to "unwrap" the string if null, eh hem, "nil"
        if let selfStr = self {
            if let concatStr = str {
                return "\(selfStr)\(concatStr)"
            } else {
                return selfStr
            }
        } else {
            return nil
        }
    }
}*/

/*extension Bool? {
    func not() {
        return self == nil ? nil : !(self!)
    }
}*/

// Enum extensions - if your enum is a CaseIterable (which should be a default!)
extension CaseIterable{
    var name: String {
        get {
            return "\(self)"
        }
    }
}