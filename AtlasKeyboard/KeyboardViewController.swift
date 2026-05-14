import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum LayoutMetric {
        static let keyboardHeight: CGFloat = KeyboardSurfaceView.preferredKeyboardHeight
    }

    private var engine: AtlasInferenceEngine?
    private var sessions: [AtlasSession] = [.fresh(name: AtlasSession.defaultName)]

    private var isCapsLocked = false
    private var keyboardView: KeyboardSurfaceView?
    private var keyboardViewConstraints: [NSLayoutConstraint] = []
    private var inputHeightConstraint: NSLayoutConstraint?
    private let inferenceQueue = DispatchQueue(label: "com.wooshir.keygram.inference", qos: .userInitiated)
    private let engramQueue = DispatchQueue(label: "com.wooshir.keygram.engram", qos: .utility)
    private var currentDraftText = ""
    private var suggestionGeneration = 0
    private var pendingSuggestionRefresh: DispatchWorkItem?
    private var pendingPresentationReveal: DispatchWorkItem?
    private var lastSuggestionRequest: SuggestionRequest?
    private var displayedSuggestions: [AtlasSuggestion] = []
    private var isEngineLoading = false
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
        let runtime = try? AtlasONNXModelRuntime()
        logServiceWarmup(String(format: "ONNX runtime init %.3fs", CFAbsoluteTimeGetCurrent() - runtimeStart))

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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        logStartup("viewWillDisappear bounds=\(view.bounds)")
        hasEnteredPresentation = false
        pendingPresentationReveal?.cancel()
        pendingPresentationReveal = nil
        pendingSuggestionRefresh?.cancel()
        pendingSuggestionRefresh = nil
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
        scheduleKeyboardRevealAfterStableLayout()
    }

    override func updateViewConstraints() {
        inputHeightConstraint?.constant = LayoutMetric.keyboardHeight
        super.updateViewConstraints()
    }

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        pendingSuggestionRefresh?.cancel()
        logStartup("textWillChange")
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        keyboardView?.setReturnKeyType(textDocumentProxy.returnKeyType ?? .default)
        scheduleSuggestionRefresh()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        logStartup("didReceiveMemoryWarning")
    }

    private func installFreshKeyboardSurface(reason: String) {
        teardownKeyboardSurface(reason: "\(reason) preinstall")

        UIView.performWithoutAnimation {
            let surface = KeyboardSurfaceView()
            surface.translatesAutoresizingMaskIntoConstraints = false
            surface.delegate = self
            surface.clipsToBounds = false
            view.addSubview(surface)

            let constraints = [
                surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                surface.topAnchor.constraint(equalTo: view.topAnchor),
                surface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            keyboardViewConstraints = constraints
            keyboardView = surface

            disableImplicitLayerActions(in: view)
            surface.setPersona(activeSession, statusName: engineStatusName)
            surface.setReturnKeyType(textDocumentProxy.returnKeyType ?? .default)
            surface.setShiftState(isCapsLocked, capsLocked: isCapsLocked)
            surface.setSuggestions(displayedSuggestions)
        }
        logStartup("installed fresh keyboard surface (\(reason))")
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
        guard let engine else { return "LOADING" }
        return engine.isModelBundleAvailable ? activeSession.name : "NO MODEL"
    }

    private func loadEngineIfNeeded() {
        guard engine == nil, !isEngineLoading else { return }
        isEngineLoading = true
        logStartup("starting lazy session/model load")

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let warmupStart = CFAbsoluteTimeGetCurrent()
            let sessionStart = CFAbsoluteTimeGetCurrent()
            let loadedSessions = AtlasSessionStore.shared.loadSessions()
            Self.logServiceWarmup(String(format: "session load %.3fs", CFAbsoluteTimeGetCurrent() - sessionStart))
            let session = loadedSessions.first ?? .fresh(name: AtlasSession.defaultName)
            let engine = Self.makeInferenceEngine()
            engine.restore(glaState: session.glaState)

            DispatchQueue.main.async {
                guard let self else { return }
                self.sessions = [session]
                self.engine = engine
                self.isEngineLoading = false
                self.keyboardView?.setPersona(session, statusName: self.engineStatusName)
                self.logStartup(String(format: "lazy session/model load finished in %.3fs", CFAbsoluteTimeGetCurrent() - warmupStart))
                self.scheduleSuggestionRefresh(after: 0)
            }
        }
    }

    private func disableImplicitLayerActions(in root: UIView) {
        root.layer.actions = Self.disabledLayerActions
        for subview in root.subviews {
            disableImplicitLayerActions(in: subview)
        }
    }

    private func insert(_ text: String) {
        let inserted = isCapsLocked ? text.uppercased() : text
        textDocumentProxy.insertText(inserted)
        currentDraftText.append(contentsOf: inserted)
        scheduleSuggestionRefresh()
    }

    private func contextBeforeInput() -> String {
        textDocumentProxy.documentContextBeforeInput ?? ""
    }

    private func scheduleSuggestionRefresh(after delay: TimeInterval = 0.04) {
        pendingSuggestionRefresh?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.refreshSuggestions()
        }
        pendingSuggestionRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func refreshSuggestions() {
        guard let engine else {
            if shouldGenerateSuggestions(context: contextBeforeInput(), selectedWord: selectedCorrectionWord()) {
                loadEngineIfNeeded()
            }
            applySuggestions([])
            return
        }

        let context = contextBeforeInput()
        let selectedWord = selectedCorrectionWord()
        let rightContext = textDocumentProxy.documentContextAfterInput ?? ""
        let session = activeSession
        let request = SuggestionRequest(
            context: context,
            selectedWord: selectedWord,
            rightContext: rightContext,
            sessionUpdatedAt: session.updatedAt
        )

        guard request != lastSuggestionRequest else { return }
        lastSuggestionRequest = request

        guard shouldGenerateSuggestions(context: context, selectedWord: selectedWord) else {
            suggestionGeneration += 1
            currentDraftText.removeAll()
            applySuggestions([])
            inferenceQueue.async { [weak self] in
                self?.engine?.resetCurrentDraftMemory()
            }
            return
        }

        let correctionLeftContext = selectedWord.map { leftContextForCorrection(context, selectedWord: $0) }
        let global = Engram()
        suggestionGeneration += 1
        let generation = suggestionGeneration

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
            }

            if suggestions.isEmpty {
                if let selectedWord {
                    self.logAutocorrect("no correction candidates for '\(selectedWord)'; falling back to normal suggestions")
                }
                suggestions = engine.suggestions(for: context, session: session, globalEngram: global)
            }

            DispatchQueue.main.async {
                guard generation == self.suggestionGeneration else { return }
                self.applySuggestions(suggestions)
            }
        }
    }

    private func shouldGenerateSuggestions(context: String, selectedWord: String?) -> Bool {
        if selectedWord != nil { return true }
        return context.rangeOfCharacter(from: .letters) != nil
            || context.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func applySuggestions(_ suggestions: [AtlasSuggestion]) {
        guard suggestions != displayedSuggestions else { return }
        displayedSuggestions = suggestions
        keyboardView?.setSuggestions(suggestions)
    }

    private func acceptSuggestion(_ suggestion: AtlasSuggestion) {
        let context = contextBeforeInput()
        if suggestion.kind == .correction, let selectedWord = selectedCorrectionWord() {
            logAutocorrect("accepted correction '\(selectedWord)' -> '\(suggestion.text)'")
            textDocumentProxy.insertText(suggestion.text)
        } else if let partial = PartialWordDetector.partialWord(in: context),
           shouldReplacePartial(partial, with: suggestion.text, suggestionKind: suggestion.kind) {
            for _ in partial {
                textDocumentProxy.deleteBackward()
            }
            replaceDraftSuffix(partial, with: suggestion.text + " ")
            textDocumentProxy.insertText(suggestion.text + " ")
        } else {
            currentDraftText.append(contentsOf: suggestion.text + " ")
            textDocumentProxy.insertText(suggestion.text + " ")
        }

        learn(suggestion.text)
        refreshSuggestions()
    }

    private func shouldReplacePartial(_ partial: String, with suggestion: String, suggestionKind: AtlasSuggestionKind) -> Bool {
        suggestionKind == .completion || suggestion.localizedCaseInsensitiveCompare(partial) == .orderedSame || suggestion.lowercased().hasPrefix(partial.lowercased())
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
        let sessionName = activeSession.name
        let glaState = engine?.currentGLAState() ?? activeSession.glaState
        enqueueEngramUpdate { session in
            session.engram.learn(word, sessionName: sessionName)
            session.glaState = glaState
        }
    }

    private func learnWordBeforeSpace() {
        let context = contextBeforeInput()
        let word = PartialWordDetector.partialWord(in: context)
            ?? PartialWordDetector.lastCompletedWord(in: currentDraftText + " ")
        guard let word else { return }
        learn(word)
    }

    private func endCurrentDraft() {
        let draftText = currentDraftText
        let sessionName = activeSession.name
        let glaState = engine?.currentGLAState() ?? activeSession.glaState
        pendingSuggestionRefresh?.cancel()
        engine?.resetCurrentDraftMemory()
        currentDraftText.removeAll()
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
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didTap key: KeyboardKey) {
        switch key {
        case .character(let value):
            insert(value)
        case .space:
            learnWordBeforeSpace()
            textDocumentProxy.insertText(" ")
            currentDraftText.append(" ")
            scheduleSuggestionRefresh()
        case .backspace:
            textDocumentProxy.deleteBackward()
            deleteLastDraftCharacter()
            scheduleSuggestionRefresh()
        case .returnKey:
            textDocumentProxy.insertText("\n")
            endCurrentDraft()
        case .shift:
            isCapsLocked.toggle()
            view.setShiftState(isCapsLocked, capsLocked: isCapsLocked)
        case .globe, .modeToggle, .symbolToggle:
            break
        }
    }

    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didAccept suggestion: AtlasSuggestion) {
        acceptSuggestion(suggestion)
    }

    func keyboardSurfaceViewDidLongPressBackspace(_ view: KeyboardSurfaceView) {
        textDocumentProxy.deleteBackward()
        deleteLastDraftCharacter()
        refreshSuggestions()
    }

    func keyboardSurfaceViewDidLongPressSession(_ view: KeyboardSurfaceView) {
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
