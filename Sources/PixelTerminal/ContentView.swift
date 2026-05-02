import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var tabManager = TabManager()
    @StateObject private var settings = AppSettings.shared
    @State private var showSettings = false
    @State private var showNetworkPalette = false
    @State private var suggestionTask: Task<Void, Never>? = nil

    var body: some View {
        HStack(spacing: 0) {
            // ── Left sidebar ──────────────────────────────────────────────
            SidebarView(tabManager: tabManager, onNewSession: addTab)

            // ── Terminal area + suggestions + status bar ──────────────────
            VStack(spacing: 0) {
                TerminalAreaView(tabManager: tabManager, settings: settings)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Permanent suggestions dock — always reserved so the terminal never reflows.
                // Empty when there's nothing to suggest; populated as the user types.
                SuggestionsDock(
                    suggestions: tabManager.suggestions,
                    selectedIndex: $tabManager.selectedSuggestionIndex,
                    onAccept: { text in
                        guard let tabId = tabManager.activeTabId else { return }
                        tabManager.suggestions = []
                        tabManager.currentInput = text
                        tabManager.terminalContainer?.sendSuggestion(text, tabId: tabId)
                    },
                    onDismiss: { tabManager.suggestions = [] }
                )

                StatusBarView(tabManager: tabManager, onOpenSettings: { showSettings = true })
            }
        }
        .overlay {
            if showNetworkPalette {
                NetworkPaletteView(
                    onInsert: { command in
                        guard let tabId = tabManager.activeTabId else { return }
                        tabManager.terminalContainer?.sendSuggestion(command, tabId: tabId)
                    },
                    onDismiss: { showNetworkPalette = false }
                )
                .transition(.opacity)
            }
        }
        .background(Color(red: 0.047, green: 0.047, blue: 0.094))
        .ignoresSafeArea()
        .onAppear(perform: onAppear)
        .onChange(of: tabManager.currentInput) { newInput in
            scheduleSuggestions(for: newInput)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTab)) { _ in addTab() }
        .onReceive(NotificationCenter.default.publisher(for: .closeTab)) { _ in
            if let id = tabManager.activeTabId { tabManager.closeTab(id: id) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in showSettings = true }
        .onReceive(NotificationCenter.default.publisher(for: .launchClaudeCode)) { _ in launchClaudeCode() }
        .onReceive(NotificationCenter.default.publisher(for: .openNetworkPalette)) { _ in
            withAnimation(.easeOut(duration: 0.15)) { showNetworkPalette = true }
        }
    }

    // MARK: – Setup

    private func onAppear() {
        configureWindow()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        _ = tabManager.addTab(cwd: home)
    }

    private func configureWindow() {
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.keyWindow else { return }
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            // Disabled — was hijacking click-and-drag selection inside the terminal.
            // The window can still be moved by the title bar / sidebar header.
            window.isMovableByWindowBackground = false
            window.backgroundColor = NSColor(red: 0.027, green: 0.027, blue: 0.059, alpha: 0.97)
        }
    }

    // MARK: – Tab management

    private func addTab() {
        let cwd = tabManager.activeTab?.cwd
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        _ = tabManager.addTab(cwd: cwd)
    }

    private func launchClaudeCode() {
        let cwd = tabManager.activeTab?.cwd
            ?? FileManager.default.homeDirectoryForCurrentUser.path
        let tabId = tabManager.addTab(cwd: cwd)
        tabManager.markAsClaudeSession(tabId: tabId)
        // Give the shell a moment to initialize before sending the command
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                tabManager.terminalContainer?.sendCommand("claude", tabId: tabId)
            }
        }
    }

    // MARK: – Suggestions

    private func scheduleSuggestions(for input: String) {
        suggestionTask?.cancel()
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else {
            tabManager.suggestions = []
            return
        }
        let cwd = tabManager.activeTab?.cwd ?? ""
        let apiKey = CredentialStore.get(key: "anthropic")
        suggestionTask = Task {
            let s = await SuggestionsEngine.suggest(input: input, cwd: cwd, claudeApiKey: apiKey)
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.1)) {
                        tabManager.suggestions = s
                        tabManager.selectedSuggestionIndex = 0
                    }
                }
            }
        }
    }
}
