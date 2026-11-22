import SwiftUI
import ChargeMotionCore

/// Connected displays (AppKit) and whether the backend window manager reports a wallpaper
/// window for each (`activeDisplayIDs`). The backend exposes nothing else per display.
struct DisplaysView: View {
    @ObservedObject private var monitor: DisplayMonitor
    @ObservedObject private var windowManager: DesktopWallpaperWindowManager
    @ObservedObject private var coordinator: WallpaperCoordinator
    @EnvironmentObject private var router: NavigationRouter

    init(ctx: ShellContext) {
        _monitor = ObservedObject(wrappedValue: ctx.displays)
        _windowManager = ObservedObject(wrappedValue: ctx.services.windowManager)
        _coordinator = ObservedObject(wrappedValue: ctx.services.coordinator)
    }

    private var activeIDs: Set<UInt32> { Set(windowManager.activeDisplayIDs) }
    private var planHasVideo: Bool { coordinator.currentPlan?.mediaID != nil && coordinator.currentPlan?.issue == nil }

    var body: some View {
        let showing = monitor.displays.filter { activeIDs.contains($0.id) }.count
        CMPage(
            title: "Displays",
            subtitle: monitor.displays.isEmpty
                ? "No displays detected."
                : "\(monitor.displays.count) connected · \(showing) showing wallpaper"
        ) {
            if monitor.displays.isEmpty {
                CMCard(level: .overlay) {
                    CMEmptyState(
                        systemImage: "display.trianglebadge.exclamationmark",
                        title: "No displays detected",
                        message: "macOS didn't report any connected displays. Connect a display or wake the Mac and this list will update."
                    )
                }
            } else {
                ForEach(Array(monitor.displays.enumerated()), id: \.element.id) { index, display in
                    card(index + 1, display)
                }
                CMCard(title: "About wallpaper windows", level: .base) {
                    Text("ChargeMotion uses one wallpaper window per display. Closing ChargeMotion's window keeps the wallpaper playing; quitting the app removes it. Per-display video choice, scaling and display-sleep pausing aren't available yet (see BACKEND-GAPS-TASKS-4-5.md).")
                        .cmText(.callout).foregroundStyle(CMColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func card(_ number: Int, _ display: DisplayInfo) -> some View {
        let active = activeIDs.contains(display.id)
        return CMCard {
            HStack(spacing: CMSpacing.sm) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: 18)).foregroundStyle(CMColor.textSecondary).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(number). \(display.name)").cmText(.headline).foregroundStyle(CMColor.textPrimary)
                    Text(display.isBuiltIn ? "Built-in display" : "External display")
                        .cmText(.callout).foregroundStyle(CMColor.textSecondary)
                }
                Spacer()
                if display.isPrimary { CMStatusChip(title: "Primary", systemImage: "menubar.rectangle", tone: .info) }
                CMStatusChip(title: active ? "Wallpaper active" : "No wallpaper window",
                             systemImage: active ? "play.rectangle.fill" : "rectangle.slash",
                             tone: active ? .accent : .neutral)
            }
            VStack(alignment: .leading, spacing: CMSpacing.xs) {
                CMInfoRow(label: "Size", value: display.pointSizeText)
                if let pixels = display.pixelSizeText { CMInfoRow(label: "Native", value: pixels) }
                if let hz = display.refreshText { CMInfoRow(label: "Refresh rate", value: hz) }
                CMInfoRow(label: "Position", value: display.positionText)
                CMInfoRow(label: "Display ID", value: String(display.id), monospaced: true)
            }
            if !active {
                if planHasVideo {
                    CMBanner(systemImage: "info.circle.fill",
                             title: "No wallpaper window is reported for this display",
                             message: "The backend creates windows when the wallpaper video loads. A display connected later may only get one when the video next changes.",
                             tone: .info)
                } else {
                    CMBanner(systemImage: "film.stack", title: "No wallpaper is active",
                             message: "Assign a video to the current power state and displays will show it.",
                             actionTitle: "Open Video Library", action: { router.navigate(to: .videoLibrary) })
                }
            }
        }
    }
}
