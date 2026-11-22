import Foundation

/// A video file imported into ChargeMotion's managed media library.
public struct MediaAsset: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var filename: String
    public var displayName: String
    public let fileExtension: String
    public let importedAt: Date
    public let fileSize: Int64

    public init(
        id: UUID = UUID(),
        filename: String,
        displayName: String,
        fileExtension: String,
        importedAt: Date = .now,
        fileSize: Int64
    ) {
        self.id = id
        self.filename = filename
        self.displayName = displayName
        self.fileExtension = fileExtension.lowercased()
        self.importedAt = importedAt
        self.fileSize = fileSize
    }
}
