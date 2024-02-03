import AVFoundation

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
                return ".m4a"
            }
        }
    }
    
    var audioFormatIdentifier: Int {
        return ext.getAudioDataFormatIdentifierFromFormat()
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

extension String {
    
    func toAudioExtension() -> AudioExtension? {
        return AudioExtension.allCases.first { $0.ext == self }
    }
    
    // developer.apple.com/documentation/coreaudiotypes/coreaudiotype_constants/1572096-audio_data_format_identifiers
    func getAudioDataFormatIdentifierFromFormat() -> Int {
        switch self {
        case ".mp4", ".aac", ".m4a":
            return Int(kAudioFormatMPEG4AAC)
        case ".wav":
            return Int(kAudioFormatLinearPCM)
        default:
            return Int(kAudioFormatMPEG4AAC)
        }
    }
}
