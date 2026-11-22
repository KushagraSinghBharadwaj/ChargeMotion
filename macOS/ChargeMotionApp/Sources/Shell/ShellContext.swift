import Foundation
import Combine
import ChargeMotionCore

/// The frontend models shared by every page, created once per shell next to the single
/// `AppServices`. They read and write through the existing backend services and own no
/// media or settings storage of their own.
@MainActor
final class ShellContext: ObservableObject {
    let services: AppServices
    let displays: DisplayMonitor
    let info: MediaInfoStore
    let catalog: MediaCatalogController

    init(services: AppServices) {
        self.services = services
        self.displays = DisplayMonitor()
        let info = MediaInfoStore(library: services.mediaLibrary)
        self.info = info
        self.catalog = MediaCatalogController(
            library: services.mediaLibrary,
            settings: services.settings,
            info: info
        )
    }
}
