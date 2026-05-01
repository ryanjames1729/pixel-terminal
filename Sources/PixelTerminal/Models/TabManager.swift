import Foundation
import AppKit
import Combine

struct TabInfo: Identifiable {
    let id: String
    var title: String
    var cwd: String
    var isRunning: Bool = false
    var gitStatus: GitStatus? = nil
    var shellType: String = "zsh"
    var cols: Int = 80
    var rows: Int = 24
    var isClaudeSession: Bool = false
}

struct GitStatus {
    var branch: String?
    var ahead: Int = 0   // unpushed commits
    var behind: Int = 0  // commits on remote not yet pulled
    var dirty: Bool = false
}

@MainActor
class TabManager: ObservableObject {
    @Published var tabs: [TabInfo] = []
    @Published var activeTabId: String? = nil
    @Published var currentInput: String = ""
    @Published var termSize: (cols: Int, rows: Int) = (80, 24)
    @Published var suggestions: [Suggestion] = []
    @Published var selectedSuggestionIndex: Int = 0

    /// Weak reference set by TerminalAreaView so we can send text to the active terminal
    weak var terminalContainer: TerminalContainerView?

    private var gitPollingTasks: [String: Task<Void, Never>] = [:]

    // MARK: – Tab management

    func addTab(cwd: String) -> String {
        let id = UUID().uuidString
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        tabs.append(TabInfo(id: id, title: name.isEmpty ? "~" : name, cwd: cwd))
        activeTabId = id
        startGitPolling(tabId: id, cwd: cwd)
        return id
    }

    func closeTab(id: String) {
        gitPollingTasks[id]?.cancel()
        gitPollingTasks.removeValue(forKey: id)
        terminalContainer?.removeTerminal(tabId: id)
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if activeTabId == id {
            activeTabId = tabs.isEmpty ? nil : tabs[max(0, idx - 1)].id
        }
    }

    func setActive(id: String) {
        activeTabId = id
        currentInput = ""
        suggestions = []
    }

    // MARK: – Terminal callbacks

    func setRunning(tabId: String, running: Bool) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].isRunning = running
    }

    func updateTitle(tabId: String, title: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        if !title.isEmpty && title != "Terminal" {
            tabs[idx].title = title
        }
    }

    func updateCwd(tabId: String, cwd: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        tabs[idx].cwd = cwd
        tabs[idx].title = name.isEmpty ? "~" : name
        tabs[idx].isRunning = false
        startGitPolling(tabId: tabId, cwd: cwd)
    }

    func updateSize(tabId: String, cols: Int, rows: Int) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].cols = cols
        tabs[idx].rows = rows
        if tabId == activeTabId { termSize = (cols, rows) }
    }

    func appendInput(_ chars: String) {
        switch chars {
        case "\r", "\n":
            currentInput = ""
            if let id = activeTabId { setRunning(tabId: id, running: true) }
        case "\u{7f}":
            if !currentInput.isEmpty { currentInput.removeLast() }
        case "\u{03}", "\u{04}":
            currentInput = ""
            suggestions = []
        case "\u{1b}[A", "\u{1b}[B":  // arrow keys — shell history navigation
            currentInput = ""
            suggestions = []
        default:
            if chars.unicodeScalars.allSatisfy({ $0.value >= 32 }) {
                currentInput += chars
            }
        }
    }

    func markAsClaudeSession(tabId: String) {
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].isClaudeSession = true
    }

    // MARK: – Suggestion acceptance

    /// Called by PixelTerminalView when Tab is pressed. Returns true if a suggestion was accepted.
    func acceptTopSuggestion() -> Bool {
        guard let first = suggestions.first, let tabId = activeTabId else { return false }
        suggestions = []
        currentInput = first.text
        terminalContainer?.sendSuggestion(first.text, tabId: tabId)
        return true
    }

    // MARK: – Computed

    var activeTab: TabInfo? {
        tabs.first(where: { $0.id == activeTabId })
    }

    // MARK: – Git polling

    private func startGitPolling(tabId: String, cwd: String) {
        gitPollingTasks[tabId]?.cancel()
        gitPollingTasks[tabId] = Task {
            await pollGit(tabId: tabId, cwd: cwd)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { break }
                await pollGit(tabId: tabId, cwd: cwd)
            }
        }
    }

    private func pollGit(tabId: String, cwd: String) async {
        let status = await GitStatusService.shared.getStatus(directory: cwd)
        guard let idx = tabs.firstIndex(where: { $0.id == tabId }) else { return }
        tabs[idx].gitStatus = status
    }
}
