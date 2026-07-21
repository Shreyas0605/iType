import Foundation

protocol RewriteEngineDelegate: AnyObject {
    func rewriteEngineDidChange(_ engine: RewriteEngine)
}

/// Owns the rewrite flow and talks to the AIProvider. Typing never waits on it;
/// all generation is async and cancellable. State changes are delivered on the
/// main queue.
final class RewriteEngine {
    enum State: Equatable {
        case idle
        case loading
        case loaded([String])
        case error(String)
        case needsKey
        case noFullAccess
    }

    private(set) var state: State = .idle {
        didSet { DispatchQueue.main.async { [weak self] in guard let self = self else { return }
            self.delegate?.rewriteEngineDidChange(self) } }
    }
    private(set) var tone: RewriteTone = .professional
    weak var delegate: RewriteEngineDelegate?

    private var sourceText = ""
    private var currentTask: Task<Void, Never>?

    func begin(text: String, hasFullAccess: Bool) {
        sourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        tone = .professional
        guard hasFullAccess else { state = .noFullAccess; return }
        guard !sourceText.isEmpty else { state = .idle; return }
        generate()
    }

    func select(tone newTone: RewriteTone, hasFullAccess: Bool) {
        tone = newTone
        guard hasFullAccess else { state = .noFullAccess; return }
        guard !sourceText.isEmpty else { state = .idle; return }
        generate()
    }

    func generateMore(hasFullAccess: Bool) {
        guard hasFullAccess else { state = .noFullAccess; return }
        guard !sourceText.isEmpty else { state = .idle; return }
        generate()
    }

    /// Externally set a display state (used for paste-flow feedback).
    func forceState(_ newState: State) {
        state = newState
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func generate() {
        guard let provider = AIProviderFactory.makeProvider() else { state = .needsKey; return }
        currentTask?.cancel()
        state = .loading
        let text = sourceText
        let tone = self.tone
        currentTask = Task { [weak self] in
            do {
                let results = try await provider.rewrite(text: text, tone: tone,
                                                         variations: AppConstants.defaultRewriteCount)
                if Task.isCancelled { return }
                self?.state = .loaded(results)
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                let message = (error as? AIError)?.errorDescription ?? error.localizedDescription
                self?.state = .error(message)
            }
        }
    }
}
