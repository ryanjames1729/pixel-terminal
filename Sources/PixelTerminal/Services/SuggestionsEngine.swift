import Foundation

struct Suggestion: Identifiable {
    let id = UUID()
    let text: String
    var detail: String?
    var source: Source

    enum Source { case history, builtin, correction, claude }
}

// MARK: – Built-in sub-command knowledge

private let builtinSubcommands: [String: [String]] = [
    "git": ["add", "commit", "push", "pull", "checkout", "branch", "status", "log",
            "diff", "merge", "rebase", "fetch", "stash", "clone", "init", "remote",
            "tag", "reset", "restore", "switch", "cherry-pick"],
    "npm": ["install", "run", "start", "build", "test", "publish", "update",
            "uninstall", "audit", "ls", "init", "ci", "outdated"],
    "yarn": ["add", "install", "run", "start", "build", "test", "remove", "upgrade", "create"],
    "npx": ["create-react-app", "create-next-app", "create-vite", "tsx", "ts-node"],
    "docker": ["run", "build", "ps", "stop", "start", "pull", "push", "exec",
               "logs", "rm", "rmi", "images", "network", "volume", "compose"],
    "kubectl": ["get", "apply", "delete", "describe", "logs", "exec", "port-forward",
                "scale", "rollout", "create", "patch"],
    "brew": ["install", "uninstall", "update", "upgrade", "search", "info", "list",
             "cleanup", "doctor", "tap", "untap", "services"],
    "swift": ["build", "run", "test", "package", "repl"],
    "cargo": ["build", "run", "test", "check", "add", "update", "doc", "fmt", "clippy"],
    "gh": ["pr", "issue", "repo", "gist", "workflow", "release", "auth"],
    "pip": ["install", "uninstall", "list", "show", "freeze"],
    "python3": ["-m", "-c", "--version"],
    "vercel": ["dev", "build", "deploy", "env", "ls", "logs", "link", "pull"],
    "claude": ["--help", "--version", "--continue", "--resume", "--dangerously-skip-permissions"],
    "clear": []
]

private let commonCorrections: [String: String] = [
    "gti": "git", "giit": "git",
    "sl": "ls", "dc": "cd",
    "claer": "clear", "clera": "clear",
    "exti": "exit"
]

// MARK: – History persistence

private let historyKey = "commandHistory"
private let maxHistorySize = 5000

struct HistoryEntry: Codable {
    let command: String
    let cwd: String
    let timestamp: TimeInterval
    let exitCode: Int
}

actor HistoryStore {
    static let shared = HistoryStore()
    private(set) var entries: [HistoryEntry] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = saved
        }
    }

    func add(command: String, cwd: String, exitCode: Int) {
        entries.append(HistoryEntry(command: command, cwd: cwd,
                                    timestamp: Date().timeIntervalSince1970,
                                    exitCode: exitCode))
        if entries.count > maxHistorySize {
            entries.removeFirst(entries.count - maxHistorySize)
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func getEntries() -> [HistoryEntry] { entries }
}

// MARK: – Levenshtein

private func levenshtein(_ a: String, _ b: String) -> Int {
    let aArr = Array(a), bArr = Array(b)
    var dp = Array(0...bArr.count)
    for i in 1...aArr.count {
        var prev = dp[0]
        dp[0] = i
        for j in 1...bArr.count {
            let temp = dp[j]
            dp[j] = aArr[i-1] == bArr[j-1] ? prev : 1 + min(prev, min(dp[j], dp[j-1]))
            prev = temp
        }
    }
    return dp[bArr.count]
}

// MARK: – Engine

struct SuggestionsEngine {
    static func suggest(input: String, cwd: String, claudeApiKey: String? = nil) async -> [Suggestion] {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let history = await HistoryStore.shared.getEntries()
        let freqMap = Dictionary(history.map { ($0.command, 1) }, uniquingKeysWith: +)
        let maxFreq = Double(freqMap.values.max() ?? 1)
        let now = Date().timeIntervalSince1970

        var results: [Suggestion] = []
        var seen = Set<String>()

        // 1. History matches
        let historyMatches = history
            .filter { $0.command != input && ($0.command.hasPrefix(input) || $0.command.contains(input)) }
            .map { entry -> (HistoryEntry, Double) in
                let ageDays = (now - entry.timestamp) / 86400
                let recency = exp(-ageDays / 7)
                let freq = Double(freqMap[entry.command] ?? 0) / maxFreq
                let dirMatch: Double = entry.cwd == cwd ? 1.0 : entry.cwd.hasPrefix(cwd) ? 0.6 : 0.2
                let prefixBonus: Double = entry.command.hasPrefix(input) ? 0.3 : 0
                let score = recency * 0.35 + freq * 0.3 + dirMatch * 0.2 + prefixBonus * 0.15
                return (entry, score)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(6)

        for (entry, score) in historyMatches {
            if !seen.contains(entry.command) {
                seen.insert(entry.command)
                let freq = freqMap[entry.command] ?? 0
                results.append(Suggestion(text: entry.command,
                                          detail: freq > 1 ? "\(freq)×" : nil,
                                          source: .history))
                _ = score
            }
        }

        // 2. Built-in sub-commands
        let parts = input.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2, let subs = builtinSubcommands[parts[0]] {
            for s in subs {
                let full = "\(parts[0]) \(s)"
                if full.hasPrefix(input) && !seen.contains(full) {
                    seen.insert(full)
                    results.append(Suggestion(text: full, source: .builtin))
                }
            }
        } else if parts.count == 1 {
            for cmd in builtinSubcommands.keys.sorted() where cmd.hasPrefix(input) {
                if !seen.contains(cmd) {
                    seen.insert(cmd)
                    results.append(Suggestion(text: cmd, source: .builtin))
                }
            }
        }

        // 3. Typo correction
        if let first = parts.first, first.count >= 2 {
            if let correction = commonCorrections[first.lowercased()] {
                let corrected = ([correction] + parts.dropFirst()).joined(separator: " ")
                if !seen.contains(corrected) {
                    seen.insert(corrected)
                    results.append(Suggestion(text: corrected, detail: "did you mean \(correction)?", source: .correction))
                }
            } else {
                for cmd in builtinSubcommands.keys where levenshtein(first, cmd) == 1 {
                    let corrected = ([cmd] + parts.dropFirst()).joined(separator: " ")
                    if !seen.contains(corrected) {
                        seen.insert(corrected)
                        results.append(Suggestion(text: corrected, detail: "did you mean \(cmd)?", source: .correction))
                    }
                }
            }
        }

        // 4. Plain-language network phrase matching
        let inputLower = input.lowercased()
        for entry in networkPhraseMap {
            if entry.phrases.contains(where: { inputLower.contains($0) || $0.contains(inputLower) }) {
                if !seen.contains(entry.command) {
                    seen.insert(entry.command)
                    results.insert(Suggestion(text: entry.command, detail: "network", source: .builtin),
                                   at: min(results.count, 1))
                }
                break
            }
        }

        // 5. Claude API augmentation (non-blocking, fires in parallel)
        if let apiKey = claudeApiKey, !apiKey.isEmpty, results.count < 4 {
            let recentCmds = history.suffix(15).map { $0.command }
            if let claudeSuggestions = await claudeSuggest(input: input, cwd: cwd,
                                                           recentCommands: recentCmds,
                                                           apiKey: apiKey) {
                for text in claudeSuggestions {
                    if !seen.contains(text) {
                        seen.insert(text)
                        results.insert(Suggestion(text: text, detail: "AI", source: .claude),
                                       at: min(results.count, 2))
                    }
                }
            }
        }

        return Array(results.prefix(4))
    }

    // MARK: – Claude API call

    private static func claudeSuggest(input: String, cwd: String,
                                      recentCommands: [String],
                                      apiKey: String) async -> [String]? {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url, timeoutInterval: 4)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let recentList = recentCommands.suffix(10).joined(separator: "\n")
        let userMessage = """
            Partial command: \(input)
            Current directory: \(cwd)
            Recent commands:
            \(recentList)
            """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 256,
            "system": "You are a terminal command completion engine. Given a partial command, current directory, and recent command history, suggest the most likely completions. Respond with ONLY a JSON array of strings (max 3 items). No explanation, no markdown, no code fences. Example: [\"git commit -m\", \"git push origin main\"]",
            "messages": [["role": "user", "content": userMessage]]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data

        guard let (responseData, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else { return nil }

        // Parse JSON array from the response text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let arrayData = trimmed.data(using: .utf8),
              let suggestions = try? JSONSerialization.jsonObject(with: arrayData) as? [String] else { return nil }

        return suggestions
    }
}
