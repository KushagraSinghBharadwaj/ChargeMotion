import Foundation

/// Why application startup stopped. Copy says what happened and what to do next.
struct StartupFailure: Equatable {
    enum Kind: Equatable {
        case settingsUnreadable
        case settingsResetFailed
        case mediaLibraryUnavailable
    }

    let kind: Kind
    let title: String
    let message: String
    /// The underlying error description, shown as secondary detail.
    let detail: String
    /// The file involved, when known.
    let location: String?

    /// Resetting is offered only when the settings file itself is the problem.
    var canResetSettings: Bool { kind == .settingsUnreadable }

    static func settingsUnreadable(error: Error, location: String?) -> StartupFailure {
        StartupFailure(
            kind: .settingsUnreadable,
            title: "ChargeMotion can't read its settings",
            message: "The settings file couldn't be read. Retry, or reset settings to their defaults. "
                + "Resetting deletes the settings file; your imported videos are not affected.",
            detail: error.localizedDescription,
            location: location
        )
    }

    static func settingsResetFailed(error: Error, location: String?) -> StartupFailure {
        StartupFailure(
            kind: .settingsResetFailed,
            title: "ChargeMotion couldn't reset its settings",
            message: "The settings file couldn't be deleted. Check that you can modify it, then retry.",
            detail: error.localizedDescription,
            location: location
        )
    }

    static func mediaLibraryUnavailable(error: Error) -> StartupFailure {
        StartupFailure(
            kind: .mediaLibraryUnavailable,
            title: "ChargeMotion can't open your video library",
            message: "The video library folder or its catalog couldn't be opened. "
                + "Check that you have access to the ChargeMotion folder in Application Support, then retry.",
            detail: error.localizedDescription,
            location: nil
        )
    }
}
