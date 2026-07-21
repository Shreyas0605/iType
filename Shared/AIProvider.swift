import Foundation

/// A rewrite tone. `rawValue` is the label shown on the tone chip (text only).
enum RewriteTone: String, CaseIterable, Identifiable {
    case professional = "Professional"
    case friendly     = "Friendly"
    case formal       = "Formal"
    case casual       = "Casual"
    case funny        = "Funny"
    case shorter      = "Shorter"
    case longer       = "Longer"
    case creative     = "Creative"
    case simple       = "Simple"
    case polite       = "Polite"
    case confident    = "Confident"
    case business     = "Business"
    case academic     = "Academic"
    case romantic     = "Romantic"
    case persuasive   = "Persuasive"

    var id: String { rawValue }
    var label: String { rawValue }

    /// Guidance appended to the rewrite prompt for this tone.
    var instruction: String {
        switch self {
        case .professional: return "Rewrite in a clear, professional tone suitable for the workplace."
        case .friendly:     return "Rewrite in a warm, friendly, approachable tone."
        case .formal:       return "Rewrite in a formal, respectful tone."
        case .casual:       return "Rewrite in a relaxed, casual, conversational tone."
        case .funny:        return "Rewrite with light, tasteful humor while keeping the meaning."
        case .shorter:      return "Rewrite to be as short and concise as possible without losing meaning."
        case .longer:       return "Rewrite with a little more detail and elaboration, staying natural."
        case .creative:     return "Rewrite in a creative, expressive, original way."
        case .simple:       return "Rewrite in simple, plain language that is easy to read."
        case .polite:       return "Rewrite in an especially polite and courteous tone."
        case .confident:    return "Rewrite in a confident, assertive tone."
        case .business:     return "Rewrite in a concise business tone suitable for email."
        case .academic:     return "Rewrite in a precise, academic tone."
        case .romantic:     return "Rewrite in a warm, romantic, affectionate tone."
        case .persuasive:   return "Rewrite in a persuasive, compelling tone."
        }
    }
}

enum AIError: LocalizedError {
    case missingKey
    case invalidKey
    case modelUnavailable
    case network(String)
    case decoding
    case empty
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingKey:            return "No API key configured."
        case .invalidKey:            return "The Gemini API key is invalid."
        case .modelUnavailable:      return "No supported Gemini model found for this key."
        case .network(let m):        return "Network error: \(m)"
        case .decoding:              return "Couldn't read the response."
        case .empty:                 return "The model returned no rewrites."
        case .server(let c, let m):  return "Server error (\(c)): \(m)"
        }
    }
}

/// Abstraction the UI depends on. Providers (Gemini, others later) implement it;
/// the keyboard and settings never reference a concrete provider directly.
protocol AIProvider {
    func rewrite(text: String, tone: RewriteTone, variations: Int) async throws -> [String]
    /// Verifies connectivity and returns the model that will be used.
    @discardableResult
    func testConnection() async throws -> String
}
