import SwiftUI

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var selection: SidebarItem = .dashboard
    func navigate(to item: SidebarItem) { selection = item }
}

private struct NavigationRouterFocusedKey: FocusedValueKey {
    typealias Value = NavigationRouter
}

extension FocusedValues {
    var navigationRouter: NavigationRouter? {
        get { self[NavigationRouterFocusedKey.self] }
        set { self[NavigationRouterFocusedKey.self] = newValue }
    }
}

/// "Go" menu: Command-1 ... Command-7.
struct NavigationCommands: Commands {
    @FocusedValue(\.navigationRouter) private var router

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.element) { index, item in
                Button(item.title) { router?.navigate(to: item) }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                    .disabled(router == nil)
            }
        }
    }
}
