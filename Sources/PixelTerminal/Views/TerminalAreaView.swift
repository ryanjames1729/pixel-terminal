import SwiftUI
import AppKit
import SwiftTerm

// MARK: – Container that owns all live terminal views

class TerminalContainerView: NSView {
    private var terminals: [String: LocalProcessTerminalView] = [:]
    private var delegates: [String: TerminalTabDelegate] = [:]
    private weak var tabManager: TabManager?
    private var settings: AppSettings
    private var eventMonitor: Any?

    init(tabManager: TabManager, settings: AppSettings) {
        self.tabManager = tabManager
        self.settings = settings
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.055, green: 0.055, blue: 0.102, alpha: 0.97).cgColor
        setupEventMonitor()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        if let monitor = eventMonitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: – Event monitor for Tab/Escape interception + input tracking

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let tm = self.tabManager,
                  self.isTerminalFirstResponder() else {
                return event
            }

            // Intercept Tab if suggestions are visible
            if event.keyCode == 48 {
                let handled = MainActor.assumeIsolated { tm.acceptTopSuggestion() }
                if handled { return nil }  // consume — don't send Tab to shell
            }

            // Intercept Escape if suggestions are visible
            if event.keyCode == 53 {
                let hasSuggestions = MainActor.assumeIsolated { !tm.suggestions.isEmpty }
                if hasSuggestions {
                    MainActor.assumeIsolated { tm.suggestions = [] }
                    return nil
                }
            }

            // Track input for suggestion engine
            let chars = event.characters ?? ""
            MainActor.assumeIsolated {
                switch event.keyCode {
                case 36, 76:       tm.appendInput("\r")
                case 51:           tm.appendInput("\u{7f}")
                case 3:            tm.appendInput("\u{03}")  // Ctrl+C
                case 126, 125:     tm.appendInput("\u{1b}[A")  // arrow (clears input)
                default:
                    if !chars.isEmpty { tm.appendInput(chars) }
                }
            }

            return event
        }
    }

    private func isTerminalFirstResponder() -> Bool {
        guard let fr = window?.firstResponder as? NSView else { return false }
        return terminals.values.contains(where: { $0 === fr || fr.isDescendant(of: $0) })
    }

    // MARK: – Terminal lifecycle

    func addTerminal(tabId: String, cwd: String) {
        guard terminals[tabId] == nil else { return }

        let terminal = LocalProcessTerminalView(frame: bounds)
        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminal.isHidden = true
        addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.topAnchor.constraint(equalTo: topAnchor),
            terminal.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminal.leadingAnchor.constraint(equalTo: leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        applyTheme(to: terminal)

        let delegate = TerminalTabDelegate(tabId: tabId, tabManager: tabManager!)
        terminal.processDelegate = delegate
        delegates[tabId] = delegate

        let (shellExec, shellArgs, shellEnv) = buildShellConfig()
        terminal.startProcess(
            executable: shellExec,
            args: shellArgs,
            environment: shellEnv,
            execName: nil,
            currentDirectory: cwd
        )

        terminals[tabId] = terminal
    }

    func setActive(tabId: String) {
        for (tid, term) in terminals {
            term.isHidden = tid != tabId
        }
        if let active = terminals[tabId] {
            window?.makeFirstResponder(active)
        }
    }

    func removeTerminal(tabId: String) {
        terminals[tabId]?.terminate()
        terminals[tabId]?.removeFromSuperview()
        terminals.removeValue(forKey: tabId)
        delegates.removeValue(forKey: tabId)
    }

    /// Clear current line (Ctrl+U) and type the suggestion text
    func sendSuggestion(_ text: String, tabId: String) {
        guard let terminal = terminals[tabId] else { return }
        let ctrlU = "\u{15}"
        let bytes = Array((ctrlU + text).utf8)
        terminal.process.send(data: ArraySlice(bytes))
    }

    /// Type a command and press Enter
    func sendCommand(_ command: String, tabId: String) {
        guard let terminal = terminals[tabId] else { return }
        let bytes = Array((command + "\n").utf8)
        terminal.process.send(data: ArraySlice(bytes))
    }

    // MARK: – Theme

    private func applyTheme(to terminal: LocalProcessTerminalView) {
        terminal.font = settings.resolvedFont
        terminal.nativeBackgroundColor = NSColor(red: 0.055, green: 0.055, blue: 0.102, alpha: 0.97)
        terminal.nativeForegroundColor = NSColor(red: 0.886, green: 0.910, blue: 0.961, alpha: 1)
        terminal.caretColor = NSColor(red: 0.506, green: 0.549, blue: 0.973, alpha: 1)
        terminal.selectedTextBackgroundColor = NSColor(red: 0.506, green: 0.549, blue: 0.973, alpha: 0.25)
        terminal.optionAsMetaKey = true
    }

    // MARK: – Shell config (args + environment) with integration injected

    /// Returns (args, environment) for the configured shell.
    /// Injects a custom prompt and OSC 7 CWD reporting for both zsh and bash.
    private func buildShellConfig() -> (executable: String, args: [String], env: [String]) {
        let shellPath = settings.shell
        let shellName = URL(fileURLWithPath: shellPath).lastPathComponent
        let home      = FileManager.default.homeDirectoryForCurrentUser.path
        let user      = ProcessInfo.processInfo.userName

        var baseEnv = ProcessInfo.processInfo.environment
        baseEnv["TERM"]                 = "xterm-256color"
        baseEnv["COLORTERM"]            = "truecolor"
        baseEnv["TERM_PROGRAM"]         = "PixelTerminal"
        baseEnv["TERM_PROGRAM_VERSION"] = "0.1.0"

        // Greeting printed once when shell starts (true-color ANSI)
        let greeting = """
        printf '\\033[38;2;129;140;248m  ▸ pixel-terminal\\033[0m \\033[38;2;74;85;104mv0.1.0\\033[0m\\n'
        printf '\\033[38;2;44;50;74m  ──────────────────────────────────────────────────\\033[0m\\n'
        printf '  \\033[38;2;74;85;104m⌘T\\033[0m \\033[38;2;110;231;183mnew session\\033[0m   \\033[38;2;74;85;104m⌘⇧C\\033[0m \\033[38;2;167;139;250mclaude code\\033[0m   \\033[38;2;74;85;104m⌘⇧N\\033[0m \\033[38;2;96;165;250mnetwork cmds\\033[0m\\n'
        printf '  \\033[38;2;44;50;74mTab\\033[0m \\033[38;2;44;50;74maccepts suggestions\\033[0m  ·  \\033[38;2;44;50;74mEsc\\033[0m \\033[38;2;44;50;74mdismisses\\033[0m\\n'
        printf '\\033[38;2;44;50;74m  ──────────────────────────────────────────────────\\033[0m\\n'
        printf '\\n'
        """

        switch shellName {

        // ── zsh ────────────────────────────────────────────────────────────
        case "zsh":
            let tempDir = NSTemporaryDirectory() + "PixelTerminalZsh"
            let rc = """
            # ── Pixel Terminal shell integration ──────────────────────────
            # 1. Source the user's real ~/.zshrc (all aliases / themes intact)
            if [ -f "\(home)/.zshrc" ]; then
              ZDOTDIR="\(home)" source "\(home)/.zshrc"
            fi

            # 2. Emit OSC 7 before every prompt so the sidebar tracks CWD
            _pixel_cwd() {
              printf '\\033]7;file://%s%s\\033\\\\' "$(hostname -f 2>/dev/null || hostname)" "$PWD"
            }
            autoload -Uz add-zsh-hook 2>/dev/null
            add-zsh-hook precmd _pixel_cwd

            # 3. Custom prompt  pixel-terminal:user ~/dir >
            PROMPT='%F{#818cf8}pixel-terminal%f:%F{#60a5fa}\(user)%f %F{#6ee7b7}%1~%f %F{#818cf8}>%f '
            RPROMPT=''

            # 4. Greeting
            \(greeting)
            """
            try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
            try? rc.write(toFile: tempDir + "/.zshrc", atomically: true, encoding: .utf8)
            baseEnv["ZDOTDIR"] = tempDir
            return (shellPath, [], baseEnv.map { "\($0.key)=\($0.value)" })

        // ── bash ───────────────────────────────────────────────────────────
        case "bash":
            let rcPath      = NSTemporaryDirectory() + "pixel_terminal_bashrc"
            let wrapperPath = NSTemporaryDirectory() + "pixel_terminal_bash_wrapper.sh"
            let rc = """
            # ── Pixel Terminal shell integration ──────────────────────────
            # 1. Source the user's ~/.bash_profile or ~/.bashrc
            for f in "\(home)/.bash_profile" "\(home)/.bashrc"; do
              [ -f "$f" ] && source "$f" && break
            done

            # 2. Emit OSC 7 before every prompt so the sidebar tracks CWD
            _pixel_cwd() {
              printf '\\033]7;file://%s%s\\033\\\\' "$(hostname -f 2>/dev/null || hostname)" "$PWD"
            }
            PROMPT_COMMAND='_pixel_cwd'

            # 3. Custom prompt  pixel-terminal:user ~/dir >
            PS1='\\[\\e[38;2;129;140;248m\\]pixel-terminal\\[\\e[0m\\]:\\[\\e[38;2;96;165;250m\\]\(user)\\[\\e[0m\\] \\[\\e[38;2;110;231;183m\\]\\W\\[\\e[0m\\] \\[\\e[38;2;129;140;248m\\]>\\[\\e[0m\\] '

            # 4. Greeting
            \(greeting)
            """
            // Wrapper sets BASH_SILENCE_DEPRECATION_WARNING before exec'ing bash,
            // which is the only way to suppress it before bash's main() runs.
            let wrapper = "#!/bin/sh\nexport BASH_SILENCE_DEPRECATION_WARNING=1\nexec \(shellPath) --rcfile \(rcPath)\n"
            try? rc.write(toFile: rcPath, atomically: true, encoding: .utf8)
            try? wrapper.write(toFile: wrapperPath, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperPath)
            return (wrapperPath, [], baseEnv.map { "\($0.key)=\($0.value)" })

        // ── fish ───────────────────────────────────────────────────────────
        case "fish":
            // fish reads ~/.config/fish/config.fish; we can set FISH_TERM_PROGRAM
            // and rely on fish's built-in OSC 7 support (fish 3.2+)
            baseEnv["FISH_TERM_PROGRAM"] = "PixelTerminal"
            return (shellPath, [], baseEnv.map { "\($0.key)=\($0.value)" })

        default:
            return (shellPath, [], baseEnv.map { "\($0.key)=\($0.value)" })
        }
    }
}

// MARK: – SwiftTerm delegate per tab

class TerminalTabDelegate: LocalProcessTerminalViewDelegate {
    let tabId: String
    weak var tabManager: TabManager?

    init(tabId: String, tabManager: TabManager) {
        self.tabId = tabId
        self.tabManager = tabManager
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        Task { @MainActor in tabManager?.updateSize(tabId: tabId, cols: newCols, rows: newRows) }
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        Task { @MainActor in tabManager?.updateTitle(tabId: tabId, title: title) }
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let raw = directory else { return }
        let cwd = raw.hasPrefix("file://") ? String(raw.dropFirst(7)) : raw
        Task { @MainActor in tabManager?.updateCwd(tabId: tabId, cwd: cwd) }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        Task { @MainActor in tabManager?.setRunning(tabId: tabId, running: false) }
    }
}

// MARK: – SwiftUI bridge

struct TerminalAreaView: NSViewRepresentable {
    @ObservedObject var tabManager: TabManager
    let settings: AppSettings

    func makeNSView(context: Context) -> TerminalContainerView {
        let view = TerminalContainerView(tabManager: tabManager, settings: settings)
        tabManager.terminalContainer = view
        return view
    }

    func updateNSView(_ nsView: TerminalContainerView, context: Context) {
        for tab in tabManager.tabs {
            nsView.addTerminal(tabId: tab.id, cwd: tab.cwd)
        }
        if let activeId = tabManager.activeTabId {
            nsView.setActive(tabId: activeId)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {}
}
