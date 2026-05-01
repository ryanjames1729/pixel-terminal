import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: Section = .appearance
    @State private var githubToken = ""
    @State private var vercelToken = ""
    @State private var anthropicKey = ""
    @State private var githubStatus: TokenStatus = .idle
    @State private var vercelStatus: TokenStatus = .idle
    @State private var anthropicStatus: TokenStatus = .idle
    @State private var githubUser: String? = nil
    @State private var vercelUser: String? = nil

    enum Section: String, CaseIterable {
        case appearance = "Appearance"
        case integrations = "Integrations"
        case shell = "Shell"
    }

    enum TokenStatus { case idle, validating, valid, invalid }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar nav
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Section.allCases, id: \.self) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Text(section.rawValue)
                            .font(.system(size: 13))
                            .foregroundColor(selectedSection == section
                                ? Color(red: 0.506, green: 0.549, blue: 0.973)
                                : Color(red: 0.478, green: 0.518, blue: 0.600))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedSection == section
                                ? Color(red: 0.506, green: 0.549, blue: 0.973).opacity(0.12)
                                : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .frame(width: 140)
            .padding(.top, 12)
            .background(Color(red: 0.04, green: 0.04, blue: 0.09))
            .overlay(Divider().opacity(0.15), alignment: .trailing)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedSection {
                    case .appearance: appearanceContent
                    case .integrations: integrationsContent
                    case .shell: shellContent
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 480, height: 420)
        .background(Color(red: 0.051, green: 0.051, blue: 0.098))
        .onAppear(perform: loadTokens)
    }

    // MARK: – Sections

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Appearance")

            SettingsField(label: "Font Family") {
                TextField("SFMono-Regular", text: $settings.fontName)
                    .textFieldStyle(.plain)
                    .padding(7)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(5)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
            }

            SettingsField(label: "Font Size: \(Int(settings.fontSize))pt") {
                Slider(value: $settings.fontSize, in: 10...20, step: 1)
                    .tint(Color(red: 0.506, green: 0.549, blue: 0.973))
            }

            SettingsField(label: "Cursor") {
                Toggle("Blinking cursor", isOn: $settings.cursorBlink)
                    .toggleStyle(.checkbox)
                    .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                    .font(.system(size: 13))
            }

            SettingsField(label: "Scrollback") {
                HStack {
                    TextField("10000", value: $settings.scrollback, format: .number)
                        .textFieldStyle(.plain)
                        .padding(7)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(5)
                        .frame(width: 90)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                    Text("lines")
                        .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                        .font(.system(size: 12))
                }
            }
        }
    }

    private var integrationsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Integrations")

            Text("Tokens are encrypted in your macOS Keychain.")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.290, green: 0.322, blue: 0.400))

            // Claude API key — enables AI-powered suggestions
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.820, green: 0.580, blue: 0.980))
                    Text("Anthropic API Key")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                    Text("· enables AI suggestions")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.290, green: 0.322, blue: 0.400))
                }

                HStack(spacing: 8) {
                    SecureField("sk-ant-…", text: $anthropicKey)
                        .textFieldStyle(.plain)
                        .padding(7)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(5)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)

                    if anthropicStatus == .valid {
                        Button("Remove") { disconnectAnthropic() }
                            .buttonStyle(DangerButtonStyle())
                    } else {
                        Button(anthropicStatus == .validating ? "…" : "Save") { connectAnthropic() }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(anthropicKey.isEmpty || anthropicStatus == .validating)
                    }
                }

                if anthropicStatus == .valid {
                    Label("AI suggestions active", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.431, green: 0.906, blue: 0.718))
                } else if anthropicStatus == .invalid {
                    Label("Invalid key", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.973, green: 0.443, blue: 0.443))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(7)

            tokenRow(
                label: "GitHub Personal Access Token",
                token: $githubToken,
                status: $githubStatus,
                user: githubUser,
                hintURL: "https://github.com/settings/tokens/new",
                onConnect: connectGitHub,
                onDisconnect: disconnectGitHub
            )

            tokenRow(
                label: "Vercel Access Token",
                token: $vercelToken,
                status: $vercelStatus,
                user: vercelUser,
                hintURL: "https://vercel.com/account/tokens",
                onConnect: connectVercel,
                onDisconnect: disconnectVercel
            )
        }
    }

    private var shellContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("Shell")

            SettingsField(label: "Default Shell") {
                TextField("/bin/zsh", text: $settings.shell)
                    .textFieldStyle(.plain)
                    .padding(7)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(5)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
            }

            SettingsField(label: "Selection") {
                Toggle("Copy on select", isOn: $settings.copyOnSelect)
                    .toggleStyle(.checkbox)
                    .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
                    .font(.system(size: 13))
            }
        }
    }

    // MARK: – Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
            .kerning(0.8)
    }

    private func tokenRow(
        label: String,
        token: Binding<String>,
        status: Binding<TokenStatus>,
        user: String?,
        hintURL: String,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))

            HStack(spacing: 8) {
                SecureField("Paste your token", text: token)
                    .textFieldStyle(.plain)
                    .padding(7)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(5)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                if status.wrappedValue == .valid {
                    Button("Disconnect") { onDisconnect() }
                        .buttonStyle(DangerButtonStyle())
                } else {
                    Button(status.wrappedValue == .validating ? "…" : "Connect") { onConnect() }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(token.wrappedValue.isEmpty || status.wrappedValue == .validating)
                }
            }

            HStack {
                if status.wrappedValue == .valid {
                    Label(user.map { "Connected as \($0)" } ?? "Connected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.431, green: 0.906, blue: 0.718))
                } else if status.wrappedValue == .invalid {
                    Label("Invalid token", systemImage: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.973, green: 0.443, blue: 0.443))
                }
                Spacer()
                Button("How to get a token →") {
                    NSWorkspace.shared.open(URL(string: hintURL)!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.376, green: 0.647, blue: 0.980))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(7)
    }

    // MARK: – Token actions

    private func loadTokens() {
        if let t = CredentialStore.get(key: "github") { githubToken = t; githubStatus = .valid }
        if let t = CredentialStore.get(key: "vercel") { vercelToken = t; vercelStatus = .valid }
        if let t = CredentialStore.get(key: "anthropic") { anthropicKey = t; anthropicStatus = .valid }
    }

    private func connectGitHub() {
        githubStatus = .validating
        Task {
            let result = await TokenValidator.validateGitHub(token: githubToken)
            await MainActor.run {
                if result.valid {
                    githubStatus = .valid
                    githubUser = result.user
                    CredentialStore.set(key: "github", value: githubToken)
                } else {
                    githubStatus = .invalid
                }
            }
        }
    }

    private func disconnectGitHub() {
        CredentialStore.delete(key: "github")
        githubToken = ""
        githubStatus = .idle
        githubUser = nil
    }

    private func connectVercel() {
        vercelStatus = .validating
        Task {
            let result = await TokenValidator.validateVercel(token: vercelToken)
            await MainActor.run {
                if result.valid {
                    vercelStatus = .valid
                    vercelUser = result.user
                    CredentialStore.set(key: "vercel", value: vercelToken)
                } else {
                    vercelStatus = .invalid
                }
            }
        }
    }

    private func disconnectVercel() {
        CredentialStore.delete(key: "vercel")
        vercelToken = ""
        vercelStatus = .idle
        vercelUser = nil
    }

    private func connectAnthropic() {
        guard !anthropicKey.isEmpty else { return }
        // Basic format validation: Anthropic keys start with "sk-ant-"
        if anthropicKey.hasPrefix("sk-ant-") || anthropicKey.hasPrefix("sk-") {
            CredentialStore.set(key: "anthropic", value: anthropicKey)
            anthropicStatus = .valid
        } else {
            anthropicStatus = .invalid
        }
    }

    private func disconnectAnthropic() {
        CredentialStore.delete(key: "anthropic")
        anthropicKey = ""
        anthropicStatus = .idle
    }
}

// MARK: – Supporting views

private struct SettingsField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.478, green: 0.518, blue: 0.600))
            content()
        }
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(red: 0.506, green: 0.549, blue: 0.973).opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(5)
    }
}

private struct DangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(Color(red: 0.973, green: 0.443, blue: 0.443))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color(red: 0.973, green: 0.443, blue: 0.443).opacity(0.12))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(red: 0.973, green: 0.443, blue: 0.443).opacity(0.3), lineWidth: 1)
            )
    }
}
