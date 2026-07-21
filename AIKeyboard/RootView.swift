import SwiftUI

/// Landing screen: connection status, setup steps, and links to settings/about.
struct RootView: View {
    @State private var hasKey = SecretStore.shared.hasKey

    var body: some View {
        NavigationView {
            List {
                Section("AI") {
                    HStack {
                        Text("Gemini")
                        Spacer()
                        Text(hasKey ? "Connected" : "API Key Missing")
                            .foregroundColor(hasKey ? .green : .orange)
                    }
                    NavigationLink("Gemini API & Settings") {
                        SettingsView(onChange: { hasKey = SecretStore.shared.hasKey })
                    }
                }

                Section("Set up the keyboard") {
                    step(1, "Open Settings → General → Keyboard → Keyboards → Add New Keyboard, then choose AI Keyboard.")
                    step(2, "Tap AI Keyboard in that list and turn on Allow Full Access. This is required so AI requests can reach Gemini.")
                    step(3, "Add your Gemini API key in Gemini API & Settings above, tap Save, then tap Copy Key to Clipboard.")
                    step(4, "In any app, switch to AI Keyboard, tap AI, then tap Paste API Key once. After that, AI works everywhere.")
                }

                Section {
                    NavigationLink("About") { AboutView() }
                }
            }
            .navigationTitle("AI Keyboard")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear { hasKey = SecretStore.shared.hasKey }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .center)
            Text(text)
                .font(.callout)
        }
        .padding(.vertical, 2)
    }
}
