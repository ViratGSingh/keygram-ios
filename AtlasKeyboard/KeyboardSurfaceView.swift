import UIKit

protocol KeyboardSurfaceViewDelegate: AnyObject {
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didTap key: KeyboardKey, at point: CGPoint, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval)
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, didAccept suggestion: AtlasSuggestion, touchStartedAt: CFTimeInterval, touchEndedAt: CFTimeInterval)
    func keyboardSurfaceView(_ view: KeyboardSurfaceView, preferredHeightDidChange height: CGFloat)
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

    var defaultTitle: String {
        switch self {
        case .character(let character):
            return character
        case .shift:
            return "shift"
        case .backspace:
            return "delete.left"
        case .space:
            return "space"
        case .returnKey:
            return "return"
        case .globe:
            return "globe"
        case .modeToggle:
            return "123"
        case .symbolToggle:
            return "#+="
        }
    }
}

final class KeyboardSurfaceView: UIView {
    private enum LayoutMetric {
        // Suggestion bar is slimmer than a key row, matching the iOS system keyboard.
        static let toolbarHeight: CGFloat = 38
        static let rowHeight: CGFloat = 52
        // 1 toolbar + 4 key rows + a little vertical slack.
        static let keyboardContentHeight: CGFloat = toolbarHeight + rowHeight * 4 + 8
        static let emojiContentHeight: CGFloat = 330
        static let emojiSearchContentHeight: CGFloat = 470
        static let buttonHorizontalInset: CGFloat = 3
        static let buttonVerticalInset: CGFloat = 4
    }

    static var keyboardBackgroundColor: UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.08, green: 0.09, blue: 0.1, alpha: 1) : UIColor(red: 227 / 255, green: 229 / 255, blue: 233 / 255, alpha: 1)
        }
    }

    static var preferredKeyboardHeight: CGFloat {
        LayoutMetric.keyboardContentHeight
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
    private var touchStartTimes: [ObjectIdentifier: CFTimeInterval] = [:]
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
    private var selectedEmojiCategoryIndex = 0
    private var isEmojiSearchActive = false
    private var emojiSearchQuery = ""
    private var recentEmojis: [String] = []
    private var visibleEmojiItems: [EmojiCatalogItem] = []
    private var lastReportedPreferredHeight = LayoutMetric.keyboardContentHeight
    private let keyFeedback = UIImpactFeedbackGenerator(style: .light)
    private var hapticsEnabled = true

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

    private struct EmojiDisplayCategory {
        var name: String
        var symbolName: String
        var items: [EmojiCatalogItem]
    }

    private struct KeyLayout {
        var itemRows: [[Item]]

        struct Item {
            var key: KeyboardKey?
            var title: String
            var width: Width

            static func key(_ key: KeyboardKey, title: String? = nil, width: Width) -> Item {
                Item(key: key, title: title ?? key.defaultTitle, width: width)
            }

            static func spacer(width: Width = .available) -> Item {
                Item(key: nil, title: "", width: width)
            }
        }

        enum Width {
            case input
            case inputPercentage(CGFloat)
            case percentage(CGFloat)
            case points(CGFloat)
            case available
        }
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
        let contentHeight = min(preferredHeightForCurrentMode, bounds.height)
        let contentWidth = keyboardContentWidth
        let contentFrame = CGRect(
            x: 0,
            y: max(0, bounds.height - contentHeight),
            width: contentWidth,
            height: contentHeight
        )
        backgroundPanel.frame = contentFrame
        rootStack.frame = contentFrame
        updateRowHeights(for: contentHeight)
        rootStack.setNeedsLayout()
        rootStack.layoutIfNeeded()
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

    private var keyboardContentWidth: CGFloat {
        bounds.width
    }

    private var preferredHeightForCurrentMode: CGFloat {
        guard keyboardMode == .emoji else { return LayoutMetric.keyboardContentHeight }
        return isEmojiSearchActive ? LayoutMetric.emojiSearchContentHeight : LayoutMetric.emojiContentHeight
    }

    private func notifyPreferredHeightIfNeeded() {
        let nextHeight = preferredHeightForCurrentMode
        guard abs(nextHeight - lastReportedPreferredHeight) > 0.5 else { return }
        lastReportedPreferredHeight = nextHeight
        delegate?.keyboardSurfaceView(self, preferredHeightDidChange: nextHeight)
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
        hapticsEnabled = Self.persistedHapticsEnabled()
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
            button.addTarget(self, action: #selector(controlTouchDown(_:)), for: .touchDown)
            button.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            button.addTarget(self, action: #selector(controlTouchCancelled(_:)), for: [.touchUpOutside, .touchCancel, .touchDragExit])
            suggestionButtons.append(button)
            chipsContainer.addArrangedSubview(button)
        }
        suggestionStack.addArrangedSubview(chipsContainer)

        // toolbarToggleButton = makeToolbarChevron(expanded: false)
        // toolbarToggleButton.addTarget(self, action: #selector(toolbarToggleTapped), for: .touchUpInside)
        // suggestionStack.addArrangedSubview(toolbarToggleButton)

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

        // let chevronClose = makeToolbarChevron(expanded: true)
        // chevronClose.addTarget(self, action: #selector(toolbarToggleTapped), for: .touchUpInside)
        // collapsedToolbar.addArrangedSubview(chevronClose)
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
        keyStack.spacing = keyboardMode == .emoji ? 6 : 0
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
        notifyPreferredHeightIfNeeded()
        setNeedsLayout()
    }

    private func buildLetterRows() {
        renderKeyLayout(letterLayout)
    }

    private func buildEmojiRows() {
        if isEmojiSearchActive {
            addEmojiSearchTitle()
            addEmojiSearchResults()
            addEmojiSearchInputRow()
            renderKeyLayout(emojiSearchKeyboardLayout)
            return
        }

        addEmojiSearchRow()

        switch emojiPanelMode {
        case .emojis:
            addEmojiGrid(items: selectedEmojiItems())
            addEmojiCategoryStrip()
        case .engrams:
            addEmojiSectionLabel("Engrams")
            addEngramGrid()
        }

        addEmojiModeToolbar()
    }

    private func addEmojiGrid(items: [EmojiCatalogItem]) {
        visibleEmojiItems = items

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 44, height: 32)
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 2, left: 18, bottom: 2, right: 18)

        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.alwaysBounceHorizontal = true
        collection.dataSource = self
        collection.delegate = self
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseIdentifier)
        let height = collection.heightAnchor.constraint(equalToConstant: 138)
        height.priority = .defaultHigh
        height.isActive = true

        keyStack.addArrangedSubview(collection)
    }

    private func selectedEmojiItems() -> [EmojiCatalogItem] {
        let categories = emojiDisplayCategories()
        guard categories.indices.contains(selectedEmojiCategoryIndex) else {
            selectedEmojiCategoryIndex = min(max(0, selectedEmojiCategoryIndex), max(0, categories.count - 1))
            return categories.first?.items ?? []
        }
        return categories[selectedEmojiCategoryIndex].items
    }

    private func emojiDisplayCategories() -> [EmojiDisplayCategory] {
        var categories: [EmojiDisplayCategory] = []
        let recentItems = recentEmojiItems()
        if !recentItems.isEmpty {
            categories.append(EmojiDisplayCategory(name: "Recent", symbolName: "clock.fill", items: recentItems))
        }
        categories += EmojiCatalog.categories.map {
            EmojiDisplayCategory(name: $0.name, symbolName: $0.symbolName, items: $0.items)
        }
        return categories
    }

    private func recentEmojiItems() -> [EmojiCatalogItem] {
        let fallback = ["😀", "😁", "😅", "🙂", "😇", "😉", "🥰", "😘", "😛", "😂", "😊", "😍", "👍", "🎉", "🔥", "✨", "❤️", "🙏"]
        let values = recentEmojis.isEmpty ? fallback : recentEmojis
        return values.map { EmojiCatalogItem(value: $0, name: "recent emoji", subgroup: "recent") }
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
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let search = UIButton(type: .system)
        search.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.25, green: 0.25, blue: 0.26, alpha: 1) : UIColor(red: 239 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1)
        }
        search.layer.cornerRadius = 22
        search.clipsToBounds = true
        search.translatesAutoresizingMaskIntoConstraints = false
        search.heightAnchor.constraint(equalToConstant: 48).isActive = true
        search.addTarget(self, action: #selector(emojiSearchTapped), for: .touchUpInside)
        container.addSubview(search)

        let brand = UILabel()
        brand.text = "K"
        brand.font = .systemFont(ofSize: 20, weight: .bold)
        brand.textColor = .white
        brand.textAlignment = .center
        brand.backgroundColor = .systemBlue
        brand.layer.cornerRadius = 15
        brand.clipsToBounds = true
        brand.translatesAutoresizingMaskIntoConstraints = false
        search.addSubview(brand)

        let label = UILabel()
        label.text = "Search emojis"
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        search.addSubview(label)

        NSLayoutConstraint.activate([
            brand.leadingAnchor.constraint(equalTo: search.leadingAnchor, constant: 18),
            brand.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            brand.widthAnchor.constraint(equalToConstant: 30),
            brand.heightAnchor.constraint(equalToConstant: 30),
            label.leadingAnchor.constraint(equalTo: brand.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: search.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: search.trailingAnchor, constant: -16)
        ])

        NSLayoutConstraint.activate([
            search.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            search.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            search.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            search.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        keyStack.addArrangedSubview(container)
    }

    private func addEmojiSearchTitle() {
        let label = UILabel()
        label.text = "Keygram"
        label.textAlignment = .center
        label.textColor = .label
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.heightAnchor.constraint(equalToConstant: 42).isActive = true
        keyStack.addArrangedSubview(label)
    }

    private func addEmojiSearchResults() {
        addEmojiGrid(items: filteredEmojiSearchItems())
    }

    private func addEmojiSearchInputRow() {
        let container = UIView()
        container.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.25, green: 0.25, blue: 0.26, alpha: 1) : UIColor(red: 239 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1)
        }
        container.layer.cornerRadius = 16
        container.clipsToBounds = true
        container.heightAnchor.constraint(equalToConstant: 46).isActive = true

        let back = UIButton(type: .system)
        back.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        back.tintColor = .label
        back.translatesAutoresizingMaskIntoConstraints = false
        back.addTarget(self, action: #selector(emojiSearchBackTapped), for: .touchUpInside)
        container.addSubview(back)

        let label = UILabel()
        label.text = emojiSearchQuery.isEmpty ? "Search emojis" : emojiSearchQuery
        label.textColor = emojiSearchQuery.isEmpty ? .secondaryLabel : .label
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let clear = UIButton(type: .system)
        clear.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clear.tintColor = .label
        clear.alpha = emojiSearchQuery.isEmpty ? 0.35 : 1
        clear.translatesAutoresizingMaskIntoConstraints = false
        clear.addTarget(self, action: #selector(emojiSearchClearTapped), for: .touchUpInside)
        container.addSubview(clear)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            back.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            back.widthAnchor.constraint(equalToConstant: 38),
            back.heightAnchor.constraint(equalToConstant: 38),
            label.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            clear.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            clear.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            clear.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            clear.widthAnchor.constraint(equalToConstant: 34),
            clear.heightAnchor.constraint(equalToConstant: 34)
        ])

        keyStack.addArrangedSubview(container)
    }

    private func filteredEmojiSearchItems() -> [EmojiCatalogItem] {
        let query = emojiSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return EmojiCatalog.searchItems.prefix(36).map { $0.item }
        }

        let terms = query.split(separator: " ").map(String.init)
        return EmojiCatalog.searchItems.compactMap { entry in
            let haystack = "\(entry.item.name) \(entry.item.subgroup) \(entry.categoryName)".lowercased()
            return terms.allSatisfy { haystack.contains($0) } ? entry.item : nil
        }
        .prefix(54)
        .map { $0 }
    }

    private func addEmojiSectionLabel(_ title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = .secondaryLabel
        label.heightAnchor.constraint(equalToConstant: 24).isActive = true
        keyStack.addArrangedSubview(label)
    }

    private func addEmojiCategoryStrip() {
        let categories = emojiDisplayCategories()
        if selectedEmojiCategoryIndex >= categories.count {
            selectedEmojiCategoryIndex = max(0, categories.count - 1)
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.heightAnchor.constraint(equalToConstant: 46).isActive = true

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -18),
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        for (index, category) in categories.enumerated() {
            let selected = index == selectedEmojiCategoryIndex
            let button = makeEmojiCategoryButton(systemName: category.symbolName, selected: selected)
            button.tag = index
            button.addTarget(self, action: #selector(emojiCategoryIndexTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
        }

        keyStack.addArrangedSubview(scroll)
    }

    private func addEmojiModeToolbar() {
        let toolbar = UIStackView()
        toolbar.axis = .horizontal
        toolbar.alignment = .center
        toolbar.spacing = 10
        toolbar.distribution = .fill
        toolbar.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let abc = makeKey(.modeToggle, title: "ABC", width: 72)
        abc.backgroundColor = .clear
        abc.titleLabel?.font = .systemFont(ofSize: 24, weight: .regular)
        toolbar.addArrangedSubview(abc)

        toolbar.addArrangedSubview(FlexibleSpacerView())

        let emojiButton = makeEmojiModeButton(systemName: "face.smiling", title: nil, selected: emojiPanelMode == .emojis)
        emojiButton.addTarget(self, action: #selector(emojiCategoryTapped), for: .touchUpInside)
        toolbar.addArrangedSubview(emojiButton)

        let stickerButton = makeEmojiModeButton(systemName: "face.smiling.inverse", title: nil, selected: false)
        stickerButton.isEnabled = false
        toolbar.addArrangedSubview(stickerButton)

        let gifButton = makeEmojiModeButton(systemName: nil, title: "GIF", selected: false)
        gifButton.isEnabled = false
        toolbar.addArrangedSubview(gifButton)

        let emoticonButton = makeEmojiModeButton(systemName: nil, title: ":-)", selected: false)
        emoticonButton.isEnabled = false
        toolbar.addArrangedSubview(emoticonButton)

        toolbar.addArrangedSubview(FlexibleSpacerView())

        let backspace = makeKey(.backspace, title: "delete.left", width: 48)
        backspace.backgroundColor = .clear
        backspace.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:))))
        toolbar.addArrangedSubview(backspace)

        keyStack.addArrangedSubview(toolbar)
    }

    private func buildSymbolRows() {
        renderKeyLayout(symbolLayout)
    }

    private func buildNumberRows() {
        renderKeyLayout(numberLayout)
    }

    private var letterLayout: KeyLayout {
        KeyLayout(itemRows: [
            inputRow("qwertyuiop"),
            [.spacer(width: .inputPercentage(0.5))] + inputItems("asdfghjkl") + [.spacer(width: .inputPercentage(0.5))],
            [
                .key(.shift, width: .inputPercentage(1.3)),
                .spacer(),
            ] + inputItems("zxcvbnm") + [
                .spacer(),
                .key(.backspace, width: .inputPercentage(1.3)),
            ],
            [
                .key(.modeToggle, title: "123", width: .inputPercentage(1.23)),
                .key(.globe, width: .inputPercentage(1.23)),
                .key(.space, width: .available),
                .key(.returnKey, width: .percentage(0.25)),
            ],
        ])
    }

    private var numberLayout: KeyLayout {
        KeyLayout(itemRows: [
            inputRow("1234567890"),
            inputRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\u{201D}"]),
            [
                .key(.symbolToggle, title: "#+=", width: .inputPercentage(1.3)),
                .spacer(),
            ] + inputItems([".", ",", "?", "!", "\u{2019}"]) + [
                .spacer(),
                .key(.backspace, width: .inputPercentage(1.3)),
            ],
            [
                .key(.modeToggle, title: "ABC", width: .inputPercentage(1.23)),
                .key(.globe, width: .inputPercentage(1.23)),
                .key(.space, width: .available),
                .key(.returnKey, width: .percentage(0.25)),
            ],
        ])
    }

    private var symbolLayout: KeyLayout {
        KeyLayout(itemRows: [
            inputRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]),
            inputRow(["_", "\\", "|", "~", "<", ">", "\u{20AC}", "\u{00A3}", "\u{00A5}", "\u{2022}"]),
            [
                .key(.symbolToggle, title: "123", width: .inputPercentage(1.3)),
                .spacer(),
            ] + inputItems([".", ",", "?", "!", "\u{2019}"]) + [
                .spacer(),
                .key(.backspace, width: .inputPercentage(1.3)),
            ],
            [
                .key(.modeToggle, title: "ABC", width: .inputPercentage(1.23)),
                .key(.globe, width: .inputPercentage(1.23)),
                .key(.space, width: .available),
                .key(.returnKey, width: .percentage(0.25)),
            ],
        ])
    }

    private var emojiSearchKeyboardLayout: KeyLayout {
        KeyLayout(itemRows: [
            inputRow("qwertyuiop"),
            [.spacer(width: .inputPercentage(0.5))] + inputItems("asdfghjkl") + [.spacer(width: .inputPercentage(0.5))],
            [
                .key(.shift, width: .inputPercentage(1.3)),
                .spacer(),
            ] + inputItems("zxcvbnm") + [
                .spacer(),
                .key(.backspace, width: .inputPercentage(1.3)),
            ],
            [
                .key(.modeToggle, title: "123", width: .inputPercentage(1.23)),
                .key(.globe, width: .inputPercentage(1.23)),
                .key(.space, width: .available),
                .key(.character("."), title: ".", width: .inputPercentage(1.0)),
                .key(.returnKey, title: "Search", width: .percentage(0.28)),
            ],
        ])
    }

    private func inputRow(_ characters: String) -> [KeyLayout.Item] {
        inputItems(characters.map(String.init))
    }

    private func inputRow(_ characters: [String]) -> [KeyLayout.Item] {
        inputItems(characters)
    }

    private func inputItems(_ characters: String) -> [KeyLayout.Item] {
        inputItems(characters.map(String.init))
    }

    private func inputItems(_ characters: [String]) -> [KeyLayout.Item] {
        characters.map { .key(.character($0), title: $0, width: .input) }
    }

    private func renderKeyLayout(_ layout: KeyLayout) {
        for itemRow in layout.itemRows {
            let row = keyboardRow()
            let widthMultipliers = resolvedWidthMultipliers(for: itemRow)
            for (item, widthMultiplier) in zip(itemRow, widthMultipliers) {
                addLayoutItem(item, to: row, widthMultiplier: widthMultiplier)
            }
            keyStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: keyStack.widthAnchor).isActive = true
        }
    }

    private func resolvedWidthMultipliers(for itemRow: [KeyLayout.Item]) -> [CGFloat?] {
        let hasAvailableWidth = itemRow.contains {
            if case .available = $0.width { return true }
            return false
        }

        if hasAvailableWidth {
            let fixedWidth = itemRow.reduce(CGFloat(0)) { result, item in
                result + (fixedWidthMultiplier(for: item.width) ?? 0)
            }
            let availableCount = itemRow.filter {
                if case .available = $0.width { return true }
                return false
            }.count
            let availableWidth = availableCount > 0 ? max(0, 1 - fixedWidth) / CGFloat(availableCount) : 0

            return itemRow.map { item in
                if case .available = item.width { return availableWidth }
                return fixedWidthMultiplier(for: item.width)
            }
        }

        let weights = itemRow.map { proportionalWeight(for: $0.width) }
        let totalWeight = weights.reduce(CGFloat(0), +)
        guard totalWeight > 0 else { return itemRow.map { _ in nil } }
        return weights.map { $0 / totalWeight }
    }

    private func fixedWidthMultiplier(for width: KeyLayout.Width) -> CGFloat? {
        switch width {
        case .input:
            return inputKeyWidthMultiplier
        case .inputPercentage(let multiplier):
            return inputKeyWidthMultiplier * multiplier
        case .percentage(let multiplier):
            return multiplier
        case .available, .points:
            return nil
        }
    }

    private func proportionalWeight(for width: KeyLayout.Width) -> CGFloat {
        switch width {
        case .input:
            return 1
        case .inputPercentage(let multiplier):
            return multiplier
        case .percentage(let multiplier):
            return multiplier
        case .available:
            return 1
        case .points:
            return 0
        }
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

    @discardableResult
    private func addLayoutItem(_ item: KeyLayout.Item, to row: UIStackView, widthMultiplier: CGFloat?) -> KeyboardButton? {
        let view: UIView
        let button: KeyboardButton?

        if let key = item.key {
            let keyButton = makeKey(key, title: item.title, width: nil)
            if key == .backspace {
                keyButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(backspaceLongPressed(_:))))
            }
            view = keyContainer(for: keyButton)
            button = keyButton
        } else {
            view = FlexibleSpacerView()
            button = nil
        }

        row.addArrangedSubview(view)
        apply(item.width, to: view, in: row, widthMultiplier: widthMultiplier)
        return button
    }

    private func keyContainer(for button: KeyboardButton) -> UIView {
        let container = UIView()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.hitTestOutsets = UIEdgeInsets(
            top: LayoutMetric.buttonVerticalInset,
            left: LayoutMetric.buttonHorizontalInset,
            bottom: LayoutMetric.buttonVerticalInset,
            right: LayoutMetric.buttonHorizontalInset
        )
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: LayoutMetric.buttonHorizontalInset),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -LayoutMetric.buttonHorizontalInset),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: LayoutMetric.buttonVerticalInset),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -LayoutMetric.buttonVerticalInset)
        ])
        return container
    }

    private func apply(_ width: KeyLayout.Width, to view: UIView, in row: UIStackView, widthMultiplier: CGFloat?) {
        if let widthMultiplier {
            view.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: widthMultiplier).isActive = true
            lockHorizontalSize(of: view)
            return
        }

        switch width {
        case .points(let points):
            view.widthAnchor.constraint(equalToConstant: points).isActive = true
            lockHorizontalSize(of: view)
        case .available, .input, .inputPercentage, .percentage:
            view.setContentHuggingPriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
    }

    private var inputKeyWidthMultiplier: CGFloat {
        0.1
    }

    private func lockHorizontalSize(of view: UIView) {
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
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
        let fontSize: CGFloat
        if isEmojiSearchActive && key == .returnKey {
            fontSize = 18
        } else {
            fontSize = key == .space || key == .modeToggle || key == .symbolToggle ? 15 : 22
        }
        button.titleLabel?.font = .systemFont(ofSize: fontSize, weight: isEmojiSearchActive && key == .returnKey ? .semibold : .regular)
        button.layer.cornerRadius = 5
        button.layer.cornerCurve = .continuous
        button.backgroundColor = keyBackground(for: key)
        button.setTitleColor(isEmojiSearchActive && key == .returnKey ? .white : .label, for: .normal)
        button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(keyTouchCancelled(_:)), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        if case .character = key {
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
        button.accessibilityIdentifier = "emoji-key"
        button.setTitle(emoji, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 34)
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.backgroundColor = .clear
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(keyTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(keyTouchCancelled(_:)), for: [.touchUpOutside, .touchCancel, .touchDragExit])
        button.addTarget(self, action: #selector(characterKeyTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
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
        button.tintColor = .label
        button.backgroundColor = selected ? UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(red: 0.32, green: 0.33, blue: 0.35, alpha: 1) : UIColor(red: 207 / 255, green: 211 / 255, blue: 219 / 255, alpha: 1)
        } : .clear
        button.alpha = selected ? 1 : 0.95
        button.layer.cornerRadius = 20
        button.widthAnchor.constraint(equalToConstant: 40).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.imageView?.contentMode = .scaleAspectFit
        return button
    }

    private func makeEmojiModeButton(systemName: String?, title: String?, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        if let systemName {
            button.setImage(UIImage(systemName: systemName), for: .normal)
        }
        if let title {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        }
        button.tintColor = selected ? .systemBlue : .label
        button.setTitleColor(selected ? .systemBlue : .label, for: .normal)
        button.alpha = button.isEnabled ? 1 : 0.95
        button.widthAnchor.constraint(equalToConstant: 48).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }

    private func imageName(for key: KeyboardKey) -> String? {
        switch key {
        case .shift:
            return "shift"
        case .backspace:
            return "delete.left"
        case .globe:
            return "face.smiling"
        case .returnKey:
            if isEmojiSearchActive { return nil }
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
            if isEmojiSearchActive && key == .returnKey {
                return "Search"
            }
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
            case .returnKey where self.isEmojiSearchActive:
                return UIColor.systemBlue
            default:
                return trait.userInterfaceStyle == .dark ? UIColor(red: 0.32, green: 0.33, blue: 0.35, alpha: 1) : UIColor(red: 174 / 255, green: 179 / 255, blue: 189 / 255, alpha: 1)
            }
        }
    }

    @objc private func controlTouchDown(_ sender: UIControl) {
        touchStartTimes[ObjectIdentifier(sender)] = CACurrentMediaTime()
    }

    @objc private func controlTouchCancelled(_ sender: UIControl) {
        touchStartTimes.removeValue(forKey: ObjectIdentifier(sender))
    }

    private func consumeTouchTiming(for control: UIControl) -> (startedAt: CFTimeInterval, endedAt: CFTimeInterval) {
        let endedAt = CACurrentMediaTime()
        let identifier = ObjectIdentifier(control)
        let startedAt = touchStartTimes[identifier] ?? endedAt
        touchStartTimes.removeValue(forKey: identifier)
        return (startedAt, endedAt)
    }

    @objc private func keyTouchDown(_ sender: KeyboardButton) {
        controlTouchDown(sender)
        triggerKeyFeedback()

        guard case .character = sender.key,
              let title = sender.title(for: .normal),
              !title.isEmpty
        else { return }

        prepareKeyFeedback()
        showKeyPreview(title, from: sender)
    }

    @objc private func keyTouchCancelled(_ sender: KeyboardButton) {
        controlTouchCancelled(sender)
    }

    @objc private func keyTapped(_ sender: KeyboardButton) {
        let touchTiming = consumeTouchTiming(for: sender)
        if isEmojiSearchActive {
            handleEmojiSearchKeyTap(sender, touchTiming: touchTiming)
            return
        }
        if sender.key == .globe {
            emojiPanelMode = .emojis
            isEmojiSearchActive = false
            keyboardMode = .emoji
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
            return
        }
        if sender.key == .modeToggle {
            if keyboardMode == .emoji {
                isEmojiSearchActive = false
            }
            keyboardMode = keyboardMode == .letters ? .numbers : .letters
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
            return
        }
        if sender.key == .symbolToggle {
            keyboardMode = keyboardMode == .symbols ? .numbers : .symbols
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
            return
        }
        let tapPoint = sender.latestTouchLocation(in: self)
            ?? sender.convert(CGPoint(x: sender.bounds.midX, y: sender.bounds.midY), to: self)

        #if DEBUG
        let keyCenter = sender.convert(CGPoint(x: sender.bounds.midX, y: sender.bounds.midY), to: self)
        NSLog(
            "[Keygram Touch] key=%@ point=(%.1f, %.1f) keyCenter=(%.1f, %.1f) delta=(%.1f, %.1f)",
            String(describing: sender.key),
            tapPoint.x,
            tapPoint.y,
            keyCenter.x,
            keyCenter.y,
            tapPoint.x - keyCenter.x,
            tapPoint.y - keyCenter.y
        )
        #endif

        if sender.accessibilityIdentifier == "emoji-key",
           case .character(let value) = sender.key {
            rememberEmoji(value)
        }
        delegate?.keyboardSurfaceView(self, didTap: sender.key, at: tapPoint, touchStartedAt: touchTiming.startedAt, touchEndedAt: touchTiming.endedAt)
    }

    private func handleEmojiSearchKeyTap(_ sender: KeyboardButton, touchTiming: (startedAt: CFTimeInterval, endedAt: CFTimeInterval)) {
        if sender.accessibilityIdentifier == "emoji-key" {
            submitEmojiKey(sender, touchTiming: touchTiming)
            return
        }

        switch sender.key {
        case .character(let value):
            emojiSearchQuery.append(value.lowercased())
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
        case .space:
            emojiSearchQuery.append(" ")
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
        case .backspace:
            guard !emojiSearchQuery.isEmpty else { return }
            emojiSearchQuery.removeLast()
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
        case .shift:
            isShifted.toggle()
            setShiftState(isShifted, capsLocked: isCapsLocked)
        case .returnKey:
            break
        case .globe:
            isEmojiSearchActive = false
            UIView.performWithoutAnimation { rebuildKeyboardRows() }
        case .modeToggle, .symbolToggle:
            break
        }
    }

    private func submitEmojiKey(_ sender: KeyboardButton, touchTiming: (startedAt: CFTimeInterval, endedAt: CFTimeInterval)) {
        let tapPoint = sender.latestTouchLocation(in: self)
            ?? sender.convert(CGPoint(x: sender.bounds.midX, y: sender.bounds.midY), to: self)
        if case .character(let value) = sender.key {
            rememberEmoji(value)
        }
        delegate?.keyboardSurfaceView(self, didTap: sender.key, at: tapPoint, touchStartedAt: touchTiming.startedAt, touchEndedAt: touchTiming.endedAt)
    }

    private func rememberEmoji(_ emoji: String) {
        recentEmojis.removeAll { $0 == emoji }
        recentEmojis.insert(emoji, at: 0)
        if recentEmojis.count > 36 {
            recentEmojis.removeLast(recentEmojis.count - 36)
        }
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
        container.isUserInteractionEnabled = false
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
        isEmojiSearchActive = false
        rebuildKeyboardRows()
    }

    @objc private func emojiCategoryTapped() {
        emojiPanelMode = .emojis
        isEmojiSearchActive = false
        selectedEmojiCategoryIndex = min(selectedEmojiCategoryIndex, max(0, emojiDisplayCategories().count - 1))
        rebuildKeyboardRows()
    }

    @objc private func emojiCategoryIndexTapped(_ sender: UIButton) {
        selectedEmojiCategoryIndex = sender.tag
        emojiPanelMode = .emojis
        isEmojiSearchActive = false
        rebuildKeyboardRows()
    }

    @objc private func emojiSearchTapped() {
        emojiPanelMode = .emojis
        isEmojiSearchActive = true
        emojiSearchQuery = ""
        UIView.performWithoutAnimation { rebuildKeyboardRows() }
    }

    @objc private func emojiSearchBackTapped() {
        isEmojiSearchActive = false
        emojiSearchQuery = ""
        UIView.performWithoutAnimation { rebuildKeyboardRows() }
    }

    @objc private func emojiSearchClearTapped() {
        guard !emojiSearchQuery.isEmpty else { return }
        emojiSearchQuery = ""
        UIView.performWithoutAnimation { rebuildKeyboardRows() }
    }

    @objc private func engramButtonTapped(_ sender: UIButton) {
        hidePersonaPicker()
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        let touchTiming = consumeTouchTiming(for: sender)
        guard let text = sender.title(for: .normal), !text.isEmpty else { return }
        let kind = AtlasSuggestionKind(rawValue: sender.accessibilityIdentifier ?? "") ?? .nextWord
        delegate?.keyboardSurfaceView(
            self,
            didAccept: AtlasSuggestion(text: text, kind: kind, score: 0),
            touchStartedAt: touchTiming.startedAt,
            touchEndedAt: touchTiming.endedAt
        )
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
        Self.setPersistedHapticsEnabled(next)
        delegate?.keyboardSurfaceView(self, didSetHapticsEnabled: next)
        if let button = hapticsToggleButton {
            var config = button.configuration
            var attrs = AttributeContainer()
            attrs.font = .systemFont(ofSize: 13, weight: .semibold)
            config?.attributedTitle = AttributedString(hapticsTitle(), attributes: attrs)
            button.configuration = config
        }
    }

    private static func persistedHapticsEnabled() -> Bool {
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
        guard defaults.object(forKey: AtlasConfiguration.hapticsEnabledKey) != nil else { return true }
        return defaults.bool(forKey: AtlasConfiguration.hapticsEnabledKey)
    }

    private static func setPersistedHapticsEnabled(_ enabled: Bool) {
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
        defaults.set(enabled, forKey: AtlasConfiguration.hapticsEnabledKey)
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

extension KeyboardSurfaceView {
    func touchModelLayoutSnapshot() -> [AtlasKeyboard.KeyLayout] {
        layoutIfNeeded()

        return keyButtons.compactMap { button in
            guard let keyID = touchModelKeyID(for: button.key) else { return nil }
            let frame = button.convert(button.bounds, to: self)
            guard frame.width > 0, frame.height > 0 else { return nil }

            return AtlasKeyboard.KeyLayout(
                id: keyID,
                centerX: Double(frame.midX),
                centerY: Double(frame.midY),
                width: Double(frame.width),
                height: Double(frame.height)
            )
        }
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
}

extension KeyboardSurfaceView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visibleEmojiItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseIdentifier, for: indexPath)
        guard let emojiCell = cell as? EmojiCell,
              visibleEmojiItems.indices.contains(indexPath.item)
        else { return cell }

        emojiCell.configure(with: visibleEmojiItems[indexPath.item].value)
        return emojiCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard visibleEmojiItems.indices.contains(indexPath.item),
              let cell = collectionView.cellForItem(at: indexPath)
        else { return }

        let emoji = visibleEmojiItems[indexPath.item].value
        rememberEmoji(emoji)
        triggerKeyFeedback()

        let point = cell.convert(CGPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: self)
        let now = CACurrentMediaTime()
        delegate?.keyboardSurfaceView(self, didTap: .character(emoji), at: point, touchStartedAt: now, touchEndedAt: now)
    }
}

private final class EmojiCell: UICollectionViewCell {
    static let reuseIdentifier = "EmojiCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 28)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.alpha = isHighlighted ? 0.72 : 1
        }
    }

    func configure(with emoji: String) {
        label.text = emoji
    }
}

final class KeyboardButton: UIButton {
    let key: KeyboardKey
    var hitTestOutsets: UIEdgeInsets = .zero
    private var latestTouchLocationInButton: CGPoint?

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

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitBounds = bounds.inset(by: UIEdgeInsets(
            top: -hitTestOutsets.top,
            left: -hitTestOutsets.left,
            bottom: -hitTestOutsets.bottom,
            right: -hitTestOutsets.right
        ))
        return hitBounds.contains(point)
    }

    func latestTouchLocation(in view: UIView) -> CGPoint? {
        guard let latestTouchLocationInButton else { return nil }
        return convert(latestTouchLocationInButton, to: view)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateLatestTouchLocation(from: touches)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateLatestTouchLocation(from: touches)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateLatestTouchLocation(from: touches)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateLatestTouchLocation(from: touches)
        super.touchesCancelled(touches, with: event)
    }

    private func updateLatestTouchLocation(from touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        latestTouchLocationInButton = touch.location(in: self)
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
