import SwiftUI

// Permanent bottom dock for suggestions — always reserves space so the terminal never reflows.
struct SuggestionsDock: View {
    let suggestions: [Suggestion]
    @Binding var selectedIndex: Int
    let onAccept: (String) -> Void
    let onDismiss: () -> Void

    // Fixed height — ~5 rows × 28pt + small footer + chrome ≈ 168
    private let dockHeight: CGFloat = 168

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Subtle separator between terminal and dock
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)

            if suggestions.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("Suggestions appear here as you type")
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundColor(Color(red: 0.255, green: 0.275, blue: 0.345))
                .padding(.horizontal, 16)
                .padding(.top, 10)
            } else {
                SuggestionsView(
                    suggestions: suggestions,
                    selectedIndex: $selectedIndex,
                    onAccept: onAccept,
                    onDismiss: onDismiss
                )
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: dockHeight)
        .background(Color(red: 0.039, green: 0.039, blue: 0.082))
    }
}

struct SuggestionsView: View {
    let suggestions: [Suggestion]
    @Binding var selectedIndex: Int
    let onAccept: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { idx, suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isSelected: idx == selectedIndex,
                    isFirst: idx == 0,
                    onAccept: { onAccept(suggestion.text) }
                )
                .onHover { if $0 { selectedIndex = idx } }
            }

            HStack(spacing: 12) {
                Text("↑↓ navigate").opacity(0.5)
                Text("Tab accept").opacity(0.5)
                Text("Esc dismiss").opacity(0.5)
            }
            .font(.system(size: 10))
            .foregroundColor(Color(red: 0.29, green: 0.32, blue: 0.40))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(Divider().opacity(0.2), alignment: .top)
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(red: 0.063, green: 0.063, blue: 0.118).opacity(0.97))
                .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
        .frame(minWidth: 300, maxWidth: 500)
    }
}

private struct SuggestionRow: View {
    let suggestion: Suggestion
    let isSelected: Bool
    let isFirst: Bool
    let onAccept: () -> Void

    private var sourceColor: Color {
        switch suggestion.source {
        case .history: return Color(red: 0.376, green: 0.647, blue: 0.980)
        case .builtin: return Color(red: 0.655, green: 0.545, blue: 0.980)
        case .correction: return Color(red: 0.984, green: 0.749, blue: 0.141)
        case .claude: return Color(red: 0.820, green: 0.580, blue: 0.980)
        }
    }

    private var sourceIcon: String {
        switch suggestion.source {
        case .history: return "clock"
        case .builtin: return "square.grid.2x2"
        case .correction: return "wand.and.stars"
        case .claude: return "sparkles"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sourceIcon)
                .font(.system(size: 10))
                .foregroundColor(sourceColor)
                .frame(width: 14)

            Text(suggestion.text)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundColor(Color(red: 0.886, green: 0.910, blue: 0.961))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail = suggestion.detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.29, green: 0.32, blue: 0.40))
            }

            if isFirst {
                Text("TAB")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(red: 0.29, green: 0.32, blue: 0.40))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color(red: 0.506, green: 0.549, blue: 0.973).opacity(0.12) : Color.clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? Color(red: 0.506, green: 0.549, blue: 0.973) : Color.clear)
                .frame(width: 2),
            alignment: .leading
        )
        .onTapGesture { onAccept() }
        .contentShape(Rectangle())
    }
}
