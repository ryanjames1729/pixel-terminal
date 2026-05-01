import SwiftUI

// MARK: – Color palette constants

private extension Color {
    static let midnight = Color(red: 0.031, green: 0.031, blue: 0.063)
    static let tabActive = Color(red: 0.086, green: 0.086, blue: 0.149)
    static let tabHover = Color(red: 0.071, green: 0.071, blue: 0.125)
    static let textPrimary = Color(red: 0.886, green: 0.910, blue: 0.961)
    static let textSecondary = Color(red: 0.478, green: 0.518, blue: 0.600)
    static let textMuted = Color(red: 0.290, green: 0.322, blue: 0.400)
    static let accentIndigo = Color(red: 0.506, green: 0.549, blue: 0.973)
    static let successGreen = Color(red: 0.431, green: 0.906, blue: 0.718)
    static let warnYellow = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let dirtyOrange = Color(red: 0.984, green: 0.573, blue: 0.188)
    static let purpleBranch = Color(red: 0.655, green: 0.545, blue: 0.980)
}

// MARK: – Tab item view

struct TabItemView: View {
    let tab: TabInfo
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            // Running indicator dot
            Circle()
                .fill(tab.isRunning ? Color.successGreen : Color.textMuted)
                .frame(width: 6, height: 6)
                .opacity(tab.isRunning ? 1.0 : 0.5)
                .animation(tab.isRunning ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: tab.isRunning)

            // Tab title
            Text(tab.title)
                .font(.system(size: 12))
                .foregroundColor(isActive ? .textPrimary : .textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .leading)

            // Git status badge
            if let git = tab.gitStatus {
                HStack(spacing: 3) {
                    if let branch = git.branch {
                        Text(branch)
                            .font(.system(size: 10))
                            .foregroundColor(.purpleBranch)
                    }
                    if git.ahead > 0 {
                        Text("↑\(git.ahead)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.warnYellow)
                    }
                    if git.dirty {
                        Circle()
                            .fill(Color.dirtyOrange)
                            .frame(width: 5, height: 5)
                    }
                }
            }

            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
            .opacity(isHovered || isActive ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.tabActive : (isHovered ? Color.tabHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.white.opacity(0.07) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
        .contentShape(Rectangle())
    }
}

// MARK: – Tab bar

struct TabBarView: View {
    @ObservedObject var tabManager: TabManager
    let onNewTab: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Space for traffic lights (76pt)
            Spacer().frame(width: 76)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabManager.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == tabManager.activeTabId,
                            onSelect: { tabManager.setActive(id: tab.id) },
                            onClose: { tabManager.closeTab(id: tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            // New tab button
            Button {
                onNewTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab (⌘T)")

            Spacer()
        }
        .frame(height: 42)
        .background(Color(red: 0.031, green: 0.031, blue: 0.071).opacity(0.97))
        .overlay(Divider().opacity(0.15), alignment: .bottom)
    }
}
