import Foundation

/// A saved prompt users can invoke with `<prefix><alias>`, e.g. `/translate`.
/// The `prompt` field is the full expansion sent to apfel.
struct SavedPrompt: Codable, Sendable, Equatable, Identifiable, Hashable {
    let id: UUID
    var alias: String
    var prompt: String

    init(id: UUID = UUID(), alias: String, prompt: String) {
        self.id = id
        self.alias = alias
        self.prompt = prompt
    }
}

extension SavedPrompt {
    /// Useful starter set seeded on first launch. Users can edit or remove.
    static let defaults: [SavedPrompt] = [
        SavedPrompt(
            alias: "translate",
            prompt: "Translate the following text to English. Return only the translation, no preamble."
        ),
        SavedPrompt(
            alias: "grammar",
            prompt: "Fix grammar and spelling. Return only the corrected text, no explanations."
        ),
        SavedPrompt(
            alias: "tldr",
            prompt: "Summarize the following in one short sentence. Return only the summary."
        ),
        SavedPrompt(
            alias: "explain",
            prompt: "Explain the following clearly and concisely. Assume the reader is a smart non-expert."
        ),
        SavedPrompt(
            alias: "email",
            prompt: "Rewrite the following as a polite, professional email. Keep it short."
        ),
    ]
}
