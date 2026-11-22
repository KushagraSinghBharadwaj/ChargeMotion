import Foundation

public enum PlaybackError: Error, LocalizedError, Sendable {
    case unsupportedFormat(String)
    case fileDoesNotExist
    case cannotCreatePlayerItem

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "The .\(ext) video format is not supported for playback."
        case .fileDoesNotExist:
            return "The selected video file could not be found."
        case .cannotCreatePlayerItem:
            return "ChargeMotion could not create a video playback item."
        }
    }
}
