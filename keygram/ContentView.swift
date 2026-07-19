import SwiftUI
import Combine
import StoreKit
import SafariServices
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessions = AtlasSessionStore.shared.loadSessions()
    @AppStorage(
        AtlasConfiguration.hapticsEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var hapticsEnabled = true
    @AppStorage(
        AtlasConfiguration.autocorrectEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var autocorrectEnabled = true
    @AppStorage(
        AtlasConfiguration.aiRewriteEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var aiRewriteEnabled = true
    @AppStorage(
        AtlasConfiguration.personalizedAutocorrectEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var personalizedAutocorrectEnabled = true
    @AppStorage(
        AtlasConfiguration.personalizedTypingEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var personalizedTypingEnabled = false
    @AppStorage(
        AtlasConfiguration.learnNewWordsEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var learnNewWordsEnabled = true
    @AppStorage(
        AtlasConfiguration.neuralOnlyEvaluationEnabledKey,
        store: UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
    ) private var neuralOnlyEvaluationEnabled = false
    @State private var darkKeyboardEnabled = false
    @State private var autocorrectFeedback = AutocorrectFeedbackStore.shared.summaries(limit: 5_000)
    @State private var nextWordEvaluation = NextWordFeedbackStore.shared.evaluationSnapshot()
    @State private var learnedTypingTaps = Self.loadLearnedTypingTaps()
    @State private var typingModelHealth = Self.loadTypingModelHealth()
    @State private var setupStatus = KeyboardSetupStatus.current()
    @State private var hasFinishedOnboarding = KeyboardSetupStatus.hasCompletedOnboarding

    private var userSession: AtlasSession {
        sessions.first ?? .fresh(name: AtlasSession.defaultName)
    }

    private var shouldShowOnboarding: Bool {
        !hasFinishedOnboarding && !setupStatus.isComplete
    }

    var body: some View {
        Group {
            if shouldShowOnboarding {
                OnboardingView(
                    status: setupStatus,
                    refresh: { setupStatus = KeyboardSetupStatus.current() },
                    onComplete: {
                        hasFinishedOnboarding = true
                        refreshLocalState()
                    }
                )
            } else {
                homeContent
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            setupStatus = KeyboardSetupStatus.current()
        }
        .onChange(of: neuralOnlyEvaluationEnabled) {
            resetNextWordEvaluation()
        }
    }

    private var homeContent: some View {
        NavigationStack {
            HomeView(
                keyboardSettings: {
                    KeyboardSettingsView(
                        hapticsEnabled: $hapticsEnabled,
                        autocorrectEnabled: $autocorrectEnabled,
                        aiRewriteEnabled: $aiRewriteEnabled,
                        personalizedAutocorrectEnabled: $personalizedAutocorrectEnabled,
                        learnNewWordsEnabled: $learnNewWordsEnabled,
                        darkKeyboardEnabled: $darkKeyboardEnabled,
                        neuralOnlyEvaluationEnabled: $neuralOnlyEvaluationEnabled,
                        nextWordEvaluation: nextWordEvaluation,
                        refreshEvaluation: refreshNextWordEvaluation,
                        resetEvaluation: resetNextWordEvaluation,
                        resetPredictionFeedback: resetPredictionFeedback
                    )
                },
                typingPersonalization: {
                    TypingPersonalizationView(
                        personalizedTypingEnabled: $personalizedTypingEnabled,
                        learnedTaps: learnedTypingTaps,
                        modelHealth: typingModelHealth,
                        refresh: refreshTypingPersonalization,
                        reset: resetTypingPersonalization
                    )
                },
                personaWords: {
                    PersonaWordsView(
                        session: userSession,
                        confirmWord: confirmEngramWord,
                        removeWord: removeEngramWord
                    )
                },
                learnedCorrections: {
                    LearnedCorrectionsView(
                        corrections: autocorrectFeedback,
                        removeCorrection: removeCorrection,
                        resetCorrections: resetCorrections
                    )
                },
                backupAccount: {
                    BackupAccountView()
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
        // Bottom navigation is intentionally disabled. The home rows now own navigation.
        // TabView { Setup tab; Persona tab; Settings tab }
        .tint(.primary)
        .onChange(of: sessions) { _, newValue in
            AtlasSessionStore.shared.saveSessions(newValue)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            refreshLocalState()
        }
        .onAppear {
            refreshLocalState()
        }
    }

    private func refreshLocalState() {
        sessions = AtlasSessionStore.shared.loadSessions()
        autocorrectFeedback = AutocorrectFeedbackStore.shared.summaries(limit: 5_000)
        refreshNextWordEvaluation()
        refreshTypingPersonalization()
    }

    private func removeEngramWord(_ entry: EngramEntry) {
        guard var session = sessions.first else { return }
        session.engram.remove(entry.word)
        session.updatedAt = Date()
        sessions = [session]
    }

    private func confirmEngramWord(_ entry: EngramEntry) {
        guard var session = sessions.first else { return }
        session.engram.confirmManually(entry.word, sessionName: session.name)
        session.updatedAt = Date()
        sessions = [session]
    }

    private func removeCorrection(_ correction: AutocorrectFeedbackSummary) {
        AutocorrectFeedbackStore.shared.remove(typed: correction.typed, candidate: correction.candidate)
        autocorrectFeedback = AutocorrectFeedbackStore.shared.summaries(limit: 5_000)
    }

    private func resetCorrections() {
        AutocorrectFeedbackStore.shared.reset()
        autocorrectFeedback = []
    }

    private func refreshNextWordEvaluation() {
        // Re-read the shared file first: the metrics are produced by the keyboard
        // extension, so without a reload the app serves a stale in-memory cache.
        NextWordFeedbackStore.shared.reloadFromDisk()
        nextWordEvaluation = NextWordFeedbackStore.shared.evaluationSnapshot()
    }

    private func resetNextWordEvaluation() {
        NextWordFeedbackStore.shared.resetEvaluation()
        refreshNextWordEvaluation()
    }

    private func resetPredictionFeedback() {
        NextWordFeedbackStore.shared.resetFeedback()
    }

    private func refreshTypingPersonalization() {
        migrateTypingPersonalizationIfNeeded()
        learnedTypingTaps = Self.loadLearnedTypingTaps()
        typingModelHealth = Self.loadTypingModelHealth()
        if learnedTypingTaps < AtlasConfiguration.personalizedTypingActivationThreshold {
            personalizedTypingEnabled = false
        }
    }

    private func resetTypingPersonalization() {
        personalizedTypingEnabled = false
        TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)?
            .deleteSavedModelSynchronously()
        Self.sharedDefaults.set(
            0,
            forKey: AtlasConfiguration.touchModelSchemaVersionKey
        )
        learnedTypingTaps = 0
        typingModelHealth = TypingModelHealth(learnedLetters: 0, expectedLetters: TouchModel.requiredLetterCount)
    }

    private func migrateTypingPersonalizationIfNeeded() {
        guard Self.sharedDefaults.integer(forKey: AtlasConfiguration.touchModelSchemaVersionKey)
            < AtlasConfiguration.currentTouchModelSchemaVersion
        else {
            return
        }

        TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)?.deleteSavedModelSynchronously()
        personalizedTypingEnabled = false
    }

    private static func loadLearnedTypingTaps() -> Int {
        TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)?
            .load()?
            .totalSamples ?? 0
    }

    private static func loadTypingModelHealth() -> TypingModelHealth {
        guard let model = TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)?.load() else {
            return TypingModelHealth(learnedLetters: 0, expectedLetters: TouchModel.requiredLetterCount)
        }
        return TypingModelHealth(
            learnedLetters: model.completeLetterCount,
            expectedLetters: TouchModel.requiredLetterCount
        )
    }

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
    }
}

private struct TypingModelHealth {
    var learnedLetters: Int
    var expectedLetters: Int

    var isComplete: Bool {
        learnedLetters == expectedLetters
    }
}

private struct HomeView<KeyboardSettings: View, TypingPersonalization: View, PersonaWords: View, LearnedCorrections: View, BackupAccount: View>: View {
    @ViewBuilder var keyboardSettings: () -> KeyboardSettings
    @ViewBuilder var typingPersonalization: () -> TypingPersonalization
    @ViewBuilder var personaWords: () -> PersonaWords
    @ViewBuilder var learnedCorrections: () -> LearnedCorrections
    @ViewBuilder var backupAccount: () -> BackupAccount

    var body: some View {
        GeometryReader { proxy in
            let metrics = HomeLayoutMetrics(availableHeight: proxy.size.height)

            VStack(spacing: metrics.heroSectionSpacing) {
                KeyboardHero(height: metrics.heroHeight, logoSize: metrics.logoSize)
                    .frame(height: metrics.heroHeight)

                VStack(spacing: metrics.sectionSpacing) {
                    HomeSection {
//                        HomeNavigationRow("Keyboard Setup", rowHeight: metrics.rowHeight) {
//                            KeyboardSetupView()
//                        }
//                        HomeDivider()
                        HomeNavigationRow("Settings", rowHeight: metrics.rowHeight) {
                            keyboardSettings()
                        }
                        HomeDivider()
                        HomeNavigationRow("Typing", rowHeight: metrics.rowHeight) {
                            typingPersonalization()
                        }
                        HomeDivider()
                        HomeNavigationRow("Words", rowHeight: metrics.rowHeight) {
                            personaWords()
                        }
                        HomeDivider()
                        HomeNavigationRow("Corrections", rowHeight: metrics.rowHeight) {
                            learnedCorrections()
                        }
//                        HomeDivider()
//                        HomeNavigationRow("Stickers", rowHeight: metrics.rowHeight) {
//                            StickersView()
//                        }
                    }

                    HomeSection {
                        HomeRateRow(rowHeight: metrics.rowHeight)
                        HomeDivider()
                        HomeLinkRow(
                            "Privacy Policy",
                            rowHeight: metrics.rowHeight,
                            url: URL(string: "https://keygram.me/privacy")!
                        )
                        HomeDivider()
                        HomeLinkRow(
                            "Terms of Service",
                            rowHeight: metrics.rowHeight,
                            url: URL(string: "https://keygram.me/terms")!
                        )
                    }

                   HomeSection {
                       HomeNavigationRow("Account", rowHeight: metrics.rowHeight) {
                           backupAccount()
                       }
                   }
                }
            }
            .padding(.top, metrics.topPadding)
            .padding(.horizontal, 16)
            .padding(.bottom, metrics.bottomPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct HomeLayoutMetrics {
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let sectionSpacing: CGFloat
    let heroSectionSpacing: CGFloat
    let heroHeight: CGFloat
    let logoSize: CGFloat
    let rowHeight: CGFloat

    init(availableHeight: CGFloat) {
        let height = max(availableHeight, 1)
        let dividerHeight: CGFloat = 6
        topPadding = min(24, max(8, height * 0.02))
        bottomPadding = topPadding
        sectionSpacing = min(18, max(8, height * 0.016))
        heroSectionSpacing = min(120, max(60, height * 0.026))

        let rowCount: CGFloat = 7
        let outerSpacing = heroSectionSpacing + sectionSpacing
        let preferredHeroHeight = min(109, max(70, height * 0.12))
        let rowHeightWithPreferredHero = (
            height - topPadding - bottomPadding - outerSpacing - preferredHeroHeight - dividerHeight
        ) / rowCount

        if rowHeightWithPreferredHero < 48 {
            heroHeight = max(
                92,
                height - topPadding - bottomPadding - outerSpacing - dividerHeight - rowCount * 48
            )
        } else {
            heroHeight = preferredHeroHeight
        }

        rowHeight = min(
            52,
            max(
                36,
                floor((height - topPadding - bottomPadding - outerSpacing - heroHeight - dividerHeight) / rowCount)
            )
        )
        logoSize = min(206, max(126, heroHeight * 1.02))
    }
}

private struct KeyboardHero: View {
    var height: CGFloat
    var logoSize: CGFloat

    var body: some View {
        let iconScale = max(0.58, min(1, height / 250))

        Group {
            if let logoURL = Bundle.main.url(
                forResource: "AppIcon~ios-marketing",
                withExtension: "png"
            ), let logo = UIImage(contentsOfFile: logoURL.path) {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.18, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    .offset(y: 12 * iconScale)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct HomeNavigationRow<Destination: View>: View {
    var title: String
    var rowHeight: CGFloat
    let destination: Destination

    init(_ title: String, rowHeight: CGFloat, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.rowHeight = rowHeight
        self.destination = destination()
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HomeRowLabel(title: title, role: nil, showsChevron: true, rowHeight: rowHeight)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeLinkRow: View {
    var title: String
    var rowHeight: CGFloat
    var url: URL

    init(_ title: String, rowHeight: CGFloat, url: URL) {
        self.title = title
        self.rowHeight = rowHeight
        self.url = url
    }

    @State private var isPresentingWeb = false

    var body: some View {
        Button {
            isPresentingWeb = true
        } label: {
            HomeRowLabel(title: title, role: nil, showsChevron: true, rowHeight: rowHeight)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresentingWeb) {
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }
}

/// In-app browser (`SFSafariViewController`) so Privacy Policy / Terms open inside Keygram
/// instead of switching the user out to the Safari app.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct HomeButtonRow: View {
    var title: String
    var role: ButtonRole?
    var rowHeight: CGFloat
    var action: () -> Void

    init(_ title: String, role: ButtonRole? = nil, rowHeight: CGFloat, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.rowHeight = rowHeight
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            HomeRowLabel(title: title, role: role, showsChevron: false, rowHeight: rowHeight)
        }
        .buttonStyle(.plain)
    }
}

/// "Rate Us" row. Deep-links straight to the App Store write-review sheet once the app is
/// live (`AppStoreInfo.appStoreID` set); until then it falls back to StoreKit's in-app
/// review prompt so the row is always functional.
private struct HomeRateRow: View {
    var rowHeight: CGFloat

    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = AppStoreInfo.writeReviewURL {
                openURL(url)
            } else {
                requestReview()
            }
        } label: {
            HomeRowLabel(title: "Rate Us", role: nil, showsChevron: true, rowHeight: rowHeight)
        }
        .buttonStyle(.plain)
    }
}

/// App Store identifiers used for review/rating deep links.
enum AppStoreInfo {
    /// The numeric App Store ID (the `id######` in the product URL). Fill this in once the
    /// app has been created in App Store Connect. While empty, "Rate Us" uses the in-app
    /// StoreKit review prompt instead of the write-review deep link.
    static let appStoreID = "6767987188"

    /// Direct link to the App Store review composer, or `nil` if the ID isn't set yet.
    static var writeReviewURL: URL? {
        guard !appStoreID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")
    }
}

private struct HomeRowLabel: View {
    var title: String
    var role: ButtonRole?
    var showsChevron: Bool
    var rowHeight: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: rowHeight < 50 ? 12 : 16, weight: .regular))
                .foregroundStyle(role == .destructive ? .red : .primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Spacer()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: rowHeight < 50 ? 20 : 23, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: rowHeight)
        .padding(.horizontal, 22)
        .contentShape(Rectangle())
    }
}

private struct HomeDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 22)
    }
}

private struct KeyboardSetupView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Private predictions, built into your keyboard.")
                        .font(.title2.weight(.semibold))
                    Text("Keygram runs on device, learns your personal vocabulary, and keeps your persona local and encrypted.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("Enable Keyboard") {
                SetupStep(number: 1, title: "Open Settings", detail: "Go to General > Keyboard > Keyboards.")
                SetupStep(number: 2, title: "Add Keygram", detail: "Choose Add New Keyboard and select Keygram.")
                SetupStep(number: 3, title: "Make It Default", detail: "Tap Edit and drag Keygram to the top of your keyboard list.")
                SetupStep(number: 4, title: "Start Typing", detail: "Use the globe key to switch to Keygram anywhere.")
            }

            Section("Privacy") {
                Label("No telemetry or analytics", systemImage: "eye.slash")
                Label("Encrypted local persona", systemImage: "lock")
                Label("Cloud backup is optional and only runs when you sign in", systemImage: "icloud")
            }

            #if canImport(UIKit)
            Section {
                Button("Open Keygram Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
            #endif
        }
        .navigationTitle("Keyboard Setup")
    }
}

private struct KeyboardSettingsView: View {
    @Binding var hapticsEnabled: Bool
    @Binding var autocorrectEnabled: Bool
    @Binding var aiRewriteEnabled: Bool
    @Binding var personalizedAutocorrectEnabled: Bool
    @Binding var learnNewWordsEnabled: Bool
    @Binding var darkKeyboardEnabled: Bool
    @Binding var neuralOnlyEvaluationEnabled: Bool
    var nextWordEvaluation: NextWordEvaluationSnapshot
    var refreshEvaluation: () -> Void
    var resetEvaluation: () -> Void
    var resetPredictionFeedback: () -> Void
    private let enabledTint = Color(
        red: 246.0 / 255.0,
        green: 207.0 / 255.0,
        blue: 47.0 / 255.0
    )

    var body: some View {
        Form {
            Section {
//                Text("Keyboard")
                Toggle("Haptics", isOn: $hapticsEnabled)
                Toggle("Autocorrect", isOn: $autocorrectEnabled)
//                Toggle("AI Rewrite", isOn: $aiRewriteEnabled)
                Toggle("Personalized autocorrect", isOn: $personalizedAutocorrectEnabled)
                Toggle("Learn new words", isOn: $learnNewWordsEnabled)
                Toggle("Dark keyboard", isOn: $darkKeyboardEnabled)
            }

            Section {
                Text("Personalized autocorrect learns from corrections you keep and corrections you undo. Everything stays on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Prediction Quality") {
                Toggle("Neural-only evaluation", isOn: $neuralOnlyEvaluationEnabled)
                Text("Diagnostic mode. Suggestions and accuracy use neural scores only; changing this setting resets the quality metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Evaluated words", value: "\(nextWordEvaluation.predictionCount)")
                LabeledContent(
                    "Top suggestion",
                    value: nextWordEvaluation.top1Accuracy.formatted(.percent.precision(.fractionLength(1)))
                )
                LabeledContent(
                    "Top 3",
                    value: nextWordEvaluation.top3Accuracy.formatted(.percent.precision(.fractionLength(1)))
                )
                LabeledContent(
                    "Suggestion selected",
                    value: nextWordEvaluation.suggestionSelectionRate.formatted(.percent.precision(.fractionLength(1)))
                )
                LabeledContent(
                    "Average inference",
                    value: "\(nextWordEvaluation.averageInferenceMilliseconds.formatted(.number.precision(.fractionLength(1)))) ms"
                )
                LabeledContent("P95 inference", value: "<= \(nextWordEvaluation.p95InferenceMilliseconds) ms")
                Button("Refresh metrics", action: refreshEvaluation)
                Button("Reset metrics", role: .destructive, action: resetEvaluation)
                Button("Reset prediction feedback", role: .destructive, action: resetPredictionFeedback)
            }

//            Section("AI Rewrite Privacy") {
//                Text("AI Rewrite sends only the selected text or current message you submit for rewriting to OpenRouter. Normal typing stays on this device.")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//            }
        }
        .tint(enabledTint)
        .navigationTitle("Settings")
        .onAppear(perform: refreshEvaluation)
    }
}

private struct TypingPersonalizationView: View {
    @Binding var personalizedTypingEnabled: Bool
    var learnedTaps: Int
    var modelHealth: TypingModelHealth
    var refresh: () -> Void
    var reset: () -> Void

    @State private var showingResetConfirmation = false
    private let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var threshold: Int {
        AtlasConfiguration.personalizedTypingActivationThreshold
    }

    private var isReady: Bool {
        learnedTaps >= threshold
    }

    private var progress: Double {
        min(Double(learnedTaps) / Double(threshold), 1)
    }

    var body: some View {
        List {
            Section {
//                Text("Personalized Typing")
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: isReady ? "checkmark.circle.fill" : "keyboard.badge.ellipsis")
                        .font(.title2)
                        .foregroundStyle(isReady ? .green : .blue)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(isReady ? "Ready to personalize" : "Learning your typing style")
                            .font(.headline)

                        if !isReady {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: progress)
                                Text("\(learnedTaps) / \(threshold) taps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(
                            isReady
                                ? "Keygram has learned how you type. Turn on personalized typing to start correcting slips based on your habits."
                                : "Keygram is learning where your fingers actually land when you type. Once it's learned enough, you'll be able to turn on personalized typing for fewer slips."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)

                Toggle("Personalized Typing", isOn: $personalizedTypingEnabled)
                    .disabled(!isReady)

                if isReady {
                    Label("Learned from \(learnedTaps) taps - keeps improving", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Label(
                    "Model health: \(modelHealth.learnedLetters) / \(modelHealth.expectedLetters) letters ready",
                    systemImage: modelHealth.isComplete ? "checkmark.seal" : "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(modelHealth.isComplete ? Color.secondary : Color.orange)
                #endif
            }

            if isReady || learnedTaps > 0 {
                Section {
                    Button("Reset learned data", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
            }
        }
        .tint(
            Color(
                red: 246.0 / 255.0,
                green: 207.0 / 255.0,
                blue: 47.0 / 255.0
            )
        )
        .navigationTitle("Typing")
        .refreshable {
            refresh()
        }
        .onAppear {
            refresh()
        }
        .onReceive(refreshTimer) { _ in
            refresh()
        }
        .onChange(of: learnedTaps) { _, newValue in
            if newValue < threshold {
                personalizedTypingEnabled = false
            }
        }
        .confirmationDialog(
            "Reset learned typing data?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: reset)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase what Keygram has learned about your typing. You can keep using the keyboard while it learns again.")
        }
    }
}

private struct PersonaWordsView: View {
    var session: AtlasSession
    var confirmWord: (EngramEntry) -> Void
    var removeWord: (EngramEntry) -> Void
    @State private var searchText = ""
    private let recentWordLimit = 10

    private var entries: [EngramEntry] {
        session.engram.sortedEntries
    }

    private var confirmedEntries: [EngramEntry] {
        entries
            .filter { $0.isConfirmed }
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    private var provisionalEntries: [EngramEntry] {
        entries
            .filter { !$0.isConfirmed }
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
    }

    private var recentConfirmedEntries: [EngramEntry] {
        Array(confirmedEntries.prefix(recentWordLimit))
    }

    private var recentProvisionalEntries: [EngramEntry] {
        Array(provisionalEntries.prefix(recentWordLimit))
    }

    private var totalLearnedUses: Int {
        entries.reduce(0) { $0 + $1.acceptedCount }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [EngramEntry] {
        guard !trimmedSearchText.isEmpty else { return [] }
        return Array(
            entries
                .filter { $0.word.localizedCaseInsensitiveContains(trimmedSearchText) }
                .prefix(20)
        )
    }

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Words", value: "\(entries.count)")
                LabeledContent("Confirmed", value: "\(confirmedEntries.count)")
                LabeledContent("Provisional", value: "\(provisionalEntries.count)")
                LabeledContent("Total sightings", value: "\(totalLearnedUses)")
                if let latest = entries.map(\.lastSeenAt).max() {
                    LabeledContent("Last updated", value: latest.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if trimmedSearchText.isEmpty {
                Section("Recent Confirmed Words") {
                    if recentConfirmedEntries.isEmpty {
                        ContentUnavailableView(
                            "No confirmed words",
                            systemImage: "text.badge.plus",
                            description: Text("Words appear here after Keygram has enough evidence that you meant them.")
                        )
                    } else {
                        ForEach(recentConfirmedEntries) { entry in
                            RemovableEngramWordRow(
                                entry: entry,
                                maxCount: maxAcceptedCount,
                                confirmWord: confirmWord,
                                removeWord: removeWord
                            )
                        }
                    }
                }

                if !recentProvisionalEntries.isEmpty {
                    Section("Recent Provisional Words") {
                        ForEach(recentProvisionalEntries) { entry in
                            RemovableEngramWordRow(
                                entry: entry,
                                maxCount: maxAcceptedCount,
                                confirmWord: confirmWord,
                                removeWord: removeWord
                            )
                        }
                    }
                }
            } else {
                Section("Search Results") {
                    if searchResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedSearchText)
                    } else {
                        ForEach(searchResults) { entry in
                            RemovableEngramWordRow(
                                entry: entry,
                                maxCount: maxAcceptedCount,
                                confirmWord: confirmWord,
                                removeWord: removeWord
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Words")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search words")
    }

    private var maxAcceptedCount: Int {
        max(entries.map(\.acceptedCount).max() ?? 1, 1)
    }
}

private struct RemovableEngramWordRow: View {
    var entry: EngramEntry
    var maxCount: Int
    var confirmWord: (EngramEntry) -> Void
    var removeWord: (EngramEntry) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            EngramWordRow(entry: entry, maxCount: maxCount)

            if !entry.isConfirmed {
                Button {
                    confirmWord(entry)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Confirm \(entry.word)")
            }

            Button(role: .destructive) {
                removeWord(entry)
            } label: {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(entry.word)")
        }
        .swipeActions {
            if !entry.isConfirmed {
                Button {
                    confirmWord(entry)
                } label: {
                    Label("Confirm", systemImage: "checkmark.circle")
                }
                .tint(.green)
            }
            Button(role: .destructive) {
                removeWord(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            if !entry.isConfirmed {
                Button {
                    confirmWord(entry)
                } label: {
                    Label("Confirm", systemImage: "checkmark.circle")
                }
            }
            Button(role: .destructive) {
                removeWord(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct LearnedCorrectionsView: View {
    var corrections: [AutocorrectFeedbackSummary]
    var removeCorrection: (AutocorrectFeedbackSummary) -> Void
    var resetCorrections: () -> Void
    @State private var searchText = ""
    @State private var showingResetConfirmation = false

    private var acceptedTotal: Int {
        corrections.reduce(0) { $0 + $1.acceptedCount }
    }

    private var rejectedTotal: Int {
        corrections.reduce(0) { $0 + $1.rejectedCount }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [AutocorrectFeedbackSummary] {
        guard !trimmedSearchText.isEmpty else { return [] }
        return Array(
            corrections
                .filter { correction in
                    correction.typed.localizedCaseInsensitiveContains(trimmedSearchText)
                        || correction.candidate.localizedCaseInsensitiveContains(trimmedSearchText)
                }
                .prefix(20)
        )
    }

    var body: some View {
        List {
            Section("Summary") {
                LabeledContent("Corrections", value: "\(corrections.count)")
                LabeledContent("Kept corrections", value: "\(acceptedTotal)")
                LabeledContent("Undone corrections", value: "\(rejectedTotal)")
                if let latest = corrections.map(\.lastSeenAt).max() {
                    LabeledContent("Last updated", value: latest.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Search Corrections") {
                if trimmedSearchText.isEmpty {
                    ContentUnavailableView(
                        "Search corrections learned from your typing",
                        systemImage: "magnifyingglass",
                        description: Text("Type a word  to show a limited set of matches.")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: trimmedSearchText)
                } else {
                    ForEach(searchResults) { correction in
                        LearnedCorrectionRow(correction: correction)
                            .swipeActions {
                                Button(role: .destructive) {
                                    removeCorrection(correction)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    removeCorrection(correction)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            Section {
                Button("Reset all corrections", role: .destructive) {
                    showingResetConfirmation = true
                }
            }
        }
        .navigationTitle("Corrections")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search corrections")
        .confirmationDialog(
            "Reset all corrections?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive, action: resetCorrections)
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct LearnedCorrectionRow: View {
    var correction: AutocorrectFeedbackSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(correction.typed) -> \(correction.candidate)")
                .font(.body.weight(.semibold))
            Text("Kept \(correction.acceptedCount) / Undone \(correction.rejectedCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

private struct StickersView: View {
    var body: some View {
        List {
            Section {
                ContentUnavailableView(
                    "No stickers yet",
                    systemImage: "face.smiling",
                    description: Text("Custom stickers and imported packs will appear here.")
                )
            }

            Section("Add Stickers") {
                Label("Add custom sticker", systemImage: "plus.square")
                Label("Import from WhatsApp", systemImage: "square.and.arrow.down")
                Label("Import from Telegram", systemImage: "paperplane")
            }
        }
        .navigationTitle("Stickers")
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
                Text(entry.isConfirmed ? "Confirmed" : "Provisional")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.isConfirmed ? .green : .secondary)
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
