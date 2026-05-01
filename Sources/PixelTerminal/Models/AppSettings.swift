import Foundation
import AppKit

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: "fontName") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    @Published var cursorBlink: Bool {
        didSet { UserDefaults.standard.set(cursorBlink, forKey: "cursorBlink") }
    }
    @Published var shell: String {
        didSet { UserDefaults.standard.set(shell, forKey: "shell") }
    }
    @Published var scrollback: Int {
        didSet { UserDefaults.standard.set(scrollback, forKey: "scrollback") }
    }
    @Published var copyOnSelect: Bool {
        didSet { UserDefaults.standard.set(copyOnSelect, forKey: "copyOnSelect") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.fontName = defaults.string(forKey: "fontName") ?? "SFMono-Regular"
        self.fontSize = defaults.object(forKey: "fontSize") as? Double ?? 13.0
        self.cursorBlink = defaults.object(forKey: "cursorBlink") as? Bool ?? true
        self.shell = defaults.string(forKey: "shell") ?? (ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
        self.scrollback = defaults.object(forKey: "scrollback") as? Int ?? 10000
        self.copyOnSelect = defaults.object(forKey: "copyOnSelect") as? Bool ?? false
    }

    var resolvedFont: NSFont {
        NSFont(name: fontName, size: fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
}
