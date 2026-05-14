import UIKit

protocol KeyboardSurfaceViewDelegate: AnyObject {
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didTap key: KeyboardKey)
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didAccept suggestion: AtlasSuggestion)
    func keyboardSurfaceViewDidLongPressBackspace(_ view: KeyboardSurfaceView)
    func keyboardSurfaceViewDidLongPressSession(_ view: KeyboardSurfaceView)
    func keyboardSurfaceViewDidRequestDismissKeyboard(_ view: KeyboardSurfaceView)
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didSetHapticsEnabled enabled: Bool)
}

enum KeyboardKey: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case returnKey
    case globe
    case modeToggle
    case symbolToggle
}

final class KeyboardSurfaceView: UIView {
    private enum LayoutMetric {
        // Suggestion bar is slimmer than a key row, matching the iOS system keyboard.
        static let toolbarHeight: CGFloat = 38
        static let rowHeight: CGFloat = 44
        // 1 toolbar + 4 key rows + a little vertical slack.
        static let keyboardContentHeight: CGFloat = toolbarHeight + rowHeight * 4 + 8
        static let buttonHorizontalInset: CGFloat = 3
        static let buttonVerticalInset: CGFloat = 4
        static let lowerSystemButtonWidth: CGFloat = 0.13
        static let bottomSystemButtonWidth: CGFloat = 0.123
        static let primaryButtonWidth: CGFloat = 0.25
        static let middleInputRowWidth: CGFloat = 0.90
        static let lowerAlphabeticInputRowWidth: CGFloat = 0.70
        static let lowerNumericInputRowWidth: CGFloat = 0.70
    }

    static var keyboardBackgroundColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.08, green: 0.09, blue: 0.1, alpha: 1) : UIColor(red: 227 / 255, green: 229 / 255, blue: 233 / 255, alpha: 1)
        }
    }

    weak var delegate: KeyboardSurfaceViewDelegate?

    // MARK: - Slot vocabulary (mirrors the KeyboardKit demo's layout sections)
    // rootStack stacks two slots vertically:
    //   1. toolbarSlot  — hosts suggestionStack (autocomplete bar + chevron) OR collapsedToolbar
    //   2. keyAreaSlot  — letter/number/symbol/emoji rows (keyStack)
    // menuOverlay layers on top of keyAreaSlot when isMenuToggled.
    private let backgroundPanel = UIView()
    private let rootStack = UIStackView()
    private let toolbarSlot = UIView()
    private let suggestionStack = UIStackView()
    private let collapsedToolbar = UIStackView()
    private let keyStack = UIStackView()
    private let menuOverlay = UIView()
    private var suggestionRowHeightConstraint: NSLayoutConstraint?
    private var keyRowHeightConstraints: [NSLayoutConstraint] = []
    private var suggestionButtons: [UIButton] = []
    private var keyButtons: [KeyboardButton] = []
    private var menuButtons: [UIButton] = []
    private var sessionButton: UIButton!
    private var personaPicker: UIScrollView!
    private var personaScrollStack: UIStackView?
    private var toolbarToggleButton: UIButton!
    private var hapticsToggleButton: UIButton?
    private var keyPreviewView: UIView?
    private var suggestionSeparatorLayers: [CALayer] = []
    private var isPersonaPickerOpen = false
    private var isMenuToggled = false
    private var personas: [AtlasSession] = []
    private var activePersonaName = AtlasSession.defaultName
    private var backspaceTimer: Timer?
    private var keyboardMode: KeyboardMode = .letters
    private var isShifted = false
    private var isCapsLocked = false
    private var returnKeyType: UIReturnKeyType = .default
    private var emojiPanelMode: EmojiPanelMode = .emojis
    private let keyFeedback = UIImpactFeedbackGenerator(style: .light)
    private var hapticsEnabled: Bool {
        get {
            let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
            guard defaults.object(forKey: AtlasConfiguration.hapticsEnabledKey) != nil else { return true }
            return defaults.bool(forKey: AtlasConfiguration.hapticsEnabledKey)
        }
        set {
            let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
            defaults.set(newValue, forKey: AtlasConfiguration.hapticsEnabledKey)
        }
    }

    private enum KeyboardMode {
        case letters
        case numbers
        case symbols
        case emoji
    }

    private enum EmojiPanelMode {
        case emojis
        case engrams
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    deinit {
        backspaceTimer?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let contentHeight = min(LayoutMetric.keyboardContentHeight, bounds.height)
        let contentFrame = CGRect(
            x: 0,
            y: max(0, bounds.height - contentHeight),
            width: bounds.width,
            height: contentHeight
        )
        backgroundPanel.frame = contentFrame
        rootStack.frame = contentFrame
        updateRowHeights(for: contentHeight)
        updateSuggestionSeparators()

        // The menu overlay covers the key area beneath the toolbar slot.
        let toolbarHeight = suggestionRowHeightConstraint?.constant ?? LayoutMetric.rowHeight
        menuOverlay.frame = CGRect(
            x: contentFrame.minX + 12,
            y: contentFrame.minY + toolbarHeight + 8,
            width: max(0, contentFrame.width - 24),
            height: max(0, contentFrame.height - toolbarHeight - 16)
        )
    }

    func prepareForTeardown() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
        keyPreviewView?.removeFromSuperview()
        keyPreviewView = nil
        isPersonaPickerOpen = false
        personaPicker?.alpha = 0
        personaPicker?.isHidden = true
        setMenuToggled(false, animated: false)
    }

    func setPresentationContentVisible(_ isVisible: Bool, animated: Bool = false) {
        UIView.performWithoutAnimation {
            backgroundPanel.alpha = isVisible ? 1 : 0
            rootStack.alpha = isVisible ? 1 : 0
        }
    }

    func setSuggestions(_ suggestions: [AtlasSuggestion]) {
        for (index, button) in suggestionButtons.enumerated() {
            if index < suggestions.count {
                let suggestion = suggestions[index]
                setSuggestionTitle(suggestion.text, for: button)
                button.accessibilityIdentifier = suggestion.kind.rawValue
                button.isEnabled = true
                button.alpha = 1
            } else {
                setSuggestionTitle("", for: button)
                button.isEnabled = false
                button.alpha = 0.4
            }
        }
        updateSuggestionSeparators()
    }

    func setSessionName(_ name: String) {
        activePersonaName = name
        updateSessionButton()
        rebuildPersonaCircles()
    }

    func setPersona(_ persona: AtlasSession, statusName: String) {
        self.personas = [persona]
        activePersonaName = statusName
        updateSessionButton()
        rebuildPersonaCircles()
    }

    func setReturnKeyType(_ type: UIReturnKeyType) {
        returnKeyType = type
        for button in keyButtons {
            guard button.key == .returnKey else { continue }
            button.setImage(UIImage(systemName: returnKeyIconName(for: type)), for: .normal)
        }
    }

    func setShiftState(_ shifted: Bool, capsLocked: Bool) {
        isShifted = shifted
        isCapsLocked = capsLocked
        for button in keyButtons {
            switch button.key {
            case .character(let character):
                button.setTitle(shifted || capsLocked ? character.uppercased() : character.lowercased(), for: .normal)
            case .shift:
                let icon = (shifted || capsLocked) ? "shift.fill" : "shift"
                button.setImage(UIImage(systemName: icon), for: .normal)
            default:
                break
            }
        }
    }

    private func build() {
        backgroundColor = .clear
        isOpaque = false

        backgroundPanel.backgroundColor = Self.keyboardBackgroundColor
        backgroundPanel.alpha = 1
        backgroundPanel.frame = CGRect(
            x: 0,
            y: 0,
            width: max(bounds.width, 320),
            height: LayoutMetric.keyboardContentHeight
        )
        addSubview(backgroundPanel)

        rootStack.axis = .vertical
        rootStack.spacing = 0
        rootStack.alpha = 1
        rootStack.frame = CGRect(
            x: 0,
            y: 0,
            width: max(bounds.width, 320),
            height: LayoutMetric.keyboardContentHeight
        )
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStack)

        buildToolbarSlot(in: rootStack)
        buildKeyAreaSlot(in: rootStack)
        buildMenuOverlay()
    }

    // MARK: - Toolbar slot
    // Hosts two toolbars in a single ZStack-like overlay:
    //   • suggestionStack (default): autocomplete chips + chevron toggle on the right
    //   • collapsedToolbar (when isMenuToggled): a single "dismiss keyboard" affordance on the right
    private func buildToolbarSlot(in root: UIStackView) {
        toolbarSlot.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(toolbarSlot)
        let height = toolbarSlot.heightAnchor.constraint(equalToConstant: LayoutMetric.toolbarHeight)
        height.isActive = true
        suggestionRowHeightConstraint = height

        buildAutocompleteToolbar()
        buildCollapsedToolbar()
        collapsedToolbar.alpha = 0
    }

    private func buildAutocompleteToolbar() {
        suggestionStack.axis = .horizontal
        suggestionStack.spacing = 0
        suggestionStack.distribution = .fill
        suggestionStack.translatesAutoresizingMaskIntoConstraints = false
        toolbarSlot.addSubview(suggestionStack)
        NSLayoutConstraint.activate([
            suggestionStack.leadingAnchor.constraint(equalTo: toolbarSlot.leadingAnchor),
            suggestionStack.trailingAnchor.constraint(equalTo: toolbarSlot.trailingAnchor),
            suggestionStack.topAnchor.constraint(equalTo: toolbarSlot.topAnchor),
            suggestionStack.bottomAnchor.constraint(equalTo: toolbarSlot.bottomAnchor)
        ])

        sessionButton = makePersonaButton(title: "AT")
        sessionButton.widthAnchor.constraint(equalToConstant: 42).isActive = true
        sessionButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        sessionButton.addTarget(self, action: #selector(sessionTapped), for: .touchUpInside)
        sessionButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(sessionLongPressed(_:))))

        buildPersonaRail()

        let chipsContainer = UIStackView()
        chipsContainer.axis = .horizontal
        chipsContainer.spacing = 0
        chipsContainer.distribution = .fillEqually
        chipsContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for index in 0..<AtlasConfiguration.maxSuggestions {
            let button = makeSuggestionButton(title: "")
            button.tag = index
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            suggestionButtons.append(button)
            chipsContainer.addArrangedSubview(button)
        }
        suggestionStack.addArrangedSubview(chipsContainer)

        toolbarToggleButton = makeToolbarChevron(expanded: false)
        toolbarToggleButton.addTarget(self, action: #selector(toolbarToggleTapped), for: .touchUpInside)
        suggestionStack.addArrangedSubview(toolbarToggleButton)

        buildSuggestionSeparators()
    }

    private func buildCollapsedToolbar() {
        collapsedToolbar.axis = .horizontal
        collapsedToolbar.spacing = 0
        collapsedToolbar.distribution = .fill
        collapsedToolbar.alignment = .center
        collapsedToolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbarSlot.addSubview(collapsedToolbar)
        NSLayoutConstraint.activate([
            collapsedToolbar.leadingAnchor.constraint(equalTo: toolbarSlot.leadingAnchor),
            collapsedToolbar.trailingAnchor.constraint(equalTo: toolbarSlot.trailingAnchor),
            collapsedToolbar.topAnchor.constraint(equalTo: toolbarSlot.topAnchor),
            collapsedToolbar.bottomAnchor.constraint(equalTo: toolbarSlot.bottomAnchor)
        ])

        let spacer = FlexibleSpacerView()
        collapsedToolbar.addArrangedSubview(spacer)

        let dismiss = UIButton(type: .system)
        dismiss.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
        dismiss.tintColor = .label
        dismiss.widthAnchor.constraint(equalToConstant: 44).isActive = true
        dismiss.addTarget(self, action: #selector(dismissKeyboardTapped), for: .touchUpInside)
        collapsedToolbar.addArrangedSubview(dismiss)

        let chevronClose = makeToolbarChevron(expanded: true)
        chevronClose.addTarget(self, action: #selector(toolbarToggleTapped), for: .touchUpInside)
        collapsedToolbar.addArrangedSubview(chevronClose)
    }

    private func makeToolbarChevron(expanded: Bool) -> UIButton {
        let button = UIButton(type: .system)
        let symbol = expanded ? "chevron.up" : "chevron.down"
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.tintColor = .label
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        return button
    }

    private func buildPersonaRail() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.clipsToBounds = false
        scroll.alpha = 0
        scroll.isHidden = true
        personaPicker = scroll

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        personaScrollStack = row

        suggestionStack.addArrangedSubview(scroll)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 2),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -2),
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
    }

    // MARK: - Key area slot
    private func buildKeyAreaSlot(in root: UIStackView) {
        keyStack.axis = .vertical
        keyStack.spacing = 0
        keyStack.distribution = .fill
        root.addArrangedSubview(keyStack)

        rebuildKeyboardRows()
    }

    // MARK: - Menu overlay
    // Layered over the key area when the toolbar chevron is toggled. Mirrors the demo's
    // DemoKeyboardMenu grid: an adaptive list of action buttons that overlays the keys
    // while they fade to alpha 0.
    private func buildMenuOverlay() {
        menuOverlay.alpha = 0
        menuOverlay.isUserInteractionEnabled = false
        menuOverlay.backgroundColor = .clear
        menuOverlay.frame = .zero
        addSubview(menuOverlay)

        let grid = UIStackView()
        grid.axis = .horizontal
        grid.spacing = 12
        grid.distribution = .fillEqually
        grid.alignment = .center
        grid.translatesAutoresizingMaskIntoConstraints = false
        menuOverlay.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: menuOverlay.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: menuOverlay.trailingAnchor),
            grid.centerYAnchor.constraint(equalTo: menuOverlay.centerYAnchor)
        ])

        let haptics = makeMenuItem(systemImage: "iphone.radiowaves.left.and.right", title: hapticsTitle(), tint: .systemGreen, action: #selector(menuHapticsTapped))
        hapticsToggleButton = haptics
        let dismiss = makeMenuItem(systemImage: "keyboard.chevron.compact.down", title: "Dismiss", tint: .systemOrange, action: #selector(menuDismissTapped))
        let close = makeMenuItem(systemImage: "xmark", title: "Close", tint: .systemRed, action: #selector(menuCloseTapped))

        for item in [haptics, dismiss, close] {
            menuButtons.append(item)
            grid.addArrangedSubview(item)
        }
    }

    private func hapticsTitle() -> String {
        hapticsEnabled ? "Haptics On" : "Haptics Off"
    }

    private func makeMenuItem(systemImage: String, title: String, tint: UIColor, action: Selector) -> UIButton {
        var config = UIButton.Configuration.gray()
        config.image = UIImage(systemName: systemImage)
        config.title = title
        config.imagePlacement = .top
        config.imagePadding = 6
        config.titleAlignment = .center
        config.baseForegroundColor = .label
        config.background.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.85)
        config.background.cornerRadius = 18
        var titleAttributes = AttributeContainer()
        titleAttributes.font = .systemFont(ofSize: 13, weight: .semibold)
        config.attributedTitle = AttributedString(title, attributes: titleAttributes)
        let button = UIButton(configuration: config)
        button.tintColor = tint
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 96).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func rebuildKeyboardRows() {
        let hideToolbar = keyboardMode == .emoji
        toolbarSlot.isHidden = hideToolbar
        suggestionStack.isHidden = hideToolbar
        keyStack.spacing = keyboardMode == .emoji ? 2 : 0
        keyButtons.removeAll()
        keyRowHeightConstraints.removeAll()
        keyStack.arrangedSubviews.forEach { view in
            keyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        switch keyboardMode {
        case .letters:
            buildLetterRows()
        case .numbers:
            buildNumberRows()
        case .symbols:
            buildSymbolRows()
        case .emoji:
            buildEmojiRows()
        }

        setShiftState(isShifted, capsLocked: isCapsLocked)
        setReturnKeyType(returnKeyType)
        setNeedsLayout()
    }

    private func buildLetterRows() {
        addCharacterRow("qwertyuiop")
        addCharacterRow("asdfghjkl", inputWidthMultiplier: LayoutMetric.middleInputRowWidth)

        let third = keyboardRow()
        addKey(.shift, title: "shift", to: third, widthMultiplier: LayoutMetric.lowerSystemButtonWidth)
        third.addArrangedSubview(FlexibleSpacerView())

        let zxcvKeys = inputCluster(for: "zxcvbnm".map(String.init))
        third.addArrangedSubview(zxcvKeys)
        zxcvKeys.widthAnchor.constraint(equalTo: third.widthAnchor, multiplier: LayoutMetric.lowerAlphabeticInputRowWidth).isActive = true

        third.addArrangedSubview(FlexibleSpacerView())
        let backspace = addKey(.backspace, title: "delete.left", to: third, widthMultiplier: LayoutMetric.lowerSystemButtonWidth)
        backspace.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:))))
        keyStack.addArrangedSubview(third)

        let bottom = keyboardRow()
        addKey(.modeToggle, title: "123", to: bottom, widthMultiplier: LayoutMetric.bottomSystemButtonWidth)
        addKey(.globe, title: "globe", to: bottom, widthMultiplier: LayoutMetric.bottomSystemButtonWidth)
        let spaceKey = addKey(.space, title: "space", to: bottom)
        spaceKey.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addKey(.returnKey, title: "return", to: bottom, widthMultiplier: LayoutMetric.primaryButtonWidth)
        keyStack.addArrangedSubview(bottom)
    }

    private func buildEmojiRows() {
        // addEmojiSearchRow()
        let topInset = UIView()
        topInset.heightAnchor.constraint(equalToConstant: 8).isActive = true
        keyStack.addArrangedSubview(topInset)

        addEmojiSectionLabel(emojiPanelMode == .engrams ? "Engrams" : "Emojis")

        switch emojiPanelMode {
        case .emojis:
            addEmojiGrid()
        case .engrams:
            keyStack.setCustomSpacing(8, after: keyStack.arrangedSubviews.last!)
            addEngramGrid()
        }

        addEmojiToolbar()
    }

    private func addEmojiGrid() {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.heightAnchor.constraint(equalToConstant: 232).isActive = true

        let grid = UIStackView()
        grid.axis = .horizontal
        grid.alignment = .top
        grid.spacing = 6
        grid.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 0),
            grid.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            grid.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            grid.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            grid.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        let emojis = [
            "😓", "🥱", "😶", "😵", "😟", "😴", "😵‍💫", "😝", "🤠",
            "🤗", "🫡", "🫥", "😁", "😮", "🤤", "🤐", "😷", "😈",
            "🤔", "🤫", "😐", "🙄", "😯", "😪", "😏", "🤒", "😠",
            "🫣", "🫠", "😑", "😮‍💨", "🥱", "😔", "🤢", "🤕", "👹",
            "🫢", "🤥", "😑", "☹️", "🥺", "😵", "🤮", "🤑", "👺",
            "😀", "😃", "😄", "😆", "😉", "😊", "😍", "😘", "😋",
            "😜", "🤪", "😎", "🥳", "😇", "🙂", "🙃", "😂", "🤣",
            "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "💔",
            "👍", "👎", "👏", "🙌", "🙏", "🤝", "💪", "👌", "✌️",
            "👋", "🤚", "🖐️", "✋", "👊", "🤟", "🤘", "☝️", "👇",
            "👀", "🧠", "👑", "💍", "💼", "🎒", "🕶️", "🎓", "💄",
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨",
            "🐯", "🦁", "🐮", "🐷", "🐸", "🐵", "🐔", "🐧", "🐦",
            "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🥝",
            "🍕", "🍔", "🍟", "🌮", "🍜", "🍣", "🍩", "🍪", "🎂",
            "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏐", "🎱", "🏓", "🏸",
            "🚗", "🚕", "🚌", "🚑", "🚒", "🚲", "✈️", "🚀", "⛵️",
            "🏠", "🏢", "🏥", "🏫", "🏨", "🏦", "⛪️", "🕌", "🛕",
            "⌚️", "📱", "💻", "⌨️", "🖥️", "🖨️", "📷", "🎥", "🎧",
            "💡", "🔦", "🧯", "🛠️", "🔑", "🎁", "🎈", "🎉", "🪄",
            "✅", "❌", "❗️", "❓", "⭐️", "🔥", "💧", "🌈", "☀️"
        ]

        let rowsPerColumn = 5
        for columnStart in stride(from: 0, to: emojis.count, by: rowsPerColumn) {
            let column = UIStackView()
            column.axis = .vertical
            column.spacing = 4
            column.distribution = .fillEqually
            column.widthAnchor.constraint(equalToConstant: 36).isActive = true

            for index in columnStart..<min(columnStart + rowsPerColumn, emojis.count) {
                column.addArrangedSubview(makeEmojiKey(emojis[index]))
            }

            grid.addArrangedSubview(column)
        }

        keyStack.addArrangedSubview(scroll)
    }

    private func addEngramGrid() {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.heightAnchor.constraint(equalToConstant: 226).isActive = true

        let pages = UIStackView()
        pages.axis = .horizontal
        pages.alignment = .top
        pages.spacing = 12
        pages.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(pages)

        NSLayoutConstraint.activate([
            pages.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            pages.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            pages.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            pages.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            pages.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        let rowsPerPage = 5
        let availableWidth = UIScreen.main.bounds.width - 12
        let spacingFraction: CGFloat = 0.3           // spacing = 30% of circleDiameter
        let minDiameter: CGFloat = 36
        let columnsPerPage = max(1, Int((availableWidth + minDiameter * spacingFraction) / (minDiameter * (1 + spacingFraction))))
        let circleDiameter = availableWidth / (CGFloat(columnsPerPage) + CGFloat(columnsPerPage - 1) * spacingFraction)
        let buttonSpacing = circleDiameter * spacingFraction
        let pageWidth = availableWidth
        let personasPerPage = rowsPerPage * columnsPerPage

        for pageStart in stride(from: 0, to: personas.count, by: personasPerPage) {
            let page = UIStackView()
            page.axis = .horizontal
            page.alignment = .top
            page.spacing = buttonSpacing
            page.distribution = .fill

            page.widthAnchor.constraint(equalToConstant: pageWidth).isActive = true

            for columnIndex in 0..<columnsPerPage {
                let column = UIStackView()
                column.axis = .vertical
                column.spacing = 8
                column.distribution = .fill
                column.widthAnchor.constraint(equalToConstant: circleDiameter).isActive = true

                for rowIndex in 0..<rowsPerPage {
                    let index = pageStart + rowIndex * columnsPerPage + columnIndex
                    if index < personas.count && index < pageStart + personasPerPage {
                        column.addArrangedSubview(makeEngramButton(for: personas[index], index: index, size: circleDiameter))
                    } else {
                        column.addArrangedSubview(makeEngramPlaceholder(size: circleDiameter))
                    }
                }

                page.addArrangedSubview(column)
            }

            pages.addArrangedSubview(page)
        }

        keyStack.addArrangedSubview(scroll)
    }

    private func addEmojiSearchRow() {
        let search = UIView()
        search.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.18, green: 0.19, blue: 0.21, alpha: 1) : UIColor(red: 239 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1)
        }
        search.layer.cornerRadius = 22
        search.translatesAutoresizingMaskIntoConstraints = false
        search.heightAnchor.constraint(equalToConstant: 46).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .secondaryLabel
        icon.translatesAutoresizingMaskIntoConstraints = false
        search.addSubview(icon)

        let label = UILabel()
        label.text = "Search Emoji"
        label.font = .systemFont(ofSize: 22, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        search.addSubview(label)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: search.leadingAnchor, constant: 20),
            icon.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: search.trailingAnchor, constant: -16)
        ])

        keyStack.addArrangedSubview(search)
    }

    private func addEmojiSectionLabel(_ title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .secondaryLabel
        label.heightAnchor.constraint(equalToConstant: 24).isActive = true
        keyStack.addArrangedSubview(label)
    }

    private func addEmojiToolbar() {
        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 12
        toolbar.distribution = .fill
        toolbar.heightAnchor.constraint(equalToConstant: 44).isActive = true

        toolbar.addArrangedSubview(makeKey(.modeToggle, title: "ABC", width: 58))

        let categoryScroll = UIScrollView()
        categoryScroll.showsHorizontalScrollIndicator = false
        categoryScroll.alwaysBounceHorizontal = true
        categoryScroll.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let categoryRow = UIStackView()
        categoryRow.axis = .horizontal
        categoryRow.alignment = .center
        categoryRow.spacing = 8
        categoryRow.translatesAutoresizingMaskIntoConstraints = false
        categoryScroll.addSubview(categoryRow)

        NSLayoutConstraint.activate([
            categoryRow.leadingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.leadingAnchor),
            categoryRow.trailingAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.trailingAnchor),
            categoryRow.topAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.topAnchor),
            categoryRow.bottomAnchor.constraint(equalTo: categoryScroll.contentLayoutGuide.bottomAnchor),
            categoryRow.heightAnchor.constraint(equalTo: categoryScroll.frameLayoutGuide.heightAnchor)
        ])

        // let personButton = makeEmojiCategoryButton(systemName: "person.crop.circle", selected: emojiPanelMode == .engrams)
        // personButton.addTarget(self, action: #selector(engramCategoryTapped), for: .touchUpInside)
        // categoryRow.addArrangedSubview(personButton)

        let emojiButton = makeEmojiCategoryButton(systemName: "face.smiling", selected: emojiPanelMode == .emojis)
        emojiButton.addTarget(self, action: #selector(emojiCategoryTapped), for: .touchUpInside)
        categoryRow.addArrangedSubview(emojiButton)

        toolbar.addArrangedSubview(categoryScroll)

        let backspace = makeKey(.backspace, title: "delete.left", width: 48)
        backspace.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:))))
        toolbar.addArrangedSubview(backspace)

        keyStack.addArrangedSubview(toolbar)
    }

    private func buildSymbolRows() {
        addCharacterRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="])
        addCharacterRow(["_", "\\", "|", "~", "<", ">", "\u{20AC}", "\u{00A3}", "\u{00A5}", "\u{2022}"])

        let third = keyboardRow()
        addKey(.symbolToggle, title: "123", to: third, widthMultiplier: LayoutMetric.lowerSystemButtonWidth)
        third.addArrangedSubview(FlexibleSpacerView())

        let punctuationKeys = inputCluster(for: [".", ",", "?", "!", "\u{2019}"])
        third.addArrangedSubview(punctuationKeys)
        punctuationKeys.widthAnchor.constraint(equalTo: third.widthAnchor, multiplier: LayoutMetric.lowerNumericInputRowWidth).isActive = true

        third.addArrangedSubview(FlexibleSpacerView())
        let backspace = addKey(.backspace, title: "delete.left", to: third, widthMultiplier: LayoutMetric.lowerSystemButtonWidth)
        backspace.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:))))
        keyStack.addArrangedSubview(third)

        let bottom = keyboardRow()
        addKey(.modeToggle, title: "ABC", to: bottom, widthMultiplier: LayoutMetric.bottomSystemButtonWidth)
        addKey(.globe, title: "globe", to: bottom, widthMultiplier: LayoutMetric.bottomSystemButtonWidth)
        let spaceKey = addKey(.space, title: "space", to: bottom)
        spaceKey.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addKey(.returnKey, title: "return", to: bottom, widthMultiplier: LayoutMetric.primaryButtonWidth)
        keyStack.addArrangedSubview(bottom)
    }

    private func buildNumberRows() {
        addCharacterRow("1234567890")
        addCharacterRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\u{201D}"])

        let third = keyboardRow()
        addKey(.symbolToggle, title: "#+=", to: third, widthMultiplier: LayoutMetric.lowerSystemButtonWidth)
        third.addArrangedSubview(FlexibleSpacerView())

        let punctuationKeys = inputCluster(for: [".", ",", "?", "!", "\u{2019}"])
        third.addArrangedSubview(punctuationKeys)
        punctuationKeys.widthAnchor.constraint(equalTo: third.widthAnchor, multiplier: LayoutMetric.lowerNumericInputRowWidth).isActive = true

        third.addArrangedSubview(FlexibleSpacerView())
        let backspace = addKey(.backspace, title: "delete.left", to: third, widthMultiplier: LayoutMetric.lowerSystemButtonWidth)
        backspace.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:))))
        keyStack.addArrangedSubview(third)

        let bottom = keyboardRow()
        addKey(.modeToggle, title: "ABC", to: bottom, widthMultiplier: LayoutMetric.bottomSystemButtonWidth)
        addKey(.globe, title: "globe", to: bottom, widthMultiplier: LayoutMetric.bottomSystemButtonWidth)
        let spaceKey = addKey(.space, title: "space", to: bottom)
        spaceKey.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addKey(.returnKey, title: "return", to: bottom, widthMultiplier: LayoutMetric.primaryButtonWidth)
        keyStack.addArrangedSubview(bottom)
    }

    private func addCharacterRow(_ characters: String, inputWidthMultiplier: CGFloat? = nil) {
        addCharacterRow(characters.map(String.init), inputWidthMultiplier: inputWidthMultiplier)
    }

    private func addCharacterRow(_ characters: [String], inputWidthMultiplier: CGFloat? = nil) {
        let row = keyboardRow()
        let keys = inputCluster(for: characters)

        if let inputWidthMultiplier {
            row.addArrangedSubview(FlexibleSpacerView())
            row.addArrangedSubview(keys)
            keys.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: inputWidthMultiplier).isActive = true
            row.addArrangedSubview(FlexibleSpacerView())
        } else {
            row.addArrangedSubview(keys)
        }

        keyStack.addArrangedSubview(row)
    }

    private func keyboardRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 0
        row.distribution = .fill
        let height = row.heightAnchor.constraint(equalToConstant: LayoutMetric.rowHeight)
        height.isActive = true
        keyRowHeightConstraints.append(height)
        return row
    }

    private func updateRowHeights(for contentHeight: CGFloat) {
        let toolbarVisible = !toolbarSlot.isHidden
        let toolbarHeight = toolbarVisible ? LayoutMetric.toolbarHeight : 0
        let keyRows = keyRowHeightConstraints.count
        guard keyRows > 0 else { return }

        let remaining = max(0, contentHeight - toolbarHeight)
        let rowHeight = min(LayoutMetric.rowHeight, remaining / CGFloat(keyRows))
        suggestionRowHeightConstraint?.constant = toolbarHeight
        keyRowHeightConstraints.forEach { $0.constant = rowHeight }
    }

    private func inputCluster(for characters: [String]) -> UIStackView {
        let keys = UIStackView()
        keys.axis = .horizontal
        keys.spacing = 0
        keys.distribution = .fillEqually
        keys.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for character in characters {
            let key = makeKey(.character(character), title: character, width: nil)
            keys.addArrangedSubview(keyContainer(for: key))
        }
        return keys
    }

    @discardableResult
    private func addKey(_ key: KeyboardKey, title: String, to row: UIStackView, widthMultiplier: CGFloat? = nil) -> KeyboardButton {
        let button = makeKey(key, title: title, width: nil)
        let container = keyContainer(for: button)
        row.addArrangedSubview(container)
        if let widthMultiplier {
            container.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: widthMultiplier).isActive = true
            container.setContentHuggingPriority(.required, for: .horizontal)
            container.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        return button
    }

    private func keyContainer(for button: KeyboardButton) -> UIView {
        let container = UIView()
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: LayoutMetric.buttonHorizontalInset),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -LayoutMetric.buttonHorizontalInset),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: LayoutMetric.buttonVerticalInset),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -LayoutMetric.buttonVerticalInset)
        ])
        return container
    }

    private func rowStack() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 5
        row.distribution = .fillEqually
        return row
    }

    private func makeSuggestionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = nil
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.72
        button.titleLabel?.allowsDefaultTighteningForTruncation = true
        button.contentHorizontalAlignment = .center
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }

    private func setSuggestionTitle(_ title: String, for button: UIButton) {
        guard button.title(for: .normal) != title else { return }
        button.setTitle(title, for: .normal)
    }

    private func buildSuggestionSeparators() {
        suggestionSeparatorLayers.forEach { $0.removeFromSuperlayer() }
        suggestionSeparatorLayers = (0..<max(0, AtlasConfiguration.maxSuggestions - 1)).map { _ in
            let layer = CALayer()
            layer.backgroundColor = UIColor.separator.withAlphaComponent(0.24).cgColor
            layer.cornerRadius = 0.5
            suggestionStack.layer.addSublayer(layer)
            return layer
        }
        setNeedsLayout()
    }

    private func updateSuggestionSeparators() {
        guard suggestionSeparatorLayers.count == max(0, suggestionButtons.count - 1) else { return }

        let scale = window?.windowScene?.screen.scale ?? traitCollection.displayScale
        let width = 1 / max(scale, 1)
        let height = max(0, suggestionStack.bounds.height - 20)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, layer) in suggestionSeparatorLayers.enumerated() {
            guard index < suggestionButtons.count - 1 else { continue }
            let button = suggestionButtons[index]
            let frame = button.convert(button.bounds, to: suggestionStack)
            layer.isHidden = suggestionStack.isHidden || button.isHidden || frame.isEmpty
            layer.frame = CGRect(x: frame.maxX - width / 2, y: 10, width: width, height: height)
        }
        CATransaction.commit()
    }

    private func makePersonaButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 21
        button.clipsToBounds = true
        button.backgroundColor = personaColor(for: activePersonaName)
        return button
    }

    private func updateSessionButton() {
        let active = personas.first(where: { $0.name == activePersonaName }) ?? .fresh(name: activePersonaName)
        sessionButton.setTitle(active.displayInitials, for: .normal)
        sessionButton.backgroundColor = personaColor(for: active.name)
        sessionButton.accessibilityLabel = "ATLAS persona \(active.name)"
    }

    private func personaColor(for name: String) -> UIColor {
        let hue = name.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 360 }
        return UIColor(hue: CGFloat(hue) / 360, saturation: 0.58, brightness: 0.74, alpha: 1)
    }

    private func togglePersonaPicker() {
        if isPersonaPickerOpen {
            hidePersonaPicker()
        } else {
            showPersonaPicker()
        }
    }

    private func showPersonaPicker() {
        isPersonaPickerOpen = true
        rebuildPersonaCircles()
        personaPicker.isHidden = false
        personaPicker.transform = CGAffineTransform(translationX: -8, y: 0).scaledBy(x: 0.98, y: 0.98)
        suggestionButtons.forEach { button in
            button.isHidden = true
            button.alpha = 0
        }
        updateSuggestionSeparators()

        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.personaPicker.alpha = 1
            self.personaPicker.transform = .identity
            self.sessionButton.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
            self.layoutIfNeeded()
        }
    }

    private func hidePersonaPicker() {
        guard isPersonaPickerOpen else { return }
        isPersonaPickerOpen = false

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            self.personaPicker.alpha = 0
            self.personaPicker.transform = CGAffineTransform(translationX: -8, y: 0).scaledBy(x: 0.98, y: 0.98)
            self.sessionButton.transform = .identity
            self.layoutIfNeeded()
        } completion: { _ in
            self.personaPicker.isHidden = true
            self.personaPicker.transform = .identity
            self.suggestionButtons.forEach { button in
                button.isHidden = false
                button.alpha = button.isEnabled ? 1 : 0.4
            }
            self.updateSuggestionSeparators()
        }
    }

    private func rebuildPersonaCircles() {
        guard let stack = personaScrollStack else { return }
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, persona) in personas.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(persona.displayInitials, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = personaColor(for: persona.name)
            button.layer.cornerRadius = 19
            button.layer.borderWidth = persona.name == activePersonaName ? 2.5 : 0
            button.layer.borderColor = UIColor.white.cgColor
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = persona.name == activePersonaName ? 0.16 : 0
            button.layer.shadowRadius = 5
            button.layer.shadowOffset = CGSize(width: 0, height: 2)
            button.clipsToBounds = true
            button.accessibilityLabel = persona.name
            button.addTarget(self, action: #selector(personaCircleTapped(_:)), for: .touchUpInside)
            button.widthAnchor.constraint(equalToConstant: 38).isActive = true
            button.heightAnchor.constraint(equalToConstant: 38).isActive = true
            stack.addArrangedSubview(button)
        }
    }

    private func avatarImage(for persona: AtlasSession) -> UIImage? {
        let size = CGSize(width: 34, height: 34)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            personaColor(for: persona.name).setFill()
            context.cgContext.fillEllipse(in: rect)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let text = persona.displayInitials as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2),
                withAttributes: attributes
            )
        }
    }

    private func makeKey(_ key: KeyboardKey, title: String, width: CGFloat?) -> KeyboardButton {
        let button = KeyboardButton(key: key)
        button.setTitle(displayTitle(for: key, fallback: title), for: .normal)
        if let imageName = imageName(for: key) {
            button.setImage(UIImage(systemName: imageName), for: .normal)
            button.tintColor = .label
        }
        button.titleLabel?.font = .systemFont(ofSize: key == .space || key == .modeToggle || key == .symbolToggle ? 15 : 22, weight: .regular)
        button.layer.cornerRadius = 5
        button.layer.cornerCurve = .continuous
        button.backgroundColor = keyBackground(for: key)
        button.setTitleColor(.label, for: .normal)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        if case .character = key {
            button.addTarget(self, action: #selector(characterKeyTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        }
        if let width {
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        keyButtons.append(button)
        return button
    }

    private func makeEmojiKey(_ emoji: String) -> KeyboardButton {
        let button = KeyboardButton(key: .character(emoji))
        button.setTitle(emoji, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 31)
        button.contentHorizontalAlignment = .leading
        button.backgroundColor = .clear
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        keyButtons.append(button)
        return button
    }

    private func makeEngramButton(for persona: AtlasSession, index: Int, size: CGFloat) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.backgroundColor = personaColor(for: persona.name)
        button.layer.cornerRadius = size / 2
        button.layer.borderWidth = persona.name == activePersonaName ? 3 : 0
        button.layer.borderColor = UIColor.label.cgColor
        button.setTitle(persona.displayInitials, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: max(13, size * 0.32), weight: .bold)
        button.addTarget(self, action: #selector(engramButtonTapped(_:)), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.accessibilityLabel = persona.name
        return button
    }

    private func makeEngramPlaceholder(size: CGFloat) -> UIView {
        let view = UIView()
        view.alpha = 0
        view.widthAnchor.constraint(equalToConstant: size).isActive = true
        view.heightAnchor.constraint(equalToConstant: size).isActive = true
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }

    private func makeEmojiCategoryButton(systemName: String, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = selected ? .label : .secondaryLabel
        button.backgroundColor = selected ? UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.32, green: 0.33, blue: 0.36, alpha: 1) : UIColor(red: 207 / 255, green: 211 / 255, blue: 219 / 255, alpha: 1)
        } : .clear
        button.layer.cornerRadius = 22
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    private func imageName(for key: KeyboardKey) -> String? {
        switch key {
        case .shift:
            return "shift"
        case .backspace:
            return "delete.left"
        case .globe:
            return "globe"
        case .returnKey:
            return returnKeyIconName(for: returnKeyType)
        default:
            return nil
        }
    }

    private func returnKeyIconName(for type: UIReturnKeyType) -> String {
        switch type {
        case .search, .google, .yahoo:  return "magnifyingglass"
        case .send:                     return "paperplane"
        case .done:                     return "checkmark"
        case .next:                     return "arrow.forward.to.line"
        case .go, .continue:            return "arrow.right.circle"
        default:                        return "return"
        }
    }

    private func displayTitle(for key: KeyboardKey, fallback: String) -> String {
        switch key {
        case .shift, .backspace, .globe, .returnKey:
            return ""
        case .modeToggle:
            return keyboardMode == .letters ? "123" : "ABC"
        case .symbolToggle:
            return keyboardMode == .symbols ? "123" : "#+="
        case .space:
            return "space"
        case .character:
            return fallback
        }
    }

    private func keyBackground(for key: KeyboardKey) -> UIColor {
        return UIColor { trait in
            switch key {
            case .character, .space:
                return trait.userInterfaceStyle == .dark ? UIColor(red: 0.23, green: 0.24, blue: 0.26, alpha: 1) : .white
            default:
                return trait.userInterfaceStyle == .dark ? UIColor(red: 0.32, green: 0.33, blue: 0.35, alpha: 1) : UIColor(red: 174 / 255, green: 179 / 255, blue: 189 / 255, alpha: 1)
            }
        }
    }

    @objc private func keyTapped(_ sender: KeyboardButton) {
        if sender.key == .modeToggle {
            triggerKeyFeedback()
            keyboardMode = keyboardMode == .letters ? .numbers : .letters
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
            return
        }
        if sender.key == .symbolToggle {
            triggerKeyFeedback()
            keyboardMode = keyboardMode == .symbols ? .numbers : .symbols
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
            return
        }
        delegate?.keyboardSurfaceView(self, didTap: sender.key)
        triggerKeyFeedback()
    }

    private func triggerKeyFeedback() {
        guard hapticsEnabled else { return }
        keyFeedback.impactOccurred(intensity: 0.7)
        keyFeedback.prepare()
    }

    private func prepareKeyFeedback() {
        guard hapticsEnabled else { return }
        keyFeedback.prepare()
    }

    @objc private func characterKeyTouchDown(_ sender: KeyboardButton) {
        guard case .character = sender.key,
              let title = sender.title(for: .normal),
              !title.isEmpty
        else { return }

        prepareKeyFeedback()
        showKeyPreview(title, from: sender)
    }

    @objc private func characterKeyTouchEnded(_ sender: KeyboardButton) {
        hideKeyPreview()
    }

    private func showKeyPreview(_ title: String, from key: KeyboardButton) {
        keyPreviewView?.removeFromSuperview()

        let keyFrame = key.convert(key.bounds, to: self)
        let previewWidth = max(keyFrame.width * 1.35, 54)
        let previewHeight: CGFloat = 70
        let previewX = min(max(keyFrame.midX - previewWidth / 2, 4), bounds.width - previewWidth - 4)
        let previewY = max(keyFrame.minY - previewHeight + 10, 0)

        let container = UIView(frame: CGRect(x: previewX, y: previewY, width: previewWidth, height: previewHeight))
        container.backgroundColor = .clear
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.18
        container.layer.shadowRadius = 5
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.transform = CGAffineTransform(scaleX: 0.82, y: 0.82).translatedBy(x: 0, y: 8)
        container.alpha = 0

        let label = UILabel(frame: container.bounds)
        label.text = title
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 34, weight: .medium)
        label.textColor = .label
        label.backgroundColor = keyBackground(for: key.key)
        label.layer.cornerRadius = 10
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        container.addSubview(label)

        addSubview(container)
        bringSubviewToFront(container)
        keyPreviewView = container

        UIView.animate(withDuration: 0.035, delay: 0, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
            container.alpha = 1
            container.transform = .identity
        }
    }

    private func hideKeyPreview() {
        guard let preview = keyPreviewView else { return }
        keyPreviewView = nil

        UIView.animate(withDuration: 0.045, delay: 0, options: [.curveEaseIn, .allowUserInteraction, .beginFromCurrentState]) {
            preview.alpha = 0
            preview.transform = CGAffineTransform(scaleX: 0.9, y: 0.9).translatedBy(x: 0, y: 4)
        } completion: { _ in
            preview.removeFromSuperview()
        }
    }

    @objc private func engramCategoryTapped() {
        emojiPanelMode = .engrams
        rebuildKeyboardRows()
    }

    @objc private func emojiCategoryTapped() {
        emojiPanelMode = .emojis
        rebuildKeyboardRows()
    }

    @objc private func engramButtonTapped(_ sender: UIButton) {
        hidePersonaPicker()
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let text = sender.title(for: .normal), !text.isEmpty else { return }
        let kind = AtlasSuggestionKind(rawValue: sender.accessibilityIdentifier ?? "") ?? .nextWord
        delegate?.keyboardSurfaceView(self, didAccept: AtlasSuggestion(text: text, kind: kind, score: 0))
    }

    @objc private func sessionTapped() {
        togglePersonaPicker()
    }

    @objc private func personaCircleTapped(_ sender: UIButton) {
        hidePersonaPicker()
    }

    @objc private func sessionLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        delegate?.keyboardSurfaceViewDidLongPressSession(self)
    }

    // MARK: - Toolbar toggle / menu actions
    @objc private func toolbarToggleTapped() {
        setMenuToggled(!isMenuToggled, animated: true)
    }

    @objc private func dismissKeyboardTapped() {
        delegate?.keyboardSurfaceViewDidRequestDismissKeyboard(self)
    }

    @objc private func menuDismissTapped() {
        setMenuToggled(false, animated: true)
        delegate?.keyboardSurfaceViewDidRequestDismissKeyboard(self)
    }

    @objc private func menuCloseTapped() {
        setMenuToggled(false, animated: true)
    }

    @objc private func menuHapticsTapped() {
        let next = !hapticsEnabled
        hapticsEnabled = next
        delegate?.keyboardSurfaceView(self, didSetHapticsEnabled: next)
        if let button = hapticsToggleButton {
            var config = button.configuration
            var attrs = AttributeContainer()
            attrs.font = .systemFont(ofSize: 13, weight: .semibold)
            config?.attributedTitle = AttributedString(hapticsTitle(), attributes: attrs)
            button.configuration = config
        }
    }

    private func setMenuToggled(_ toggled: Bool, animated: Bool) {
        guard toggled != isMenuToggled else { return }
        isMenuToggled = toggled

        let suggestionsAlpha: CGFloat = toggled ? 0 : 1
        let collapsedAlpha: CGFloat = toggled ? 1 : 0
        let overlayAlpha: CGFloat = toggled ? 1 : 0
        let keysAlpha: CGFloat = toggled ? 0 : 1

        menuOverlay.isUserInteractionEnabled = toggled
        // Disable keys behind the overlay so taps don't leak through.
        keyStack.isUserInteractionEnabled = !toggled
        suggestionStack.isUserInteractionEnabled = !toggled

        let block = {
            self.suggestionStack.alpha = suggestionsAlpha
            self.collapsedToolbar.alpha = collapsedAlpha
            self.menuOverlay.alpha = overlayAlpha
            self.keyStack.alpha = keysAlpha
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: block)
        } else {
            block()
        }
    }

    @objc private func backspaceLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            backspaceTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.delegate?.keyboardSurfaceViewDidLongPressBackspace(self)
            }
        case .ended, .cancelled, .failed:
            backspaceTimer?.invalidate()
            backspaceTimer = nil
        default:
            break
        }
    }
}

final class KeyboardButton: UIButton {
    let key: KeyboardKey

    init(key: KeyboardKey) {
        self.key = key
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.72 : 1
        }
    }
}

final class SpacerView: UIView {
    init(width: CGFloat) {
        super.init(frame: .zero)
        widthAnchor.constraint(equalToConstant: width).isActive = true
        setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FlexibleSpacerView: UIView {
    init() {
        super.init(frame: .zero)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
