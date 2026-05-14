import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessions = AtlasSessionStore.shared.loadSessions()
    @AppStorage(
        AtlasConfiguration.hapticsEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var hapticsEnabled = true
    @State private var autocorrectEnabled = true
    @State private var darkKeyboardEnabled = false

    private var userSession: AtlasSession {
        sessions.first ?? .fresh(name: AtlasSession.defaultName)
    }

    var body: some View {
        TabView {
            NavigationStack {
                onboarding
                    .navigationTitle("ATLAS Keyboard")
            }
            .tabItem {
                Label("Setup", systemImage: "keyboard")
            }

            NavigationStack {
                PersonaView(session: userSession)
                    .navigationTitle("Persona")
            }
            .tabItem {
                Label("Persona", systemImage: "person.crop.circle")
            }

            NavigationStack {
                settings
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
        }
        .tint(.primary)
        .onChange(of: sessions) { _, newValue in
            AtlasSessionStore.shared.saveSessions(newValue)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            sessions = AtlasSessionStore.shared.loadSessions()
        }
        .onAppear {
            sessions = AtlasSessionStore.shared.loadSessions()
        }
    }

    private var onboarding: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Private predictions, built into your keyboard.")
                        .font(.title2.weight(.semibold))
                    Text("ATLAS runs on device, learns your personal vocabulary, and keeps your engram local and encrypted.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Enable Keyboard") {
                SetupStep(number: 1, title: "Open Settings", detail: "Go to General > Keyboard > Keyboards.")
                SetupStep(number: 2, title: "Add ATLAS", detail: "Choose Add New Keyboard and select ATLAS.")
                SetupStep(number: 3, title: "Start Typing", detail: "Use the globe key to switch to ATLAS anywhere.")
            }

            Section("Privacy") {
                Label("No telemetry or analytics", systemImage: "eye.slash")
                Label("Encrypted local persona engram", systemImage: "lock")
                Label("Cloud sync is not enabled in this MVP", systemImage: "icloud.slash")
            }
        }
    }

    private var settings: some View {
        Form {
            Section("Keyboard") {
                Toggle("Haptics", isOn: $hapticsEnabled)
                Toggle("Autocorrect", isOn: $autocorrectEnabled)
                Toggle("Dark keyboard", isOn: $darkKeyboardEnabled)
            }

            Section("Engram") {
                if userSession.engram.sortedEntries.isEmpty {
                    ContentUnavailableView("No learned words yet", systemImage: "text.badge.plus", description: Text("ATLAS learns personal words as you type and accept suggestions."))
                } else {
                    ForEach(userSession.engram.sortedEntries.prefix(20)) { entry in
                        HStack {
                            Text(entry.word)
                            Spacer()
                            Text("\(entry.acceptedCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct SetupStep: View {
    var number: Int
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 24, height: 24)
                .background(.primary)
                .foregroundStyle(.background)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PersonaView: View {
    var session: AtlasSession

    private var entries: [EngramEntry] {
        session.engram.sortedEntries
    }

    private var totalLearnedUses: Int {
        entries.reduce(0) { $0 + $1.acceptedCount }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    PersonaAvatar(session: session)
                        .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your persona")
                            .font(.headline)
                        Text("One private vocabulary learned silently from your typing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Summary") {
                LabeledContent("Saved words", value: "\(entries.count)")
                LabeledContent("Total sightings", value: "\(totalLearnedUses)")
                if let latest = entries.map(\.lastSeenAt).max() {
                    LabeledContent("Last updated", value: latest.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Saved Words") {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No learned words yet",
                        systemImage: "text.badge.plus",
                        description: Text("Personal words will appear here after you type messages with ATLAS.")
                    )
                } else {
                    ForEach(entries) { entry in
                        EngramWordRow(entry: entry, maxCount: maxAcceptedCount)
                    }
                }
            }
        }
    }

    private var maxAcceptedCount: Int {
        max(entries.map(\.acceptedCount).max() ?? 1, 1)
    }
}

private struct PersonaAvatar: View {
    var session: AtlasSession

    var body: some View {
        Text(session.displayInitials)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                Circle()
                    .fill(Color(hue: session.avatarHue, saturation: 0.58, brightness: 0.74))
            )
    }
}

private struct EngramWordRow: View {
    var entry: EngramEntry
    var maxCount: Int

    private var fillAmount: Double {
        Double(entry.acceptedCount) / Double(maxCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.word)
                    .font(.body.weight(.semibold))
                Spacer()
                Text("\(entry.acceptedCount)")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(.primary.opacity(0.35))
                        .frame(width: proxy.size.width * CGFloat(fillAmount))
                }
            }
            .frame(height: 5)

            Text(entry.lastSeenAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}
