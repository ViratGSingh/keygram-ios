import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum LayoutMetric {
        static let keyboardHeight: CGFloat = KeyboardSurfaceView.preferredKeyboardHeight
    }

    private struct EngineLoadResult {
        var session: AtlasSession
        var engine: AtlasInferenceEngine
        var wasCached: Bool
    }

    private final class EngineService {
        static let shared = EngineService()

        private let stateQueue = DispatchQueue(label: "com.wooshir.keygram.engine-service", qos: .utility)
        private var cachedSession: AtlasSession?
        private var cachedEngine: AtlasInferenceEngine?
        private var isLoading = false
        private var completions: [(EngineLoadResult) -> Void] = []

        func loadIfNeeded(completion: @escaping (EngineLoadResult) -> Void) {
            stateQueue.async {
                if let cachedEngine = self.cachedEngine {
                    let session = AtlasSessionStore.shared.loadSessions().first
                        ?? self.cachedSession
                        ?? .fresh(name: AtlasSession.defaultName)
                    self.cachedSession = session
                    DispatchQueue.main.async {
                        completion(EngineLoadResult(session: session, engine: cachedEngine, wasCached: true))
                    }
                    return
                }

                self.completions.append(completion)
                guard !self.isLoading else { return }
                self.isLoading = true

                DispatchQueue.global(qos: .background).async {
                    let warmupStart = CFAbsoluteTimeGetCurrent()
                    let sessionStart = CFAbsoluteTimeGetCurrent()
                    let loadedSessions = AtlasSessionStore.shared.loadSessions()
                    KeyboardViewController.logServiceWarmup(String(format: "session load %.3fs", CFAbsoluteTimeGetCurrent() - sessionStart))
                    let session = loadedSessions.first ?? .fresh(name: AtlasSession.defaultName)
                    let engine = KeyboardViewController.makeInferenceEngine()
                    engine.restore(glaState: session.glaState)

                    self.stateQueue.async {
                        self.cachedSession = session
                        self.cachedEngine = engine
                        self.isLoading = false
                        let completions = self.completions
                        self.completions.removeAll()
                        let result = EngineLoadResult(session: session, engine: engine, wasCached: false)
                        KeyboardViewController.logServiceWarmup(String(format: "shared lazy session/model load finished in %.3fs", CFAbsoluteTimeGetCurrent() - warmupStart))

                        DispatchQueue.main.async {
                            completions.forEach { $0(result) }
                        }
                    }
                }
            }
        }
    }

    private final class AutocorrectService {
        static let shared = AutocorrectService()

        private let stateQueue = DispatchQueue(label: "com.wooshir.keygram.autocorrect-service", qos: .utility)
        private var cachedEngine: AtlasAutocorrectEngine?
        private var isLoading = false
        private var completions: [(AtlasAutocorrectEngine) -> Void] = []

        func loadIfNeeded(completion: @escaping (AtlasAutocorrectEngine) -> Void) {
            stateQueue.async {
                if let cachedEngine = self.cachedEngine {
                    DispatchQueue.main.async {
                        completion(cachedEngine)
                    }
                    return
                }

                self.completions.append(completion)
                guard !self.isLoading else { return }
                self.isLoading = true

                DispatchQueue.global(qos: .utility).async {
                    let loadStart = CFAbsoluteTimeGetCurrent()
                    let engine = AtlasAutocorrectEngine()
                    KeyboardViewController.logServiceWarmup(String(format: "autocorrect index load %.3fs", CFAbsoluteTimeGetCurrent() - loadStart))

                    self.stateQueue.async {
                        self.cachedEngine = engine
                        self.isLoading = false
                        let completions = self.completions
                        self.completions.removeAll()
                        DispatchQueue.main.async {
                            completions.forEach { $0(engine) }
                        }
                    }
                }
            }
        }
    }

    private var engine: AtlasInferenceEngine?
    private var sessions: [AtlasSession] = [.fresh(name: AtlasSession.defaultName)]

    private var isShifted = false
    private var isCapsLocked = false
    private var lastShiftTapAt: CFTimeInterval?
    private var keyboardView: KeyboardSurfaceView?
    private var keyboardViewConstraints: [NSLayoutConstraint] = []
    private var inputHeightConstraint: NSLayoutConstraint?
    private var currentKeyboardHeight = LayoutMetric.keyboardHeight
    private let inferenceQueue = DispatchQueue(label: "com.wooshir.keygram.inference", qos: .userInitiated)
    private let engramQueue = DispatchQueue(label: "com.wooshir.keygram.engram", qos: .utility)
    private let autocorrectQueue = DispatchQueue(label: "com.wooshir.keygram.autocorrect", qos: .userInitiated)
    private let aiRewriteService = AIRewriteService()
    private var currentDraftText = ""
    private var suggestionGeneration = 0
    private var autocorrectGeneration = 0
    private var isSuggestionInferenceRunning = false
    private var needsSuggestionRefreshAfterInference = false
    private var pendingSuggestionRefresh: DispatchWorkItem?
    private var pendingPresentationReveal: DispatchWorkItem?
    private var pendingEngineWarmup: DispatchWorkItem?
    private var pendingInputLatencyEvents: [InputLatencyEvent] = []
    private var lastSuggestionRequest: SuggestionRequest?
    private var displayedSuggestions: [AtlasSuggestion] = []
    private var autocorrectEngine: AtlasAutocorrectEngine?
    private var isAutocorrectLoading = false
    private let liveWordDecoder = LiveWordDecoder()
    private var isLiveAutocorrectRunning = false
    private var needsLiveAutocorrectRefresh = false
    private var isEngramMigrationRunning = false
    private var touchDecoder: KeygramDecoder?
    private var touchModelStore: TouchModelStore?
    private var undoStack: [AutocorrectUndo] = []
    private var pendingUndoExpiration: DispatchWorkItem?
    private var undoPillExpiresAt: Date?
    private var pendingAutocorrection: PendingAutocorrection?
    private var isEngineLoading = false
    private var aiRewriteGeneration = 0
    private var isAIRewriteRunning = false
    private var pendingRewriteUndo: RewriteUndo?
    private var hasEnteredPresentation = false
    private let startupLogStart = CFAbsoluteTimeGetCurrent()
    private static let disabledLayerActions: [String: CAAction] = [
        "bounds": NSNull(),
        "position": NSNull(),
        "backgroundColor": NSNull(),
        "opacity": NSNull(),
        "contents": NSNull()
    ]

    private struct SuggestionRequest: Equatable {
        var context: String
        var selectedWord: String?
        var rightContext: String
        var sessionUpdatedAt: Date
    }

    private struct InputLatencyEvent {
        var label: String
        var touchStartedAt: CFTimeInterval
        var touchEndedAt: CFTimeInterval
        var submittedAt: CFTimeInterval
    }

    private struct AutocorrectUndo {
        var original: String
        var correction: String
        var contextKey: String
    }

    private struct PendingAutocorrection {
        var original: String
        var correction: String
        var contextKey: String
    }

    private struct RewriteTarget {
        var promptText: String
        var textToReplace: String
        var usesSelection: Bool
    }

    private struct RewriteUndo {
        var original: String
        var replacement: String
    }

    private enum AutocorrectTiming {
        static let slowDecisionLogThreshold: CFTimeInterval = 0.05
        static let maximumApplyDelay: CFTimeInterval = 0.35
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        logStartup("controller init(coder:)")
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        logStartup("controller init")
    }

    deinit {
        #if DEBUG
        NSLog("[Keygram Startup] controller deinit")
        #endif
    }

    private static func makeInferenceEngine() -> AtlasInferenceEngine {
        let warmupStart = CFAbsoluteTimeGetCurrent()
        let runtimeStart = CFAbsoluteTimeGetCurrent()
        let runtime: AtlasModelRuntime?
        do {
            runtime = try AtlasONNXModelRuntime()
            logServiceWarmup(String(format: "ONNX runtime init %.3fs", CFAbsoluteTimeGetCurrent() - runtimeStart))
        } catch {
            runtime = nil
            logServiceWarmup(
                String(
                    format: "ONNX runtime unavailable; using frequency fallback %.3fs error=%@",
                    CFAbsoluteTimeGetCurrent() - runtimeStart,
                    String(describing: error)
                )
            )
        }

        let tokenizerStart = CFAbsoluteTimeGetCurrent()
        let tokenizer: AtlasTokenizing
        if let sentencePieceTokenizer = try? AtlasSentencePieceTokenizer() {
            tokenizer = sentencePieceTokenizer
        } else {
            tokenizer = AtlasTokenizer()
        }
        logServiceWarmup(String(format: "tokenizer init %.3fs", CFAbsoluteTimeGetCurrent() - tokenizerStart))

        let engineStart = CFAbsoluteTimeGetCurrent()
        let engine = AtlasInferenceEngine(runtime: runtime, tokenizer: tokenizer)
        logServiceWarmup(
            """
            inference diagnostics
            tokenizer=\(String(describing: type(of: tokenizer)))
            \(engine.diagnosticsDescription)
            """
        )
        logServiceWarmup(String(format: "engine init %.3fs total %.3fs", CFAbsoluteTimeGetCurrent() - engineStart, CFAbsoluteTimeGetCurrent() - warmupStart))
        return engine
    }

    private static func logServiceWarmup(_ message: String) {
        #if DEBUG
        NSLog("[Keygram Startup] %@", message)
        #endif
    }

    private var activeSession: AtlasSession {
        get {
            sessions.first ?? .fresh(name: AtlasSession.defaultName)
        }
        set {
            sessions = [newValue]
            AtlasSessionStore.shared.saveSessions(sessions)
        }
    }

    override func loadView() {
        let inputView = UIInputView(frame: .zero, inputViewStyle: .keyboard)
        inputView.allowsSelfSizing = true
        inputView.backgroundColor = .clear
        inputView.isOpaque = false
        inputView.clipsToBounds = false
        inputView.layer.actions = Self.disabledLayerActions
        view = inputView

        let height = inputView.heightAnchor.constraint(equalToConstant: LayoutMetric.keyboardHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        inputHeightConstraint = height
        preferredContentSize = CGSize(width: 0, height: LayoutMetric.keyboardHeight)

        logStartup("loadView")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logStartup("viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logStartup("viewWillAppear bounds=\(view.bounds)")
        hasEnteredPresentation = true
        if keyboardView == nil {
            installFreshKeyboardSurface(reason: "viewWillAppear")
        }
        keyboardView?.setReturnKeyType(textDocumentProxy.returnKeyType ?? .default)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logStartup("viewDidAppear bounds=\(view.bounds)")
        scheduleKeyboardRevealAfterStableLayout()
        loadAutocorrectIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        logStartup("viewWillDisappear bounds=\(view.bounds)")
        hasEnteredPresentation = false
        pendingPresentationReveal?.cancel()
        pendingPresentationReveal = nil
        pendingSuggestionRefresh?.cancel()
        pendingSuggestionRefresh = nil
        pendingEngineWarmup?.cancel()
        pendingEngineWarmup = nil
        pendingUndoExpiration?.cancel()
        pendingUndoExpiration = nil
        undoPillExpiresAt = nil
        needsSuggestionRefreshAfterInference = false
        teardownKeyboardSurface(reason: "viewWillDisappear")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        logStartup("viewDidDisappear bounds=\(view.bounds)")
        teardownKeyboardSurface(reason: "viewDidDisappear")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        logStartup("viewDidLayoutSubviews bounds=\(view.bounds)")
        configureTouchDecoderIfNeeded()
        scheduleKeyboardRevealAfterStableLayout()
    }

    override func updateViewConstraints() {
        inputHeightConstraint?.constant = currentKeyboardHeight
        super.updateViewConstraints()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        pendingSuggestionRefresh?.cancel()
        pendingEngineWarmup?.cancel()
        pendingEngineWarmup = nil
        needsSuggestionRefreshAfterInference = false
        liveWordDecoder.reset()
        needsLiveAutocorrectRefresh = false
        logStartup("textWillChange")
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        logPendingInputDidChange()
        keyboardView?.setReturnKeyType(textDocumentProxy.returnKeyType ?? .default)
        keyboardView?.setAIRewriteEnabled(shouldUseAIRewrite())
        scheduleSuggestionRefresh()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        logStartup("didReceiveMemoryWarning")
    }

    private func installFreshKeyboardSurface(reason: String) {
        let installStart = CFAbsoluteTimeGetCurrent()
        teardownKeyboardSurface(reason: "\(reason) preinstall")
        currentKeyboardHeight = LayoutMetric.keyboardHeight
        inputHeightConstraint?.constant = currentKeyboardHeight
        preferredContentSize = CGSize(width: 0, height: currentKeyboardHeight)

        UIView.performWithoutAnimation {
            let surfaceInitStart = CFAbsoluteTimeGetCurrent()
            let surface = KeyboardSurfaceView()
            logStartup(String(format: "keyboard surface init %.3fs", CFAbsoluteTimeGetCurrent() - surfaceInitStart))
            surface.translatesAutoresizingMaskIntoConstraints = false
            surface.delegate = self
            surface.clipsToBounds = false
            let addSubviewStart = CFAbsoluteTimeGetCurrent()
            view.addSubview(surface)

            let constraints = [
                surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                surface.topAnchor.constraint(equalTo: view.topAnchor),
                surface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            logStartup(String(format: "keyboard surface add/layout %.3fs", CFAbsoluteTimeGetCurrent() - addSubviewStart))
            keyboardViewConstraints = constraints
            keyboardView = surface

            let configureStart = CFAbsoluteTimeGetCurrent()
            disableImplicitLayerActions(in: view)
            surface.setPersona(activeSession, statusName: engineStatusName)
            surface.setReturnKeyType(textDocumentProxy.returnKeyType ?? .default)
            surface.setShiftState(isShifted || isCapsLocked, capsLocked: isCapsLocked)
            surface.setSuggestions(displayedSuggestions)
            surface.setAIRewriteEnabled(shouldUseAIRewrite())
            logStartup(String(format: "keyboard surface configure %.3fs", CFAbsoluteTimeGetCurrent() - configureStart))
        }
        logStartup(String(format: "installed fresh keyboard surface (%@) total %.3fs", reason, CFAbsoluteTimeGetCurrent() - installStart))
        scheduleKeyboardRevealAfterStableLayout()
    }

    private func teardownKeyboardSurface(reason: String) {
        guard let keyboardView else { return }
        pendingPresentationReveal?.cancel()
        pendingPresentationReveal = nil
        keyboardView.prepareForTeardown()
        keyboardView.setPresentationContentVisible(false)
        keyboardView.delegate = nil
        NSLayoutConstraint.deactivate(keyboardViewConstraints)
        keyboardViewConstraints.removeAll()
        keyboardView.removeFromSuperview()
        self.keyboardView = nil
        logStartup("tore down keyboard surface (\(reason))")
    }

    private func scheduleKeyboardRevealAfterStableLayout() {
        // No-op: the surface is now visible from frame one so no deferred reveal is needed.
    }

    private var engineStatusName: String {
        guard shouldUseInferenceSuggestions() else { return activeSession.name }
        guard let engine else { return "AUTOCORRECT" }
        return engine.isModelBundleAvailable ? activeSession.name : "NO MODEL"
    }

    private func loadEngineIfNeeded() {
        guard shouldUseInferenceSuggestions() else { return }
        guard engine == nil, !isEngineLoading else { return }
        isEngineLoading = true
        logStartup("requesting shared lazy session/model load")

        EngineService.shared.loadIfNeeded { [weak self] result in
            guard let self else { return }
            self.sessions = [result.session]
            self.engine = result.engine
            self.isEngineLoading = false
            self.keyboardView?.setPersona(result.session, statusName: self.engineStatusName)
            self.logStartup(result.wasCached ? "attached cached shared engine" : "attached freshly loaded shared engine")
            self.scheduleSuggestionRefresh(after: 0)
        }
    }

    private func loadAutocorrectIfNeeded() {
        guard autocorrectEngine == nil, !isAutocorrectLoading else { return }
        isAutocorrectLoading = true
        AutocorrectService.shared.loadIfNeeded { [weak self] engine in
            guard let self else { return }
            self.autocorrectEngine = engine
            self.isAutocorrectLoading = false
            self.logStartup("attached shared autocorrect index")
            self.logStartup("autocorrect diagnostics \(engine.diagnosticsDescription)")
            self.migrateEngramLearningIfNeeded(using: engine)
            self.refreshLiveAutocorrect()
            self.scheduleSuggestionRefresh(after: 0)
        }
    }

    private func migrateEngramLearningIfNeeded(using autocorrectEngine: AtlasAutocorrectEngine) {
        guard !isEngramMigrationRunning else { return }
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
        let currentVersion = defaults.integer(forKey: AtlasConfiguration.engramLearningMigrationVersionKey)
        guard currentVersion < AtlasConfiguration.currentEngramLearningMigrationVersion else { return }

        isEngramMigrationRunning = true
        engramQueue.async { [weak self] in
            var session = AtlasSessionStore.shared.loadSessions().first ?? .fresh(name: AtlasSession.defaultName)
            let wordsToRemove = autocorrectEngine.likelyCorruptPersonalWords(in: session.engram)
            for word in wordsToRemove {
                session.engram.remove(word)
            }
            if !wordsToRemove.isEmpty {
                session.updatedAt = Date()
                AtlasSessionStore.shared.saveSessions([session])
            }
            defaults.set(
                AtlasConfiguration.currentEngramLearningMigrationVersion,
                forKey: AtlasConfiguration.engramLearningMigrationVersionKey
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isEngramMigrationRunning = false
                if !wordsToRemove.isEmpty {
                    self.sessions = [session]
                    self.keyboardView?.setPersona(session, statusName: self.engineStatusName)
                    self.refreshSuggestions()
                    self.logAutocorrect("removed likely corrupt learned words: \(wordsToRemove.joined(separator: ", "))")
                }
            }
        }
    }

    private func configureTouchDecoderIfNeeded() {
        guard touchDecoder == nil, let keyboardView else { return }

        guard isTouchModelLayoutGeometryReady(keyboardView) else {
            logTouchModel(
                String(
                    format: "waiting for final layout bounds=(%.1f, %.1f)",
                    keyboardView.bounds.width,
                    keyboardView.bounds.height
                )
            )
            return
        }

        let layout = keyboardView.touchModelLayoutSnapshot()
        guard isCompleteTouchModelLayout(layout) else {
            logTouchModel("waiting for complete layout keys=\(layout.count) letters=\(letterCount(in: layout))/\(TouchModel.requiredLetterCount)")
            return
        }

        let store = TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
        let needsSchemaReset = defaults.integer(forKey: AtlasConfiguration.touchModelSchemaVersionKey)
            < AtlasConfiguration.currentTouchModelSchemaVersion
        let model: TouchModel
        if needsSchemaReset {
            store?.deleteSavedModelSynchronously()
            defaults.set(false, forKey: AtlasConfiguration.personalizedTypingEnabledKey)
            defaults.set(
                AtlasConfiguration.currentTouchModelSchemaVersion,
                forKey: AtlasConfiguration.touchModelSchemaVersionKey
            )
            model = TouchModel(portraitLayout: layout, landscapeLayout: layout)
            logTouchModel("reset saved model for schema=\(AtlasConfiguration.currentTouchModelSchemaVersion)")
        } else {
            model = store?.load() ?? TouchModel(
                portraitLayout: layout,
                landscapeLayout: layout
            )
        }
        let repairedKeys = model.repairLayouts(portraitLayout: layout, landscapeLayout: layout)
        if !repairedKeys.isEmpty {
            logTouchModel("repaired missingKeys=\(repairedKeys.joined(separator: ","))")
        }
        store?.save(model)
        touchModelStore = store
        touchDecoder = KeygramDecoder(touchModel: model, store: store)
        logTouchModel(
            String(
                format: "observation model ready keys=%d letters=%d/%d learned=%d bounds=(%.1f, %.1f)",
                layout.count,
                model.completeLetterCount,
                TouchModel.requiredLetterCount,
                touchDecoder?.totalLearnedTaps ?? 0,
                keyboardView.bounds.width,
                keyboardView.bounds.height
            )
        )
    }

    private func isTouchModelLayoutGeometryReady(_ keyboardView: KeyboardSurfaceView) -> Bool {
        let bounds = keyboardView.bounds
        let targetHeight = currentKeyboardHeight
        return bounds.width > 0
            && bounds.height > 0
            && abs(bounds.height - targetHeight) <= 8
    }

    private func isCompleteTouchModelLayout(_ layout: [AtlasKeyboard.KeyLayout]) -> Bool {
        letterCount(in: layout) == TouchModel.requiredLetterCount
    }

    private func letterCount(in layout: [AtlasKeyboard.KeyLayout]) -> Int {
        Set(layout.compactMap { key -> String? in
            guard key.id.count == 1,
                  key.id.rangeOfCharacter(from: .letters) != nil
            else {
                return nil
            }
            return key.id
        }).count
    }

    private func touchOrientation() -> DeviceOrientation {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape {
            return .landscape
        }
        if orientation.isPortrait {
            return .portrait
        }
        return view.bounds.width > view.bounds.height ? .landscape : .portrait
    }

    private func observeTouchTap(_ key: KeyboardKey, at point: CGPoint) {
        configureTouchDecoderIfNeeded()
        guard let keyID = touchModelKeyID(for: key) else { return }
        touchDecoder?.observeTap(
            x: Double(point.x),
            y: Double(point.y),
            resolvedKey: keyID,
            orientation: touchOrientation()
        )
    }

    private func resolvedTouchCharacter(for value: String, at point: CGPoint) -> String {
        configureTouchDecoderIfNeeded()
        let visibleKey = value.lowercased()
        guard touchModelKeyID(for: .character(value)) == visibleKey else {
            return value
        }

        let personalizedTypingEnabled = shouldUsePersonalizedTyping()
        #if DEBUG
        NSLog(
            "[Keygram TouchModel] personalizedTyping toggle=%@ decoderReady=%@ learnedTaps=%d threshold=%d visible=%@",
            personalizedTypingEnabled ? "true" : "false",
            touchDecoder == nil ? "false" : "true",
            touchDecoder?.totalLearnedTaps ?? 0,
            AtlasConfiguration.personalizedTypingActivationThreshold,
            visibleKey
        )
        #endif

        return touchDecoder?.resolveTap(
            x: Double(point.x),
            y: Double(point.y),
            visibleKey: visibleKey,
            orientation: touchOrientation(),
            personalizedTypingEnabled: personalizedTypingEnabled
        ) ?? value
    }

    private func observeTouchBoundary(_ keyID: String, at point: CGPoint, actualWord: String?) {
        configureTouchDecoderIfNeeded()
        touchDecoder?.observeBoundaryTap(
            x: Double(point.x),
            y: Double(point.y),
            resolvedKey: keyID,
            orientation: touchOrientation(),
            actualWord: actualWord
        )
        logTouchModel("learnedTaps=\(touchDecoder?.totalLearnedTaps ?? 0)")
    }

    private func commitTouchWord(actualWord: String?) {
        configureTouchDecoderIfNeeded()
        touchDecoder?.commitPendingWord(actualWord: actualWord)
        logTouchModel("learnedTaps=\(touchDecoder?.totalLearnedTaps ?? 0)")
    }

    private func touchModelKeyID(for key: KeyboardKey) -> String? {
        switch key {
        case .character(let value):
            let normalized = value.lowercased()
            guard normalized.count == 1,
                  normalized.rangeOfCharacter(from: .letters) != nil
            else {
                return nil
            }
            return normalized
        case .space:
            return " "
        case .shift, .backspace, .returnKey, .globe, .modeToggle, .symbolToggle:
            return nil
        }
    }

    private func logTouchModel(_ message: String) {
        #if DEBUG
        NSLog("[Keygram TouchModel] %@", message)
        #endif
    }

    private func handleShiftTap(at timestamp: CFTimeInterval) {
        let doubleTapInterval: CFTimeInterval = 0.35
        let isDoubleTap = lastShiftTapAt.map { timestamp - $0 <= doubleTapInterval } ?? false

        if isDoubleTap, isShifted, !isCapsLocked {
            isCapsLocked = true
            isShifted = true
            lastShiftTapAt = nil
        } else if isShifted || isCapsLocked {
            isCapsLocked = false
            isShifted = false
            lastShiftTapAt = timestamp
        } else {
            isShifted = true
            lastShiftTapAt = timestamp
        }

        keyboardView?.setShiftState(isShifted || isCapsLocked, capsLocked: isCapsLocked)
    }

    private func consumeOneShotShiftIfNeeded() {
        guard isShifted, !isCapsLocked else { return }
        isShifted = false
        keyboardView?.setShiftState(false, capsLocked: false)
    }

    private func scheduleEngineLoadAfterTypingIdle(after delay: TimeInterval = 0.85) {
        guard shouldUseInferenceSuggestions() else { return }
        guard engine == nil, !isEngineLoading else { return }
        pendingEngineWarmup?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingEngineWarmup = nil
            guard self.shouldUseInferenceSuggestions() else { return }
            self.loadEngineIfNeeded()
        }
        pendingEngineWarmup = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func disableImplicitLayerActions(in root: UIView) {
        root.layer.actions = Self.disabledLayerActions
        for subview in root.subviews {
            disableImplicitLayerActions(in: subview)
        }
    }

    private func insert(_ text: String, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval, pathStartedAt: CFTimeInterval? = nil) {
        pendingRewriteUndo = nil
        acceptPendingAutocorrectionIfNeeded()
        let pathStartedAt = pathStartedAt ?? CACurrentMediaTime()
        let inserted = isShifted || isCapsLocked ? text.uppercased() : text
        let contextBeforeCharacter = contextBeforeInput()
        insertTextIntoDocument(inserted, label: "key \(loggableInput(inserted))", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
        currentDraftText.append(contentsOf: inserted)
        liveWordDecoder.append(inserted, leftContextBeforeInput: contextBeforeCharacter)
        consumeOneShotShiftIfNeeded()
        refreshLiveAutocorrect()
        scheduleSuggestionRefresh()
    }

    private func insertTextIntoDocument(_ text: String, label: String, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval, pathStartedAt: CFTimeInterval? = nil) {
        let beforeInsert = CACurrentMediaTime()
        if let pathStartedAt {
            logInputLatency(
                String(
                    format: "%@ handler->beforeInsert %.3fms",
                    label,
                    elapsedMilliseconds(from: pathStartedAt, to: beforeInsert)
                )
            )
        }
        logInputLatency(
            String(
                format: "%@ touchDown->beforeInsert %.3fms touchUp->beforeInsert %.3fms touchDuration %.3fms",
                label,
                elapsedMilliseconds(from: touchStartedAt, to: beforeInsert),
                elapsedMilliseconds(from: touchEndedAt, to: beforeInsert),
                elapsedMilliseconds(from: touchStartedAt, to: touchEndedAt)
            )
        )

        enqueuePendingInputLatency(label: label, touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, submittedAt: beforeInsert)
        textDocumentProxy.insertText(text)

        let afterInsert = CACurrentMediaTime()
        logInputLatency(
            String(
                format: "%@ insertCall %.3fms touchDown->afterInsert %.3fms touchUp->afterInsert %.3fms",
                label,
                elapsedMilliseconds(from: beforeInsert, to: afterInsert),
                elapsedMilliseconds(from: touchStartedAt, to: afterInsert),
                elapsedMilliseconds(from: touchEndedAt, to: afterInsert)
            )
        )
    }

    private func deleteBackwardFromDocument(label: String, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval, pathStartedAt: CFTimeInterval? = nil) {
        let beforeDelete = CACurrentMediaTime()
        if let pathStartedAt {
            logInputLatency(
                String(
                    format: "%@ handler->beforeDelete %.3fms",
                    label,
                    elapsedMilliseconds(from: pathStartedAt, to: beforeDelete)
                )
            )
        }
        logInputLatency(
            String(
                format: "%@ touchDown->beforeDelete %.3fms touchUp->beforeDelete %.3fms touchDuration %.3fms",
                label,
                elapsedMilliseconds(from: touchStartedAt, to: beforeDelete),
                elapsedMilliseconds(from: touchEndedAt, to: beforeDelete),
                elapsedMilliseconds(from: touchStartedAt, to: touchEndedAt)
            )
        )

        enqueuePendingInputLatency(label: label, touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, submittedAt: beforeDelete)
        textDocumentProxy.deleteBackward()

        let afterDelete = CACurrentMediaTime()
        logInputLatency(
            String(
                format: "%@ deleteCall %.3fms touchDown->afterDelete %.3fms touchUp->afterDelete %.3fms",
                label,
                elapsedMilliseconds(from: beforeDelete, to: afterDelete),
                elapsedMilliseconds(from: touchStartedAt, to: afterDelete),
                elapsedMilliseconds(from: touchEndedAt, to: afterDelete)
            )
        )
    }

    private func elapsedMilliseconds(from start: CFTimeInterval, to end: CFTimeInterval) -> Double {
        (end - start) * 1_000
    }

    private func enqueuePendingInputLatency(label: String, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval, submittedAt: CFTimeInterval) {
        pendingInputLatencyEvents.append(InputLatencyEvent(label: label, touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, submittedAt: submittedAt))
        if pendingInputLatencyEvents.count > 32 {
            pendingInputLatencyEvents.removeFirst(pendingInputLatencyEvents.count - 32)
        }
    }

    private func logPendingInputDidChange() {
        guard !pendingInputLatencyEvents.isEmpty else { return }
        let event = pendingInputLatencyEvents.removeFirst()
        let didChangeAt = CACurrentMediaTime()
        guard didChangeAt - event.submittedAt < 2 else {
            logInputLatency(
                String(
                    format: "%@ discarded stale textDidChange latency %.3fs",
                    event.label,
                    didChangeAt - event.submittedAt
                )
            )
            return
        }
        logInputLatency(
            String(
                format: "%@ touchDown->textDidChange %.3fms touchUp->textDidChange %.3fms submit->textDidChange %.3fms",
                event.label,
                elapsedMilliseconds(from: event.touchStartedAt, to: didChangeAt),
                elapsedMilliseconds(from: event.touchEndedAt, to: didChangeAt),
                elapsedMilliseconds(from: event.submittedAt, to: didChangeAt)
            )
        )
    }

    private func loggableInput(_ text: String) -> String {
        switch text {
        case " ":
            return "space"
        case "\n":
            return "return"
        default:
            return "'\(text)'"
        }
    }

    private func logInputLatency(_ message: String) {
        #if DEBUG
        NSLog("[Keygram InputLatency] %@", message)
        #endif
    }

    private func contextBeforeInput() -> String {
        textDocumentProxy.documentContextBeforeInput ?? ""
    }

    private func shouldSkipAutocorrectForCurrentField() -> Bool {
        guard userDefaultsEnabled(AtlasConfiguration.autocorrectEnabledKey, defaultValue: true) else {
            return true
        }

        switch textDocumentProxy.keyboardType {
        case .URL, .emailAddress, .webSearch, .namePhonePad, .phonePad:
            return true
        default:
            break
        }

        return textDocumentProxy.autocorrectionType == .no
    }

    private func shouldUsePersonalizedAutocorrect() -> Bool {
        userDefaultsEnabled(AtlasConfiguration.personalizedAutocorrectEnabledKey, defaultValue: true)
    }

    private func shouldUseInferenceSuggestions() -> Bool {
        userDefaultsEnabled(AtlasConfiguration.inferenceSuggestionsEnabledKey, defaultValue: true)
    }

    private func shouldUseAIRewrite() -> Bool {
        userDefaultsEnabled(AtlasConfiguration.aiRewriteEnabledKey, defaultValue: true)
    }

    private func hasAcceptedAIRewriteDisclosure() -> Bool {
        userDefaultsEnabled(AtlasConfiguration.aiRewriteDisclosureAcceptedKey, defaultValue: false)
    }

    private func setAcceptedAIRewriteDisclosure() {
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
        defaults.set(true, forKey: AtlasConfiguration.aiRewriteDisclosureAcceptedKey)
    }

    private func shouldUsePersonalizedTyping() -> Bool {
        userDefaultsEnabled(AtlasConfiguration.personalizedTypingEnabledKey, defaultValue: false)
    }

    private func shouldLearnNewWords() -> Bool {
        userDefaultsEnabled(AtlasConfiguration.learnNewWordsEnabledKey, defaultValue: true)
    }

    private func userDefaultsEnabled(_ key: String, defaultValue: Bool) -> Bool {
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func scheduleSuggestionRefresh(after delay: TimeInterval = 0.12) {
        pendingSuggestionRefresh?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.refreshSuggestions()
        }
        pendingSuggestionRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func refreshSuggestions() {
        let context = contextBeforeInput()
        let selectedWord = selectedCorrectionWord()
        let shouldUseModel = shouldUseModelSuggestions(context: context, selectedWord: selectedWord)
        guard shouldUseModel else {
            suggestionGeneration += 1
            needsSuggestionRefreshAfterInference = false
            applySuggestions(lightweightSuggestions(context: context, selectedWord: selectedWord))
            return
        }

        guard let engine else {
            if shouldUseInferenceSuggestions(),
               shouldGenerateSuggestions(context: context, selectedWord: selectedWord) {
                loadEngineIfNeeded()
            }
            applySuggestions(lightweightSuggestions(context: context, selectedWord: selectedWord))
            return
        }

        let rightContext = textDocumentProxy.documentContextAfterInput ?? ""
        let session = activeSession
        let modelContext = selectedWord == nil ? nextWordPredictionContext(from: context) : context
        let request = SuggestionRequest(
            context: modelContext,
            selectedWord: selectedWord,
            rightContext: rightContext,
            sessionUpdatedAt: session.updatedAt
        )

        guard request != lastSuggestionRequest else { return }

        guard shouldGenerateSuggestions(context: context, selectedWord: selectedWord) else {
            suggestionGeneration += 1
            needsSuggestionRefreshAfterInference = false
            currentDraftText.removeAll()
            applySuggestions([])
            inferenceQueue.async { [weak self] in
                self?.engine?.resetCurrentDraftMemory()
            }
            return
        }

        guard !isSuggestionInferenceRunning else {
            suggestionGeneration += 1
            needsSuggestionRefreshAfterInference = true
            return
        }

        let correctionLeftContext = selectedWord.map { leftContextForCorrection(context, selectedWord: $0) }
        let global = Engram()
        let loadedAutocorrectEngine = autocorrectEngine
        let usePersonalizedAutocorrect = shouldUsePersonalizedAutocorrect()
        suggestionGeneration += 1
        let generation = suggestionGeneration
        lastSuggestionRequest = request
        isSuggestionInferenceRunning = true

        inferenceQueue.async { [weak self] in
            guard let self else { return }
            var suggestions: [AtlasSuggestion] = []
            if let selectedWord {
                self.logAutocorrect(
                    "selected='\(selectedWord)' leftContext='\(self.logSnippet(correctionLeftContext ?? context))' rightContext='\(self.logSnippet(rightContext))'"
                )
                suggestions = engine.corrections(
                    for: selectedWord,
                    leftContext: correctionLeftContext ?? context,
                    rightContext: rightContext,
                    session: session,
                    globalEngram: global
                )
                self.logAutocorrect(
                    "corrections for '\(selectedWord)' -> \(suggestions.map { "\($0.text):\(String(format: "%.3f", $0.score))" }.joined(separator: ", "))"
                )
                if let loadedAutocorrectEngine,
                   let decision = loadedAutocorrectEngine.correction(
                    for: selectedWord,
                    leftContext: correctionLeftContext ?? context,
                    sessionEngram: session.engram,
                    globalEngram: global,
                    feedback: usePersonalizedAutocorrect ? AutocorrectFeedbackStore.shared.snapshot() : AutocorrectFeedbackSnapshot()
                   ) {
                    let productionSuggestion = AtlasSuggestion(
                        text: decision.replacement,
                        kind: .correction,
                        score: decision.confidence
                    )
                    suggestions = self.mergingCorrectionSuggestion(productionSuggestion, into: suggestions)
                    self.logAutocorrect(
                        String(
                            format: "production correction for '%@' -> '%@' confidence=%.3f margin=%.3f",
                            selectedWord,
                            decision.replacement,
                            decision.confidence,
                            decision.margin
                        )
                    )
                }
            }

            if suggestions.isEmpty {
                if let selectedWord {
                    self.logAutocorrect("no correction candidates for '\(selectedWord)'; falling back to normal suggestions")
                }
                suggestions = engine.suggestions(for: modelContext, session: session, globalEngram: global)
            }

            DispatchQueue.main.async {
                self.isSuggestionInferenceRunning = false
                if generation == self.suggestionGeneration {
                    self.applySuggestions(suggestions)
                }
                if self.needsSuggestionRefreshAfterInference {
                    self.needsSuggestionRefreshAfterInference = false
                    self.scheduleSuggestionRefresh(after: 0.08)
                }
            }
        }
    }

    private nonisolated func mergingCorrectionSuggestion(
        _ suggestion: AtlasSuggestion,
        into suggestions: [AtlasSuggestion]
    ) -> [AtlasSuggestion] {
        var merged = suggestions.filter { $0.text.lowercased() != suggestion.text.lowercased() }
        merged.append(suggestion)
        return Array(merged.sorted { $0.score > $1.score }.prefix(AtlasConfiguration.maxSuggestions))
    }

    private func shouldGenerateSuggestions(context: String, selectedWord: String?) -> Bool {
        if selectedWord != nil { return true }
        return context.rangeOfCharacter(from: .letters) != nil
            || context.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func shouldUseModelSuggestions(context: String, selectedWord: String?) -> Bool {
        guard shouldUseInferenceSuggestions() else { return false }
        if selectedWord != nil { return true }
        return endsInWhitespace(context)
    }

    private func endsInWhitespace(_ text: String) -> Bool {
        guard let scalar = text.unicodeScalars.last else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }

    private func nextWordPredictionContext(from context: String, maxWords: Int = 10) -> String {
        guard maxWords > 0 else { return context }

        var wordRanges: [Range<String.Index>] = []
        context.enumerateSubstrings(in: context.startIndex..<context.endIndex, options: [.byWords]) { _, range, _, _ in
            wordRanges.append(range)
        }

        guard wordRanges.count > maxWords,
              let start = wordRanges.suffix(maxWords).first?.lowerBound
        else {
            return context
        }

        return String(context[start...])
    }

    private func lightweightSuggestions(context: String, selectedWord: String?) -> [AtlasSuggestion] {
        guard selectedWord == nil,
              let partial = PartialWordDetector.partialWord(in: context),
              let autocorrectEngine
        else {
            return []
        }
        return autocorrectEngine.completions(
            for: partial,
            leftContext: leftContextBeforeLastWord(context: context, word: partial),
            sessionEngram: activeSession.engram,
            globalEngram: Engram()
        )
    }

    private func applySuggestions(_ suggestions: [AtlasSuggestion]) {
        guard suggestions != displayedSuggestions else { return }
        displayedSuggestions = suggestions
        if let undoPillExpiresAt, undoPillExpiresAt > Date() {
            return
        }
        keyboardView?.setSuggestions(suggestions)
    }

    private func acceptSuggestion(_ suggestion: AtlasSuggestion, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval) {
        pendingRewriteUndo = nil
        if suggestion.kind == .undoAutocorrection {
            _ = undoLastAutocorrection(touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt)
            liveWordDecoder.reset()
            return
        }

        acceptPendingAutocorrectionIfNeeded()
        liveWordDecoder.reset()
        let pathStartedAt = CACurrentMediaTime()
        let context = contextBeforeInput()
        commitTouchWord(actualWord: suggestion.text)
        if suggestion.kind == .correction, let selectedWord = selectedCorrectionWord() {
            logAutocorrect("accepted correction '\(selectedWord)' -> '\(suggestion.text)'")
            insertTextIntoDocument(suggestion.text, label: "suggestion '\(suggestion.text)'", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
        } else if let partial = PartialWordDetector.partialWord(in: context),
           shouldReplacePartial(partial, with: suggestion.text, suggestionKind: suggestion.kind) {
            let beforeReplacement = CACurrentMediaTime()
            logInputLatency(
                String(
                    format: "suggestion '%@' touch->beforeReplacement %.3fms deleting=%d",
                    suggestion.text,
                    elapsedMilliseconds(from: touchStartedAt, to: beforeReplacement),
                    partial.count
                )
            )
            for _ in partial {
                textDocumentProxy.deleteBackward()
            }
            replaceDraftSuffix(partial, with: suggestion.text + " ")
            insertTextIntoDocument(suggestion.text + " ", label: "suggestion '\(suggestion.text)'", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
        } else {
            currentDraftText.append(contentsOf: suggestion.text + " ")
            insertTextIntoDocument(suggestion.text + " ", label: "suggestion '\(suggestion.text)'", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
        }

        learn(suggestion.text)
        refreshSuggestions()
    }

    private func shouldReplacePartial(_ partial: String, with suggestion: String, suggestionKind: AtlasSuggestionKind) -> Bool {
        suggestionKind == .completion || suggestion.localizedCaseInsensitiveCompare(partial) == .orderedSame || suggestion.lowercased().hasPrefix(partial.lowercased())
    }

    private func openAIRewriteMode() {
        guard shouldUseAIRewrite() else {
            keyboardView?.setAIRewriteEnabled(false)
            return
        }

        guard hasAcceptedAIRewriteDisclosure() else {
            keyboardView?.showAIRewriteDisclosure()
            return
        }

        keyboardView?.showAIRewriteStyles()
    }

    private func submitAIRewrite(style: AIRewriteStyle) {
        guard !isAIRewriteRunning else { return }
        guard let target = currentRewriteTarget() else {
            showTemporaryToolbarMessage("Nothing to rewrite")
            return
        }

        isAIRewriteRunning = true
        aiRewriteGeneration += 1
        let generation = aiRewriteGeneration
        keyboardView?.showAIRewriteStyles(loadingStyle: style)

        aiRewriteService.rewrite(text: target.promptText, style: style) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, generation == self.aiRewriteGeneration else { return }
                self.isAIRewriteRunning = false

                switch result {
                case .success(let rewrite):
                    self.applyAIRewrite(rewrite, target: target)
                case .failure:
                    self.showTemporaryToolbarMessage("Couldn't reach AI - check connection")
                }
            }
        }
    }

    private func currentRewriteTarget() -> RewriteTarget? {
        if let selected = textDocumentProxy.selectedText {
            let promptText = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            if !promptText.isEmpty {
                return RewriteTarget(promptText: promptText, textToReplace: selected, usesSelection: true)
            }
        }

        let context = contextBeforeInput()
        guard let fallback = fallbackRewriteText(in: context) else { return nil }
        let promptText = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty else { return nil }
        return RewriteTarget(promptText: promptText, textToReplace: fallback, usesSelection: false)
    }

    private func fallbackRewriteText(in context: String) -> String? {
        guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let boundaryCharacters = CharacterSet.newlines.union(CharacterSet(charactersIn: ".?!"))
        if let lastBoundary = context.rangeOfCharacter(from: boundaryCharacters, options: .backwards) {
            let suffix = String(context[lastBoundary.upperBound...])
            let candidate = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return suffix
            }
        }

        let maxCharacters = 700
        if context.count > maxCharacters {
            return String(context.suffix(maxCharacters))
        }
        return context
    }

    private func applyAIRewrite(_ rewrite: String, target: RewriteTarget) {
        let replacement = rewrite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty else {
            showTemporaryToolbarMessage("Couldn't rewrite that")
            return
        }

        acceptPendingAutocorrectionIfNeeded()
        liveWordDecoder.reset()
        pendingRewriteUndo = RewriteUndo(original: target.textToReplace, replacement: replacement)

        if target.usesSelection {
            textDocumentProxy.insertText(replacement)
        } else {
            for _ in target.textToReplace {
                textDocumentProxy.deleteBackward()
            }
            textDocumentProxy.insertText(replacement)
        }

        replaceDraftSuffix(target.textToReplace, with: replacement)
        keyboardView?.hideAIRewriteMode()
        scheduleSuggestionRefresh(after: 0)
    }

    private func undoLastAIRewrite() -> Bool {
        guard let undo = pendingRewriteUndo else { return false }
        let context = contextBeforeInput()
        guard context.hasSuffix(undo.replacement) else {
            pendingRewriteUndo = nil
            return false
        }

        pendingRewriteUndo = nil
        for _ in undo.replacement {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(undo.original)
        replaceDraftSuffix(undo.replacement, with: undo.original)
        keyboardView?.setSuggestions(displayedSuggestions)
        scheduleSuggestionRefresh(after: 0)
        return true
    }

    private func showTemporaryToolbarMessage(_ message: String) {
        keyboardView?.showToolbarMessage(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.keyboardView?.hideAIRewriteMode()
        }
    }

    private func pasteClipboardText() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            showTemporaryToolbarMessage("Clipboard is empty")
            return
        }

        pendingRewriteUndo = nil
        acceptPendingAutocorrectionIfNeeded()
        liveWordDecoder.reset()
        textDocumentProxy.insertText(pasted)
        currentDraftText.append(contentsOf: pasted)
        scheduleSuggestionRefresh(after: 0)
    }

    private func selectedCorrectionWord() -> String? {
        guard let selectedText = textDocumentProxy.selectedText else { return nil }
        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }

        let normalized = EngramNormalizer.normalize(trimmed)
        guard normalized.count >= 3, normalized.rangeOfCharacter(from: .letters) != nil else {
            return nil
        }
        return trimmed
    }

    private func leftContextForCorrection(_ context: String, selectedWord: String) -> String {
        guard context.localizedCaseInsensitiveContains(selectedWord),
              context.lowercased().hasSuffix(selectedWord.lowercased())
        else {
            return context
        }

        return String(context.dropLast(selectedWord.count))
    }

    private func logAutocorrect(_ message: String) {
        #if DEBUG
        NSLog("[Keygram Autocorrect] %@", message)
        #endif
    }

    private func logStartup(_ message: String) {
        #if DEBUG
        NSLog("[Keygram Startup +%.3fs] %@", CFAbsoluteTimeGetCurrent() - startupLogStart, message)
        #endif
    }

    private func logSnippet(_ text: String, limit: Int = 80) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: "\\n")
        guard collapsed.count > limit else { return collapsed }
        return "..." + String(collapsed.suffix(limit))
    }

    private func learn(_ word: String) {
        guard shouldLearnNewWords() else { return }
        let sessionName = activeSession.name
        let glaState = engine?.currentGLAState() ?? activeSession.glaState
        enqueueEngramUpdate { session in
            session.engram.learn(word, sessionName: sessionName)
            session.glaState = glaState
        }
    }

    private func observeTypedWord(_ word: String, assessment: Engram.LearningAssessment = Engram.LearningAssessment()) {
        guard shouldLearnNewWords() else { return }
        let sessionName = activeSession.name
        let glaState = engine?.currentGLAState() ?? activeSession.glaState
        enqueueEngramUpdate { session in
            session.engram.observeTyped(word, sessionName: sessionName, assessment: assessment)
            session.glaState = glaState
        }
    }

    private func observeTypedWordUsingAutocorrectLexicon(_ word: String) {
        let assessment = autocorrectEngine?.learningAssessment(for: word) ?? Engram.LearningAssessment()
        observeTypedWord(word, assessment: assessment)
    }

    private func refreshLiveAutocorrect() {
        guard !shouldSkipAutocorrectForCurrentField(),
              let autocorrectEngine,
              let snapshot = liveWordDecoder.snapshot()
        else {
            return
        }

        guard !isLiveAutocorrectRunning else {
            needsLiveAutocorrectRefresh = true
            return
        }

        isLiveAutocorrectRunning = true
        let session = activeSession
        let usePersonalizedAutocorrect = shouldUsePersonalizedAutocorrect()
        let startedAt = CACurrentMediaTime()

        autocorrectQueue.async { [weak self] in
            let feedback = usePersonalizedAutocorrect
                ? AutocorrectFeedbackStore.shared.snapshot()
                : AutocorrectFeedbackSnapshot()
            let decision = autocorrectEngine.correction(
                for: snapshot.rawWord,
                leftContext: snapshot.leftContext,
                sessionEngram: session.engram,
                globalEngram: Engram(),
                feedback: feedback
            )

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let elapsed = CACurrentMediaTime() - startedAt
                self.liveWordDecoder.storeDecision(decision, for: snapshot)
                if let decision {
                    self.logAutocorrect(
                        String(
                            format: "live candidate '%@' -> '%@' confidence=%.3f margin=%.3f elapsed=%.3fms",
                            decision.original,
                            decision.replacement,
                            decision.confidence,
                            decision.margin,
                            elapsed * 1_000
                        )
                    )
                } else {
                    self.logAutocorrect(
                        String(
                            format: "live no candidate '%@' elapsed=%.3fms",
                            snapshot.rawWord,
                            elapsed * 1_000
                        )
                    )
                }
                self.isLiveAutocorrectRunning = false
                if self.needsLiveAutocorrectRefresh {
                    self.needsLiveAutocorrectRefresh = false
                    self.refreshLiveAutocorrect()
                }
            }
        }
    }

    private func demoteMistypedWord(_ word: String) {
        guard shouldLearnNewWords() else { return }
        enqueueEngramUpdate { session in
            session.engram.demoteAfterAcceptedCorrection(word)
        }
    }

    private func acceptPendingAutocorrectionIfNeeded() {
        guard let pendingAutocorrection else { return }
        self.pendingAutocorrection = nil
        guard shouldUsePersonalizedAutocorrect() else { return }
        AutocorrectFeedbackStore.shared.recordAccepted(
            typed: pendingAutocorrection.original,
            correction: pendingAutocorrection.correction,
            contextKey: pendingAutocorrection.contextKey
        )
        demoteMistypedWord(pendingAutocorrection.original)
        learn(pendingAutocorrection.correction)
    }

    private func rejectPendingAutocorrection(_ undo: AutocorrectUndo) {
        pendingAutocorrection = nil
        guard shouldUsePersonalizedAutocorrect() else { return }
        AutocorrectFeedbackStore.shared.recordRejected(
            typed: undo.original.lowercased(),
            correction: undo.correction.lowercased(),
            contextKey: undo.contextKey
        )
    }

    private func learnWordBeforeSpace() {
        let context = contextBeforeInput()
        let word = PartialWordDetector.partialWord(in: context)
            ?? PartialWordDetector.lastCompletedWord(in: currentDraftText + " ")
        guard let word else { return }
        learn(word)
    }

    @discardableResult
    private func scheduleAutocorrectAfterSpace(
        typedWord: String?,
        contextBeforeSpace: String,
        touchEndedAt: CFTimeInterval
    ) -> Bool {
        guard !shouldSkipAutocorrectForCurrentField() else { return false }
        guard let typedWord, !typedWord.isEmpty else { return false }

        let leftContext = leftContextBeforeLastWord(context: contextBeforeSpace, word: typedWord)
        let contextKey = AtlasAutocorrectEngine.contextKey(from: leftContext)
        guard let autocorrectEngine else {
            if let quickDecision = AtlasAutocorrectEngine.quickJoinedWordCorrection(
                for: typedWord,
                leftContext: leftContext
            ) {
                logAutocorrect("quick joined-word correction '\(quickDecision.original)' -> '\(quickDecision.replacement)'")
                autocorrectGeneration += 1
                applyAutocorrectDecisionAfterSpace(
                    quickDecision,
                    contextKey: contextKey,
                    touchEndedAt: touchEndedAt,
                    decisionElapsed: 0
                )
                return true
            }
            loadAutocorrectIfNeeded()
            return false
        }

        autocorrectGeneration += 1
        let generation = autocorrectGeneration
        let decisionStartedAt = CACurrentMediaTime()
        let usePersonalizedAutocorrect = shouldUsePersonalizedAutocorrect()
        let session = activeSession

        autocorrectQueue.async { [weak self] in
            let feedback = usePersonalizedAutocorrect
                ? AutocorrectFeedbackStore.shared.snapshot()
                : AutocorrectFeedbackSnapshot()
            let decision = autocorrectEngine.correction(
                for: typedWord,
                leftContext: leftContext,
                sessionEngram: session.engram,
                globalEngram: Engram(),
                feedback: feedback
            )

            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.autocorrectGeneration else { return }
                let elapsed = CACurrentMediaTime() - decisionStartedAt
                if elapsed > AutocorrectTiming.slowDecisionLogThreshold {
                    self.logAutocorrect(
                        String(
                            format: "slow space correction '%@' elapsed=%.3fms",
                            typedWord,
                            elapsed * 1_000
                        )
                    )
                }
                guard let decision else {
                    self.logAutocorrect("no space correction for '\(typedWord)'")
                    self.observeTypedWord(typedWord, assessment: autocorrectEngine.learningAssessment(for: typedWord))
                    return
                }
                guard elapsed <= AutocorrectTiming.maximumApplyDelay else {
                    self.logAutocorrect(
                        String(
                            format: "skipped late space correction '%@' -> '%@' elapsed=%.3fms",
                            decision.original,
                            decision.replacement,
                            elapsed * 1_000
                        )
                    )
                    self.observeTypedWord(typedWord, assessment: autocorrectEngine.learningAssessment(for: typedWord))
                    return
                }

                self.applyAutocorrectDecisionAfterSpace(
                    decision,
                    contextKey: contextKey,
                    touchEndedAt: touchEndedAt,
                    decisionElapsed: elapsed
                )
            }
        }

        return true
    }

    private func applyAutocorrectDecisionAfterSpace(
        _ decision: AtlasAutocorrectDecision,
        contextKey: String,
        touchEndedAt: CFTimeInterval,
        decisionElapsed: CFTimeInterval
    ) {
        let suffix = decision.original + " "
        guard contextBeforeInput().hasSuffix(suffix) else {
            logAutocorrect("skipped stale space correction '\(decision.original)' -> '\(decision.replacement)'")
            return
        }

        logAutocorrect(
            String(
                format: "space correction '%@' -> '%@' confidence=%.3f margin=%.3f elapsed=%.3fms",
                decision.original,
                decision.replacement,
                decision.confidence,
                decision.margin,
                decisionElapsed * 1_000
            )
        )

        for _ in suffix {
            textDocumentProxy.deleteBackward()
        }
        replaceDraftSuffix(suffix, with: decision.replacement + " ")
        insertTextIntoDocument(decision.replacement + " ", label: "autocorrect '\(decision.original)'->'\(decision.replacement)'", touchStartedAt: touchEndedAt, touchEndedAt: touchEndedAt)
        pushUndo(original: decision.original, correction: decision.replacement, contextKey: contextKey)
        pendingAutocorrection = PendingAutocorrection(
            original: decision.original.lowercased(),
            correction: decision.replacement.lowercased(),
            contextKey: contextKey
        )
        scheduleSuggestionRefresh(after: 0)
    }

    private func lastTypedWordBeforeSpace() -> String? {
        if let contextWord = PartialWordDetector.partialWord(in: contextBeforeInput()) {
            return contextWord
        }
        return PartialWordDetector.partialWord(in: currentDraftText)
    }

    private func leftContextBeforeLastWord(context: String, word: String) -> String {
        guard !context.isEmpty else { return "" }
        let trimmedRight = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedRight.lowercased().hasSuffix(word.lowercased()) else { return context }
        return String(trimmedRight.dropLast(word.count))
    }

    private func pushUndo(original: String, correction: String, contextKey: String) {
        undoStack.append(AutocorrectUndo(original: original, correction: correction, contextKey: contextKey))
        if undoStack.count > 3 {
            undoStack.removeFirst(undoStack.count - 3)
        }
        showUndoPill(original: original, correction: correction)
    }

    private func showUndoPill(original: String, correction: String) {
        pendingUndoExpiration?.cancel()
        let expiry = Date().addingTimeInterval(2)
        undoPillExpiresAt = expiry
        keyboardView?.setSuggestions([
            AtlasSuggestion(
                text: "Undo \"\(original)->\(correction)\"",
                kind: .undoAutocorrection,
                score: 1
            )
        ])

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.undoPillExpiresAt = nil
            self.pendingUndoExpiration = nil
            self.keyboardView?.setSuggestions(self.displayedSuggestions)
        }
        pendingUndoExpiration = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func undoLastAutocorrection(touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval) -> Bool {
        guard let undo = undoStack.last else { return false }
        pendingUndoExpiration?.cancel()
        pendingUndoExpiration = nil
        undoPillExpiresAt = nil

        let context = contextBeforeInput()
        let suffixWithSpace = undo.correction + " "
        let suffix: String
        if context.hasSuffix(suffixWithSpace) {
            suffix = suffixWithSpace
        } else if context.hasSuffix(undo.correction) {
            suffix = undo.correction
        } else {
            keyboardView?.setSuggestions(displayedSuggestions)
            return false
        }

        _ = undoStack.popLast()
        rejectPendingAutocorrection(undo)
        learn(undo.original)
        for _ in suffix {
            textDocumentProxy.deleteBackward()
        }
        let replacement = undo.original + (suffix.hasSuffix(" ") ? " " : "")
        replaceDraftSuffix(suffix, with: replacement)
        insertTextIntoDocument(
            replacement,
            label: "undo autocorrect '\(undo.correction)'",
            touchStartedAt: touchStartedAt,
            touchEndedAt: touchEndedAt,
            pathStartedAt: CACurrentMediaTime()
        )
        keyboardView?.setSuggestions(displayedSuggestions)
        scheduleSuggestionRefresh()
        return true
    }

    private func endCurrentDraft() {
        commitTouchWord(actualWord: nil)
        let draftText = currentDraftText
        let sessionName = activeSession.name
        let glaState = engine?.currentGLAState() ?? activeSession.glaState
        pendingSuggestionRefresh?.cancel()
        engine?.resetCurrentDraftMemory()
        currentDraftText.removeAll()
        liveWordDecoder.reset()
        enqueueEngramUpdate { session in
            session.engram.learnMessage(draftText, sessionName: sessionName)
            session.glaState = glaState
        }
        scheduleSuggestionRefresh()
    }

    private func enqueueEngramUpdate(_ update: @escaping (inout AtlasSession) -> Void) {
        engramQueue.async {
            var session = AtlasSessionStore.shared.loadSessions().first ?? .fresh(name: AtlasSession.defaultName)
            update(&session)
            session.updatedAt = Date()
            AtlasSessionStore.shared.saveSessions([session])

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sessions = [session]
                self.keyboardView?.setPersona(session, statusName: self.engineStatusName)
                self.refreshSuggestions()
            }
        }
    }

    private func deleteLastDraftCharacter() {
        guard !currentDraftText.isEmpty else { return }
        currentDraftText.removeLast()
    }

    private func replaceDraftSuffix(_ suffix: String, with replacement: String) {
        if currentDraftText.lowercased().hasSuffix(suffix.lowercased()) {
            currentDraftText.removeLast(suffix.count)
        }
        currentDraftText.append(contentsOf: replacement)
    }

    private func replaceLastCompletedDraftWord(_ word: String, with replacement: String) {
        if currentDraftText.hasSuffix(" ") {
            currentDraftText.removeLast()
        }
        if currentDraftText.lowercased().hasSuffix(word.lowercased()) {
            currentDraftText.removeLast(word.count)
        }
        currentDraftText.append(contentsOf: replacement)
    }

}

extension KeyboardViewController: KeyboardSurfaceViewDelegate {
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didTap key: KeyboardKey, at point: CGPoint, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval) {
        let pathStartedAt = CACurrentMediaTime()
        switch key {
        case .character(let value):
            let resolvedValue = resolvedTouchCharacter(for: value, at: point)
            insert(resolvedValue, touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
        case .space:
            pendingRewriteUndo = nil
            let contextBeforeSpace = contextBeforeInput()
            let typedWord = lastTypedWordBeforeSpace()
            let liveDecision = liveWordDecoder.commitDecision()
            insertTextIntoDocument(" ", label: "key space", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
            currentDraftText.append(" ")
            observeTouchBoundary(" ", at: point, actualWord: nil)
            acceptPendingAutocorrectionIfNeeded()
            var didApplyLiveDecision = false
            if let liveDecision,
               let typedWord,
               liveDecision.original.localizedCaseInsensitiveCompare(typedWord) == .orderedSame {
                let leftContext = leftContextBeforeLastWord(context: contextBeforeSpace, word: typedWord)
                applyAutocorrectDecisionAfterSpace(
                    liveDecision,
                    contextKey: AtlasAutocorrectEngine.contextKey(from: leftContext),
                    touchEndedAt: touchEndedAt,
                    decisionElapsed: 0
                )
                didApplyLiveDecision = true
            }
            liveWordDecoder.reset()
            if !didApplyLiveDecision,
               !scheduleAutocorrectAfterSpace(typedWord: typedWord, contextBeforeSpace: contextBeforeSpace, touchEndedAt: touchEndedAt),
               let typedWord {
                observeTypedWordUsingAutocorrectLexicon(typedWord)
            }
            scheduleSuggestionRefresh()
        case .backspace:
            touchDecoder?.handleBackspace()
            if undoLastAIRewrite() {
                liveWordDecoder.reset()
            } else if !undoLastAutocorrection(touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt) {
                deleteBackwardFromDocument(label: "key backspace", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
                deleteLastDraftCharacter()
                liveWordDecoder.backspace()
                refreshLiveAutocorrect()
                scheduleSuggestionRefresh()
            } else {
                liveWordDecoder.reset()
            }
        case .returnKey:
            pendingRewriteUndo = nil
            observeTouchBoundary("\n", at: point, actualWord: nil)
            acceptPendingAutocorrectionIfNeeded()
            insertTextIntoDocument("\n", label: "key return", touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt, pathStartedAt: pathStartedAt)
            liveWordDecoder.reset()
            endCurrentDraft()
        case .shift:
            handleShiftTap(at: touchEndedAt)
        case .globe, .modeToggle, .symbolToggle:
            break
        }
    }

    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didAccept suggestion: AtlasSuggestion, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval) {
        acceptSuggestion(suggestion, touchStartedAt: touchStartedAt, touchEndedAt: touchEndedAt)
    }

    func keyboardSurfaceViewDidTapClipboard(_ view: KeyboardSurfaceView) {
        pasteClipboardText()
    }

    func keyboardSurfaceViewDidTapAIRewrite(_ view: KeyboardSurfaceView) {
        openAIRewriteMode()
    }

    func keyboardSurfaceViewDidAcceptAIRewriteDisclosure(_ view: KeyboardSurfaceView) {
        setAcceptedAIRewriteDisclosure()
        keyboardView?.showAIRewriteStyles()
    }

    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didSelectAIRewriteStyle style: AIRewriteStyle) {
        submitAIRewrite(style: style)
    }

    func keyboardSurfaceViewDidCancelAIRewrite(_ view: KeyboardSurfaceView) {
        aiRewriteGeneration += 1
        isAIRewriteRunning = false
    }

    func keyboardSurfaceView(_ view: KeyboardSurfaceView, preferredHeightDidChange height: CGFloat) {
        currentKeyboardHeight = height
        inputHeightConstraint?.constant = height
        preferredContentSize = CGSize(width: 0, height: height)
        view.setNeedsLayout()
        self.view.setNeedsUpdateConstraints()
    }

    func keyboardSurfaceViewDidLongPressBackspace(_ view: KeyboardSurfaceView) {
        touchDecoder?.handleBackspace()
        textDocumentProxy.deleteBackward()
        deleteLastDraftCharacter()
        liveWordDecoder.backspace()
        refreshLiveAutocorrect()
        refreshSuggestions()
    }

    func keyboardSurfaceViewDidLongPressSession(_ view: KeyboardSurfaceView) {
        liveWordDecoder.reset()
        endCurrentDraft()
    }

    func keyboardSurfaceViewDidRequestDismissKeyboard(_ view: KeyboardSurfaceView) {
        dismissKeyboard()
    }

    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didSetHapticsEnabled enabled: Bool) {
        // The surface already persisted the new value to the App Group store; nothing more to do.
        _ = enabled
    }
}
