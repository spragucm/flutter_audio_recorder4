import Foundation

enum AudioFormat: String, CaseIterable {
    
    case AAC
    case WAV
    
    var ext: String {
        get {
            switch self {
            case .WAV:
                return ".wav"
            default://AAC
                return ".m4a"
            }
        }
    }
}

extension String {
    func toAudioFormat() -> AudioFormat? {
        return AudioExtension.AllCases().first { $0.ext == self }?.audioFormat
    }
}
