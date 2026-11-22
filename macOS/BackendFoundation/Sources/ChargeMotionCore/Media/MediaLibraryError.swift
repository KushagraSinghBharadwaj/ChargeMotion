import Foundation

public enum MediaLibraryError: Error, LocalizedError, Sendable {
    case unsupportedFormat(String)
    case sourceIsNotAFile
    case fileAlreadyManaged
    case assetNotFound(UUID)
    case unsafeLibraryPath

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let fileExtension):
            return "The .\(fileExtension) format is not supported. Import an MP4, MOV, or M4V video."
        case .sourceIsNotAFile:
            return "The selected item is not a readable file."
        case .fileAlreadyManaged:
            return "This file is already inside the ChargeMotion media library."
        case .assetNotFound(let id):
            return "The media item \(id.uuidString) could not be found."
        case .unsafeLibraryPath:
            return "The media item points outside the managed library."
        }
    }
}
