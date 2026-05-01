import SwiftUI

private extension Color {
    static let sbBg = Color(red: 0.024, green: 0.024, blue: 0.063).opacity(0.98)
    static let sbText = Color(red: 0.478, green: 0.518, blue: 0.600)
    static let sbAccent = Color(red: 0.506, green: 0.549, blue: 0.973)
    static let sbGreen = Color(red: 0.431, green: 0.906, blue: 0.718)
    static let sbYellow = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let sbOrange = Color(red: 0.984, green: 0.573, blue: 0.188)
    static let sbPurple = Color(red: 0.655, green: 0.545, blue: 0.980)
    static let sbRed    = Color(red: 0.973, green: 0.443, blue: 0.443)
    static let sbTeal   = Color(red: 0.176, green: 0.831, blue: 0.745)
}

private struct Pill: View {
    let content: AnyView
    var body: some View {
        content
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.sbText)
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .overlay(Divider().opacity(0.3), alignment: .trailing)
    }
}

struct StatusBarView: View {
    @ObservedObject var tabManager: TabManager
    let onOpenSettings: () -> Void

    var body: some View {
        let tab = tabManager.activeTab
        let git = tab?.gitStatus

        HStack(spacing: 0) {
            // Left: git, cwd, shell
            if let branch = git?.branch {
                Pill(content: AnyView(
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 9))
                        Text(branch).foregroundColor(.sbPurple)
                        if let ahead = git?.ahead, ahead > 0 {
                            Text("↑\(ahead)").foregroundColor(.sbYellow).fontWeight(.semibold)
                        }
                        if let behind = git?.behind, behind > 0 {
                            Text("↓\(behind)").foregroundColor(.sbRed).fontWeight(.semibold)
                        }
                        if git?.dirty == true {
                            Circle().fill(Color.sbOrange).frame(width: 5, height: 5)
                        }
                    }
                ))
            }

            if let cwd = tab?.cwd {
                Pill(content: AnyView(
                    Text(shortenPath(cwd)).foregroundColor(.sbTeal)
                ))
            }

            if let shell = tab?.shellType {
                Pill(content: AnyView(Text(shell)))
            }

            Spacer()

            // Right: size + settings
            Pill(content: AnyView(
                Text("\(tabManager.termSize.cols)×\(tabManager.termSize.rows)")
            ))

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
                    .foregroundColor(.sbText)
                    .frame(width: 32, height: 26)
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
        }
        .frame(height: 26)
        .background(Color.sbBg)
        .overlay(Divider().opacity(0.2), alignment: .top)
    }

    private func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var p = path
        if p.hasPrefix(home) {
            p = "~" + p.dropFirst(home.count)
        }
        if p.count > 50 {
            let parts = p.components(separatedBy: "/").filter { !$0.isEmpty }
            if parts.count > 3 {
                return "…/" + parts.suffix(2).joined(separator: "/")
            }
        }
        return p
    }
}
