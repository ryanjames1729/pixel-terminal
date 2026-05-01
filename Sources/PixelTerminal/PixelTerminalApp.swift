import SwiftUI
import AppKit

@main
struct PixelTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Pixel Terminal", id: "main") {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .defaultSize(width: 1200, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeTab, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Launch Claude Code") {
                    NotificationCenter.default.post(name: .launchClaudeCode, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("Network Commands…") {
                    NotificationCenter.default.post(name: .openNetworkPalette, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Clear Terminal") {
                    NotificationCenter.default.post(name: .clearTerminal, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView(settings: AppSettings.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

extension Notification.Name {
    static let newTab = Notification.Name("PixelTerminal.newTab")
    static let closeTab = Notification.Name("PixelTerminal.closeTab")
    static let clearTerminal = Notification.Name("PixelTerminal.clearTerminal")
    static let openSettings = Notification.Name("PixelTerminal.openSettings")
    static let launchClaudeCode = Notification.Name("PixelTerminal.launchClaudeCode")
    static let openNetworkPalette = Notification.Name("PixelTerminal.openNetworkPalette")
}
