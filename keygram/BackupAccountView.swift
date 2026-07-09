import SwiftUI

/// Detail screen behind the Home "Back up" row. Signed out, it explains cloud backup and
/// offers Apple/Google sign-in; signed in, it shows the account, a manual "Back up now",
/// a cross-provider link action, and local sign-out.
struct BackupAccountView: View {
    @ObservedObject private var auth = AuthManager.shared
    @ObservedObject private var backup = BackupSyncService.shared

    @State private var providerDialogMode: ProviderMode?
    @State private var restoreConfirmUID: String?

    private enum ProviderMode: Identifiable {
        case signIn, link
        var id: Int { self == .signIn ? 0 : 1 }
    }

    var body: some View {
        List {
            switch auth.state {
            case .signedOut:
                signedOutSection
            case let .signedIn(account):
                signedInSection(account)
            }

            if let message = auth.lastError ?? backup.lastError {
                Section {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Account")
        .confirmationDialog(
            "Continue with",
            isPresented: providerDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Apple") { start(provider: .apple) }
            Button("Google") { start(provider: .google) }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Restore from cloud?",
            isPresented: restoreConfirmBinding,
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                if let uid = restoreConfirmUID {
                    Task { await backup.restore(uid: uid) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces your words, corrections, and typing model on this device with your latest cloud backup.")
        }
        .onChange(of: auth.account?.uid) { _, uid in
            // First sign-in on this device: pull + merge + push so data reconciles.
            guard let uid else { return }
            Task { await backup.sync(uid: uid) }
        }
    }

    // MARK: - Signed out

    private var signedOutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("Back up your keyboard")
                    .font(.headline)
                Text("Sign in to safely back up your personal words, learned corrections, and typing model. Restore them on a new phone, and keep them in sync whether you use Apple or Google sign-in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)

            Button {
                providerDialogMode = .signIn
            } label: {
                Label("Back up", systemImage: "icloud.and.arrow.up")
            }
            .disabled(auth.isWorking)

            if auth.isWorking {
                ProgressView()
            }
        } footer: {
            Text("Your backup is tied to your account. Data leaves this device only after you sign in.")
        }
    }

    // MARK: - Signed in

    @ViewBuilder
    private func signedInSection(_ account: AuthManager.Account) -> some View {
        Section {
            LabeledContent("Signed in", value: account.email ?? account.displayName ?? "Account")
            LabeledContent("Providers", value: providerNames(account.providers))
        }

        Section {
            Button {
                Task { await backup.backUpNow(uid: account.uid) }
            } label: {
                HStack {
                    Label("Back up now", systemImage: "icloud.and.arrow.up")
                    Spacer()
                    if backup.activeOperation == .backUp {
                        ProgressView()
                    }
                }
            }
            .disabled(backup.isSyncing)

            if let syncedAt = backup.lastSyncedAt {
                LabeledContent(
                    "Last backed up",
                    value: syncedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        } footer: {
            Text("Backs up your words, corrections, typing model, and settings.")
        }

        Section {
            Button {
                restoreConfirmUID = account.uid
            } label: {
                HStack {
                    Label("Restore from cloud", systemImage: "icloud.and.arrow.down")
                    Spacer()
                    if backup.activeOperation == .restore {
                        ProgressView()
                    }
                }
            }
            .disabled(backup.isSyncing)
        } footer: {
            Text("Replaces this device's words, corrections, and typing model with your latest cloud backup.")
        }

        Section {
            Button {
                providerDialogMode = .link
            } label: {
                Label("Link another account", systemImage: "link")
            }
            .disabled(auth.isWorking)
        } footer: {
            Text("Sign in with your other provider (Apple or Google) to unify devices — useful if Apple hid your email.")
        }

        Section {
            Button("Sign out", role: .destructive) {
                auth.signOut()
            }
        } footer: {
            Text("Signing out keeps your cloud backup. Your on-device data stays on this phone.")
        }
    }

    // MARK: - Actions

    private enum Provider { case apple, google }

    private func start(provider: Provider) {
        let mode = providerDialogMode
        providerDialogMode = nil
        switch (provider, mode) {
        case (.apple, .link): auth.linkWithApple()
        case (.google, .link): auth.linkWithGoogle()
        case (.apple, _): auth.signInWithApple()
        case (.google, _): auth.signInWithGoogle()
        }
    }

    private var providerDialogBinding: Binding<Bool> {
        Binding(
            get: { providerDialogMode != nil },
            set: { if !$0 { providerDialogMode = nil } }
        )
    }

    private var restoreConfirmBinding: Binding<Bool> {
        Binding(
            get: { restoreConfirmUID != nil },
            set: { if !$0 { restoreConfirmUID = nil } }
        )
    }

    private func providerNames(_ providers: [String]) -> String {
        let names = providers.compactMap { id -> String? in
            switch id {
            case "apple.com": return "Apple"
            case "google.com": return "Google"
            case "password": return "Email"
            default: return nil
            }
        }
        return names.isEmpty ? "—" : names.joined(separator: ", ")
    }
}
