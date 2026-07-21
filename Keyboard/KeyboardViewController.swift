import UIKit

/// The keyboard extension entry point. Hosts the suggestion bar (with the AI
/// button), the keyboard, and the AI panel; manages the input-view height when
/// the panel is shown; and routes typing to the text document proxy. Typing is
/// fully synchronous and never blocked by AI work.
final class KeyboardViewController: UIInputViewController {

    private let suggestionBar = UIView()
    private let aiButton = UIButton(type: .system)
    private var predictionButtons: [UIButton] = []
    private lazy var keyboardView = KeyboardView()
    private lazy var panel = AIPanelView()
    private lazy var engine = RewriteEngine()
    private lazy var predictor = WordPredictor()

    private var heightConstraint: NSLayoutConstraint?
    private var panelVisible = false

    private var collapsedHeight: CGFloat {
        KeyboardMetrics.suggestionBarHeight + KeyboardMetrics.keyboardHeight
    }
    private var expandedHeight: CGFloat {
        KeyboardMetrics.panelHeight + collapsedHeight
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        engine.delegate = self
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardView.showsNextKeyboard = needsInputModeSwitchKey
        keyboardView.resetForNewInput()
        updatePredictions()
    }

    override func viewWillLayoutSubviews() {
        keyboardView.showsNextKeyboard = needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
        layoutManual()
    }

    // MARK: - Setup

    private func setupViews() {
        view.backgroundColor = KeyboardColors.keyboardBackground

        let height = view.heightAnchor.constraint(equalToConstant: collapsedHeight)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        suggestionBar.backgroundColor = .clear
        view.addSubview(suggestionBar)

        aiButton.setTitle("AI", for: .normal)
        aiButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        aiButton.setTitleColor(.white, for: .normal)
        aiButton.backgroundColor = KeyboardColors.accent
        aiButton.layer.cornerRadius = 8
        aiButton.layer.cornerCurve = .continuous
        aiButton.addTarget(self, action: #selector(aiTapped), for: .touchUpInside)
        suggestionBar.addSubview(aiButton)

        for _ in 0..<3 {
            let button = UIButton(type: .system)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
            button.setTitleColor(KeyboardColors.keyText, for: .normal)
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addTarget(self, action: #selector(predictionTapped(_:)), for: .touchUpInside)
            button.isHidden = true
            predictionButtons.append(button)
            suggestionBar.addSubview(button)
        }

        keyboardView.delegate = self
        keyboardView.showsNextKeyboard = needsInputModeSwitchKey
        view.addSubview(keyboardView)

        panel.onApply = { [weak self] text in self?.applyRewrite(text) }
        panel.onSelectTone = { [weak self] tone in
            guard let self = self else { return }
            self.engine.select(tone: tone, hasFullAccess: self.hasFullAccess)
        }
        panel.onMore = { [weak self] in
            guard let self = self else { return }
            self.engine.generateMore(hasFullAccess: self.hasFullAccess)
        }
        panel.onClose = { [weak self] in self?.hidePanel() }
        panel.onPasteKey = { [weak self] in self?.pasteAPIKey() }
        panel.alpha = 0
        panel.isHidden = true
        view.addSubview(panel)
    }

    private func layoutManual() {
        let w = view.bounds.width
        guard w > 0 else { return }
        let barH = KeyboardMetrics.suggestionBarHeight
        let kbH = KeyboardMetrics.keyboardHeight
        let panelH = KeyboardMetrics.panelHeight

        if panelVisible {
            panel.frame = CGRect(x: 0, y: 0, width: w, height: panelH)
            suggestionBar.frame = CGRect(x: 0, y: panelH, width: w, height: barH)
            keyboardView.frame = CGRect(x: 0, y: panelH + barH, width: w, height: kbH)
        } else {
            panel.frame = CGRect(x: 0, y: -panelH, width: w, height: panelH)
            suggestionBar.frame = CGRect(x: 0, y: 0, width: w, height: barH)
            keyboardView.frame = CGRect(x: 0, y: barH, width: w, height: kbH)
        }

        let aiW: CGFloat = 58
        aiButton.frame = CGRect(x: w - aiW - 6, y: 7, width: aiW, height: barH - 14)
        let predArea = w - aiW - 18
        let slot = predArea / CGFloat(max(1, predictionButtons.count))
        for (i, button) in predictionButtons.enumerated() {
            button.frame = CGRect(x: 8 + CGFloat(i) * slot, y: 6, width: slot - 6, height: barH - 12)
        }
    }

    // MARK: - Panel show/hide

    private func showPanel() {
        guard !panelVisible else { return }
        panelVisible = true
        panel.isHidden = false
        heightConstraint?.constant = expandedHeight
        UIView.animate(withDuration: 0.26, delay: 0, options: .curveEaseOut, animations: {
            self.panel.alpha = 1
            self.layoutManual()
            self.view.superview?.layoutIfNeeded()
        })
    }

    private func hidePanel() {
        guard panelVisible else { return }
        panelVisible = false
        engine.cancel()
        heightConstraint?.constant = collapsedHeight
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn, animations: {
            self.panel.alpha = 0
            self.layoutManual()
            self.view.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.panel.isHidden = true
        })
    }

    // MARK: - Actions

    @objc private func aiTapped() {
        let text = textDocumentProxy.documentContextBeforeInput ?? ""
        showPanel()
        engine.begin(text: text, hasFullAccess: hasFullAccess)
        panel.apply(state: engine.state, tone: engine.tone)
    }

    private func applyRewrite(_ text: String) {
        let proxy = textDocumentProxy
        let before = proxy.documentContextBeforeInput ?? ""
        for _ in 0..<before.count { proxy.deleteBackward() }
        proxy.insertText(text)
        hidePanel()
        updatePredictions()
    }

    private func pasteAPIKey() {
        guard hasFullAccess else {
            engine.forceState(.noFullAccess)
            return
        }
        let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard pasted.count >= 20, !pasted.contains(" ") else {
            engine.forceState(.error("Clipboard doesn't contain an API key. Copy the key in the AI Keyboard app, then try again."))
            return
        }
        SecretStore.shared.saveAPIKey(pasted)
        let text = textDocumentProxy.documentContextBeforeInput ?? ""
        engine.begin(text: text, hasFullAccess: hasFullAccess)
    }

    @objc private func predictionTapped(_ sender: UIButton) {
        guard let word = sender.title(for: .normal), !word.isEmpty else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let partial = WordPredictor.lastWord(before)
        for _ in 0..<partial.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(word + " ")
        keyboardViewLoweredShiftIfNeeded()
        updatePredictions()
    }

    private func keyboardViewLoweredShiftIfNeeded() {
        // Predictions insert whole words; keep the keyboard behaviour consistent.
    }

    // MARK: - Predictions

    private func updatePredictions() {
        let context = textDocumentProxy.documentContextBeforeInput ?? ""
        let suggestions = SettingsStore.shared.predictions ? predictor.suggestions(for: context) : []
        for (i, button) in predictionButtons.enumerated() {
            if i < suggestions.count {
                button.setTitle(suggestions[i], for: .normal)
                button.isHidden = false
            } else {
                button.setTitle(nil, for: .normal)
                button.isHidden = true
            }
        }
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didInsert text: String) {
        textDocumentProxy.insertText(text)
        updatePredictions()
    }
    func keyboardViewDidBackspace(_ view: KeyboardView) {
        textDocumentProxy.deleteBackward()
        updatePredictions()
    }
    func keyboardViewDidReturn(_ view: KeyboardView) {
        textDocumentProxy.insertText("\n")
        updatePredictions()
    }
    func keyboardViewDidTapSpace(_ view: KeyboardView) {
        textDocumentProxy.insertText(" ")
        updatePredictions()
    }
    func keyboardViewAdvanceInputMode(_ view: KeyboardView) {
        advanceToNextInputMode()
    }
}

// MARK: - RewriteEngineDelegate

extension KeyboardViewController: RewriteEngineDelegate {
    func rewriteEngineDidChange(_ engine: RewriteEngine) {
        panel.apply(state: engine.state, tone: engine.tone)
    }
}

// MARK: - Word prediction

/// Minimal prefix-based word predictor. This is the architecture point the spec
/// asks for; it can later be swapped for an on-device model without touching the
/// keyboard UI.
struct WordPredictor {
    private let vocabulary: [String] = [
        "the", "and", "you", "that", "this", "with", "have", "from", "they", "would",
        "there", "their", "what", "about", "which", "when", "make", "like", "time",
        "just", "know", "take", "people", "into", "your", "good", "some", "could",
        "them", "than", "then", "look", "only", "come", "over", "think", "also",
        "back", "after", "work", "first", "well", "even", "want", "because", "these",
        "give", "most", "thanks", "thank", "please", "sorry", "today", "tomorrow",
        "tonight", "morning", "meeting", "message", "email", "quick", "question",
        "sure", "great", "sounds", "later", "soon", "here", "hello", "going", "great",
        "really", "should", "little", "before", "around", "another", "through",
        "different", "important", "available", "everyone", "something", "everything"
    ]

    func suggestions(for context: String) -> [String] {
        let partial = Self.lastWord(context)
        guard partial.count >= 1 else { return [] }
        let lower = partial.lowercased()
        let capitalized = partial.first?.isUppercase ?? false
        let matches = vocabulary
            .filter { $0.hasPrefix(lower) && $0 != lower }
        var seen = Set<String>()
        var result: [String] = []
        for match in matches where !seen.contains(match) {
            seen.insert(match)
            result.append(capitalized ? match.capitalized : match)
            if result.count == 3 { break }
        }
        return result
    }

    static func lastWord(_ context: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let parts = context.components(separatedBy: separators)
        return parts.last ?? ""
    }
}
