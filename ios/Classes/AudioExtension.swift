import Foundation

enum AudioExtension: CaseIterable {
    
    case AAC
    case M4A
    case MP4
    case WAV
    
    var ext: String {
        get {
            switch self {
            case .AAC:
                return ".aac"
            case .MP4:
                return ".mp4"
            case .WAV:
                return ".wav"
            default: //M4A
                return ""
            }
        }
    }
    
    var audioFormat: AudioFormat {
        get {
            switch self {
            case .AAC:
                return AudioFormat.AAC
            case .MP4:
                return AudioFormat.AAC
            case .WAV:
                return AudioFormat.WAV
            default:// M4A
                return AudioFormat.AAC
            }
        }
    }
}

extension String? {
    func toAudioFormat() -> AudioFormat? {
        return AudioExtension.AllCases().first { $0.ext == self }?.audioFormat
    }
}
