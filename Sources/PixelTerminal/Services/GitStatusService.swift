import Foundation

actor GitStatusService {
    static let shared = GitStatusService()

    func getStatus(directory: String) async -> GitStatus? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }

        // Quick check: is this a git repo?
        guard let _ = await runGit(["-C", directory, "rev-parse", "--git-dir"]) else {
            return nil
        }

        // Get branch + ahead/behind + dirty in one call
        let statusOut = await runGit(["-C", directory, "status", "--short", "--branch"]) ?? ""
        let lines = statusOut.components(separatedBy: "\n")
        let branchLine = lines.first ?? ""

        var branch: String? = nil
        var ahead = 0
        var behind = 0
        let dirty = lines.dropFirst().contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Parse "## main...origin/main [ahead 2, behind 1]"
        if branchLine.hasPrefix("## ") {
            let info = String(branchLine.dropFirst(3))
            // Branch name is before "..."
            let parts = info.components(separatedBy: "...")
            branch = parts.first.map { String($0) }

            // Parse ahead/behind counts from the bracket portion
            if let rest = parts.dropFirst().first {
                let pattern = try? NSRegularExpression(pattern: "(ahead|behind) (\\d+)")
                let matches = pattern?.matches(in: rest, range: NSRange(rest.startIndex..., in: rest)) ?? []
                for match in matches {
                    if match.numberOfRanges == 3,
                       let typeRange = Range(match.range(at: 1), in: rest),
                       let numRange = Range(match.range(at: 2), in: rest) {
                        let type = String(rest[typeRange])
                        let num = Int(rest[numRange]) ?? 0
                        if type == "ahead" { ahead = num }
                        if type == "behind" { behind = num }
                    }
                }
            }
        }

        return GitStatus(branch: branch, ahead: ahead, behind: behind, dirty: dirty)
    }

    private func runGit(_ args: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: process.terminationStatus == 0
                    ? String(data: data, encoding: .utf8)
                    : nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
