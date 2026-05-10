import SwiftUI

struct NetworkPaletteView: View {
    let onInsert: (String) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @State private var selectedId: UUID? = nil
    @FocusState private var searchFocused: Bool

    private var filtered: [NetworkCommand] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return allNetworkCommands }
        let q = query.lowercased()
        return allNetworkCommands.filter {
            $0.name.lowercased().contains(q) ||
            $0.command.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.category.rawValue.lowercased().contains(q)
        }
    }

    private var grouped: [(category: NetworkCommand.Category, commands: [NetworkCommand])] {
        var map: [NetworkCommand.Category: [NetworkCommand]] = [:]
        for cmd in filtered { map[cmd.category, default: []].append(cmd) }
        return NetworkCommand.Category.allCases.compactMap { cat in
            guard let cmds = map[cat], !cmds.isEmpty else { return nil }
            return (category: cat, commands: cmds)
        }
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "network")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.506, green: 0.549, blue: 0.973))
                    TextField("Search network commands…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .focused($searchFocused)
                        .onSubmit { insertFirst() }
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                        }
                        .buttonStyle(.plain)
                    }
                    Text("⌘⇧N")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 0.290, green: 0.322, blue: 0.400))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(4)
                    Button { onDismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.071, green: 0.071, blue: 0.133))
                .overlay(Divider().opacity(0.2), alignment: .bottom)

                // Results
                if filtered.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.290, green: 0.322, blue: 0.400))
                        Text("No commands match \"\(query)\"")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(grouped, id: \.category) { group in
                                // Category header
                                HStack(spacing: 6) {
                                    Image(systemName: categoryIcon(group.category))
                                        .font(.system(size: 9))
                                    Text(group.category.rawValue.uppercased())
                                        .font(.system(size: 10, weight: .semibold))
                                        .kerning(0.8)
                                }
                                .foregroundColor(categoryColor(group.category))
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)

                                // Command rows
                                ForEach(group.commands) { cmd in
                                    CommandPaletteRow(
                                        cmd: cmd,
                                        isSelected: selectedId == cmd.id,
                                        query: query,
                                        onSelect: {
                                            selectedId = cmd.id
                                            onInsert(cmd.command)
                                            onDismiss()
                                        }
                                    )
                                    .onHover { if $0 { selectedId = cmd.id } }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 420)
                }

                // Footer
                HStack(spacing: 16) {
                    Label("click to insert", systemImage: "return")
                    Label("search by name, command, or category", systemImage: "magnifyingglass")
                    Spacer()
                    Text("\(filtered.count) commands")
                }
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.290, green: 0.322, blue: 0.400))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(red: 0.047, green: 0.047, blue: 0.090))
                .overlay(Divider().opacity(0.2), alignment: .top)
            }
            .background(Color(red: 0.055, green: 0.055, blue: 0.106))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 30, y: 10)
            .frame(width: 680)
            .padding(60)
        }
        .onAppear { searchFocused = true }
    }

    private func insertFirst() {
        if let first = filtered.first {
            onInsert(first.command)
            onDismiss()
        }
    }

    private func categoryIcon(_ cat: NetworkCommand.Category) -> String {
        switch cat {
        case .diagnostics: return "stethoscope"
        case .dns:          return "globe"
        case .interfaces:   return "antenna.radiowaves.left.and.right"
        case .ssh:          return "lock.shield"
        case .capture:      return "waveform"
        case .http:         return "arrow.up.arrow.down.circle"
        case .security:     return "shield.lefthalf.filled"
        case .macos:        return "apple.logo"
        case .kali:         return "terminal"
        }
    }

    private func categoryColor(_ cat: NetworkCommand.Category) -> Color {
        switch cat {
        case .diagnostics: return Color(red: 0.431, green: 0.906, blue: 0.718)
        case .dns:          return Color(red: 0.376, green: 0.647, blue: 0.980)
        case .interfaces:   return Color(red: 0.506, green: 0.549, blue: 0.973)
        case .ssh:          return Color(red: 0.655, green: 0.545, blue: 0.980)
        case .capture:      return Color(red: 0.984, green: 0.749, blue: 0.141)
        case .http:         return Color(red: 0.176, green: 0.831, blue: 0.745)
        case .security:     return Color(red: 0.973, green: 0.443, blue: 0.443)
        case .macos:        return Color(red: 0.478, green: 0.518, blue: 0.600)
        case .kali:         return Color(red: 0.235, green: 0.706, blue: 0.443)
        }
    }
}

// MARK: – Individual command row

private struct CommandPaletteRow: View {
    let cmd: NetworkCommand
    let isSelected: Bool
    let query: String
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(cmd.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : Color(red: 0.886, green: 0.910, blue: 0.961))
                .lineLimit(1)

            Text(cmd.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(isSelected
                    ? Color(red: 0.506, green: 0.549, blue: 0.973)
                    : Color(red: 0.376, green: 0.420, blue: 0.545))
                .lineLimit(1)
                .truncationMode(.tail)

            Text(cmd.description)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.290, green: 0.322, blue: 0.400))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected
            ? Color(red: 0.506, green: 0.549, blue: 0.973).opacity(0.12)
            : Color.clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? Color(red: 0.506, green: 0.549, blue: 0.973) : Color.clear)
                .frame(width: 2),
            alignment: .leading
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
