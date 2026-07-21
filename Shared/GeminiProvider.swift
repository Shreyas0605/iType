import Foundation

/// Gemini implementation of `AIProvider`.
///
/// The model is never hardcoded: on first use the provider calls the ListModels
/// API, picks the best model that supports `generateContent` (prefers current
/// "flash" models), and caches the choice. If a cached model later returns
/// NOT_FOUND (Google retires models over time), the cache is cleared, the model
/// is re-detected, and the request is retried once — so both the app and the
/// keyboard heal automatically without a new build.
struct GeminiProvider: AIProvider {
    let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - AIProvider

    func rewrite(text: String, tone: RewriteTone, variations: Int) async throws -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.empty }

        let nonce = UUID().uuidString.prefix(8)
        let prompt = """
        You are a writing assistant that rewrites a user's message.
        \(tone.instruction)
        Produce exactly \(variations) distinct rewrites of the message below.
        Rules:
        - Preserve the original meaning and language.
        - Only fix grammar, spelling, clarity and tone.
        - Do not add greetings, quotes, explanations or labels.
        - Each rewrite must be different from the others.
        - Return only the rewrites.
        Variation seed: \(nonce)

        Message:
        \(trimmed)
        """

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 1.0,
                "topP": 0.95,
                "candidateCount": 1,
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "ARRAY",
                    "items": ["type": "STRING"]
                ]
            ]
        ]

        let data = try await generate(body)
        let text = try firstText(from: data)
        let rewrites = parseRewrites(text)
        guard !rewrites.isEmpty else { throw AIError.empty }
        if rewrites.count >= variations { return Array(rewrites.prefix(variations)) }
        var padded = rewrites
        while padded.count < variations { padded.append(rewrites[padded.count % rewrites.count]) }
        return padded
    }

    @discardableResult
    func testConnection() async throws -> String {
        // Force a fresh detection so Test always reflects current availability.
        SettingsStore.shared.selectedModel = nil
        let model = try await resolveModel()
        let body: [String: Any] = [
            "contents": [["parts": [["text": "Reply with the single word: ok"]]]],
            "generationConfig": ["temperature": 0, "maxOutputTokens": 5]
        ]
        _ = try await post(body, model: model)
        return model
    }

    // MARK: - Model resolution

    /// Cached model, or detect one via the ListModels API.
    private func resolveModel() async throws -> String {
        if let cached = SettingsStore.shared.selectedModel, !cached.isEmpty {
            return cached
        }
        let detected = try await detectModel()
        SettingsStore.shared.selectedModel = detected
        return detected
    }

    /// Query ListModels and pick the best `generateContent` model.
    private func detectModel() async throws -> String {
        guard let url = URL(string: "\(AppConstants.geminiBaseURL)?key=\(apiKey)&pageSize=200") else {
            throw AIError.network("Bad URL")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.network("No response") }
        if http.statusCode != 200 {
            let message = errorMessage(from: data)
            if isKeyError(status: http.statusCode, message: message) { throw AIError.invalidKey }
            // Listing failed for another reason — fall back to known names.
            return AppConstants.geminiFallbackModels[0]
        }

        struct ModelList: Decodable {
            struct Model: Decodable {
                let name: String
                let supportedGenerationMethods: [String]?
            }
            let models: [Model]?
        }
        guard let list = try? JSONDecoder().decode(ModelList.self, from: data),
              let models = list.models, !models.isEmpty else {
            return AppConstants.geminiFallbackModels[0]
        }

        // Candidates: support generateContent, text models only.
        let excluded = ["vision", "embedding", "embed", "tts", "audio", "image", "video",
                        "live", "exp", "thinking", "learnlm", "aqa", "gemma", "imagen", "veo"]
        let candidates = models
            .filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }
            .filter { name in
                let lower = name.lowercased()
                return lower.contains("gemini") && !excluded.contains { lower.contains($0) }
            }

        guard !candidates.isEmpty else { throw AIError.modelUnavailable }

        // Rank: preferred pattern (flash > pro) first, then higher version, then
        // shorter (plain names beat dated/suffixed variants).
        func score(_ name: String) -> (Int, Double, Int) {
            let lower = name.lowercased()
            var patternRank = AppConstants.geminiPreferredPatterns.count
            for (i, pattern) in AppConstants.geminiPreferredPatterns.enumerated()
            where lower.contains(pattern) { patternRank = i; break }
            var version = 0.0
            if let match = lower.range(of: #"(\d+)\.(\d+)"#, options: .regularExpression) {
                version = Double(lower[match]) ?? 0
            }
            return (patternRank, -version, name.count)
        }
        let best = candidates.min { a, b in
            let sa = score(a), sb = score(b)
            if sa.0 != sb.0 { return sa.0 < sb.0 }
            if sa.1 != sb.1 { return sa.1 < sb.1 }
            return sa.2 < sb.2
        }
        return best ?? candidates[0]
    }

    // MARK: - Networking

    /// generateContent with automatic re-detection if the cached model is gone.
    private func generate(_ body: [String: Any]) async throws -> Data {
        let model = try await resolveModel()
        do {
            return try await post(body, model: model)
        } catch AIError.modelUnavailable {
            // Cached model was retired: re-detect once and retry.
            SettingsStore.shared.selectedModel = nil
            let fresh = try await resolveModel()
            guard fresh != model else { throw AIError.modelUnavailable }
            return try await post(body, model: fresh)
        }
    }

    private func post(_ body: [String: Any], model: String) async throws -> Data {
        guard let endpoint = URL(string: "\(AppConstants.geminiBaseURL)/\(model):generateContent?key=\(apiKey)") else {
            throw AIError.network("Bad URL")
        }
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            throw AIError.network("Encoding failed")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.network("No response") }
        if http.statusCode == 200 { return data }

        let message = errorMessage(from: data)
        if http.statusCode == 404 || message.uppercased().contains("NOT_FOUND") {
            throw AIError.modelUnavailable
        }
        if isKeyError(status: http.statusCode, message: message) {
            throw AIError.invalidKey
        }
        throw AIError.server(http.statusCode, message)
    }

    private func isKeyError(status: Int, message: String) -> Bool {
        guard status == 400 || status == 401 || status == 403 else { return false }
        let lower = message.lowercased()
        return lower.contains("api key") || lower.contains("api_key") || lower.contains("permission")
            || lower.contains("unauthenticated") || lower.contains("invalid")
    }

    // MARK: - Parsing

    private func firstText(from data: Data) throws -> String {
        struct Response: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw AIError.decoding
        }
        let text = decoded.candidates?.first?.content?.parts?
            .compactMap { $0.text }.joined() ?? ""
        guard !text.isEmpty else { throw AIError.empty }
        return text
    }

    private func parseRewrites(_ text: String) -> [String] {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let array = try? JSONDecoder().decode([String].self, from: data) {
            let items = array.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !items.isEmpty { return items }
        }

        let lines = cleaned.split(whereSeparator: \.isNewline).map { line -> String in
            var s = String(line).trimmingCharacters(in: .whitespaces)
            while let first = s.first, first == "-" || first == "*" || first == "•" || first == "\"" {
                s.removeFirst(); s = s.trimmingCharacters(in: .whitespaces)
            }
            if let dot = s.firstIndex(of: "."), let n = Int(s[s.startIndex..<dot]), n <= 9 {
                s = String(s[s.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
            }
            if s.hasSuffix("\"") { s.removeLast() }
            return s
        }.filter { !$0.isEmpty }
        return lines
    }

    private func errorMessage(from data: Data) -> String {
        struct ErrorResponse: Decodable { struct E: Decodable { let message: String? }; let error: E? }
        if let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data),
           let msg = decoded.error?.message, !msg.isEmpty {
            return msg
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}
