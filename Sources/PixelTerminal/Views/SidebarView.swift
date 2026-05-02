import SwiftUI

// MARK: – Sidebar palette

private extension Color {
    static let sbBg        = Color(red: 0.027, green: 0.027, blue: 0.059)
    static let sbItem      = Color(red: 0.071, green: 0.071, blue: 0.133)
    static let sbItemHover = Color(red: 0.086, green: 0.086, blue: 0.157)
    static let sbAccent    = Color(red: 0.506, green: 0.549, blue: 0.973)
    static let sbText      = Color(red: 0.886, green: 0.910, blue: 0.961)
    static let sbMuted     = Color(red: 0.420, green: 0.455, blue: 0.545)
    static let sbDim       = Color(red: 0.255, green: 0.275, blue: 0.345)
    static let sbGreen     = Color(red: 0.431, green: 0.906, blue: 0.718)
    static let sbYellow    = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let sbRed       = Color(red: 0.973, green: 0.443, blue: 0.443)
    static let sbOrange    = Color(red: 0.984, green: 0.573, blue: 0.188)
    static let sbPurple    = Color(red: 0.655, green: 0.545, blue: 0.980)
}

// MARK: – Pulsing dot for running state

struct RunningDot: View {
    let isRunning: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            if isRunning {
                Circle()
                    .fill(Color.sbGreen.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: pulse)
            }
            Circle()
                .fill(isRunning ? Color.sbGreen : Color.sbDim)
                .frame(width: 7, height: 7)
        }
        .frame(width: 14, height: 14)
        .onAppear { if isRunning { pulse = true } }
        .onChange(of: isRunning) { running in
            pulse = running
        }
    }
}

// MARK: – Git badge

struct GitBadge: View {
    let status: GitStatus

    var body: some View {
        HStack(spacing: 4) {
            if let branch = status.branch {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9))
                    .foregroundColor(.sbPurple)
                Text(branch)
                    .foregroundColor(.sbPurple)
                    .lineLimit(1)
            }
            if status.ahead > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .semibold))
                    Text("\(status.ahead)")
                }
                .foregroundColor(.sbYellow)
            }
            if status.behind > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .semibold))
                    Text("\(status.behind)")
                }
                .foregroundColor(.sbRed)
            }
            if status.dirty {
                Circle()
                    .fill(Color.sbOrange)
                    .frame(width: 5, height: 5)
            }
        }
        .font(.system(size: 10, design: .monospaced))
    }
}

// MARK: – Single session row

struct SessionRow: View {
    let tab: TabInfo
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    private var shortPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var p = tab.cwd
        if p.hasPrefix(home) { p = "~" + p.dropFirst(home.count) }
        return p
    }

    private var dirName: String {
        let name = URL(fileURLWithPath: tab.cwd).lastPathComponent
        return name.isEmpty ? "~" : name
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Running indicator — aligned to first line of text
            RunningDot(isRunning: tab.isRunning)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                // Directory name + Claude badge
                HStack(spacing: 6) {
                    Text(dirName)
                        .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                        .foregroundColor(isActive ? .sbText : .sbMuted)
                        .lineLimit(1)
                    if tab.isClaudeSession {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8, weight: .semibold))
                            Text("claude")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.820, green: 0.580, blue: 0.980))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.820, green: 0.580, blue: 0.980).opacity(0.15))
                        .cornerRadius(4)
                    }
                }

                // Full path (small, muted)
                Text(shortPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.sbDim)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Git status
                if let git = tab.gitStatus, git.branch != nil || git.ahead > 0 || git.behind > 0 {
                    GitBadge(status: git)
                        .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)

            // Close button — only on hover
            if isHovered || isActive {
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.sbDim)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive
                    ? Color.sbAccent.opacity(0.14)
                    : (isHovered ? Color.sbItemHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isActive ? Color.sbAccent.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

// MARK: – Full sidebar

struct SidebarView: View {
    @ObservedObject var tabManager: TabManager
    let onNewSession: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top padding — clears macOS traffic lights (44pt)
            Spacer().frame(height: 44)

            // Header
            HStack {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.sbDim)
                    .kerning(1.2)

                let activeCount = tabManager.tabs.filter { $0.isRunning }.count
                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.sbGreen)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.sbGreen.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Spacer()
                Button(action: onNewSession) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.sbMuted)
                        .frame(width: 24, height: 24)
                        .background(Color.sbItemHover)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("New Session (⌘T)")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Session list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(tabManager.tabs) { tab in
                        SessionRow(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabId,
                            onSelect: { tabManager.setActive(id: tab.id) },
                            onClose: { tabManager.closeTab(id: tab.id) }
                        )
                    }
                }
                .padding(.bottom, 12)
            }

            Spacer()

            // Footer: new session button (bigger target)
            Button(action: onNewSession) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.square.dashed")
                        .font(.system(size: 13))
                    Text("New Session")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color.sbMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.sbItemHover)
                .cornerRadius(7)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .frame(width: 230)
        .background(Color.sbBg)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}
