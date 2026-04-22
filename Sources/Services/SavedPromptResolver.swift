import Foundation

/// Maps `<prefix><alias>` inputs to full prompt expansions and surfaces
/// autocomplete matches while the user is still typing an alias.
enum SavedPromptResolver {

    /// Expand an input to its saved-prompt equivalent, or return `nil` when
    /// the input is not an alias invocation.
    ///
    /// Rules:
    /// - `<prefix><alias>` alone expands to the saved prompt verbatim.
    /// - `<prefix><alias> <context>` expands to `<saved prompt>\n\n<context>`.
    /// - Any trailing whitespace between the alias and the context collapses.
    /// - Aliases are case-sensitive.
    /// - An empty prefix never matches (guards against accidental expansion).
    static func resolve(
        input: String,
        prefix: String,
        savedPrompts: [SavedPrompt]
    ) -> String? {
        guard !prefix.isEmpty else { return nil }
        guard input.hasPrefix(prefix) else { return nil }
        let rest = String(input.dropFirst(prefix.count))
        guard !rest.isEmpty else { return nil }

        // Split on the first whitespace run.
        let (alias, context) = split(rest)
        guard let match = savedPrompts.first(where: { $0.alias == alias }) else {
            return nil
        }
        if context.isEmpty {
            return match.prompt
        }
        return "\(match.prompt)\n\n\(context)"
    }

    /// Return saved prompts whose aliases start with the fragment the user
    /// has typed after the prefix. Returns `[]` once the user has typed
    /// a full alias followed by a space (they have committed to sending).
    static func matches(
        input: String,
        prefix: String,
        savedPrompts: [SavedPrompt]
    ) -> [SavedPrompt] {
        guard !prefix.isEmpty else { return [] }
        guard input.hasPrefix(prefix) else { return [] }
        let rest = String(input.dropFirst(prefix.count))

        // Once whitespace is typed, autocomplete no longer applies - the
        // user has moved on to providing context.
        if rest.contains(where: { $0.isWhitespace }) {
            return []
        }

        let matched = savedPrompts
            .filter { $0.alias.hasPrefix(rest) }
            .sorted { $0.alias < $1.alias }
        return matched
    }

    // MARK: - Helpers

    /// Split `"translate    hello   world"` into (`"translate"`, `"hello world"`).
    private static func split(_ rest: String) -> (alias: String, context: String) {
        guard let firstSpace = rest.firstIndex(where: { $0.isWhitespace }) else {
            return (rest, "")
        }
        let alias = String(rest[..<firstSpace])
        let tail = rest[firstSpace...]
            .trimmingCharacters(in: .whitespaces)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return (alias, tail)
    }
}
