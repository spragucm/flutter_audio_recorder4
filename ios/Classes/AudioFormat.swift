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

extension String? {
    func toAudioFormat() -> AudioFormat? {
        var cases = AudioExtension.allCases;
        var first = cases.first { $0.ext == self }
        var audioFormat = first?.audioFormat
        
        return AudioExtension.allCases.first { $0.ext == self }?.audioFormat
    }
}
