//  EnglishSuggester.swift
//  English predictions and autocorrection using Apple's on-device spell checker
//  (UITextChecker). No network and no Full Access needed.

import UIKit

final class EnglishSuggester {
    private let checker = UITextChecker()
    let language: String
    /// Words from the user's Text Replacements (Settings → Keyboard) and their expansions.
    private var shortcuts: [String: String] = [:]
    private var knownWords = Set<String>()
    /// Words the user rejected a correction for; never corrected again this session.
    private var ignored = Set<String>()

    private static let contractions: [String: String] = [
        "i": "I", "im": "I'm", "ive": "I've", "id": "I'd", "ill": "I'll",
        "dont": "don't", "didnt": "didn't", "doesnt": "doesn't", "isnt": "isn't", "wasnt": "wasn't",
        "arent": "aren't", "werent": "weren't", "havent": "haven't", "hasnt": "hasn't", "hadnt": "hadn't",
        "couldnt": "couldn't", "shouldnt": "shouldn't", "wouldnt": "wouldn't", "mustnt": "mustn't",
        "thats": "that's", "whats": "what's", "theres": "there's", "heres": "here's", "whos": "who's",
        "youre": "you're", "theyre": "they're", "youve": "you've", "theyve": "they've", "weve": "we've",
        "youll": "you'll", "theyll": "they'll", "itll": "it'll", "lets": "let's", "cant": "can't", "wont": "won't",
    ]
    /// Of the contractions above, the ones that are also real words: suggest, don't auto-apply.
    private static let ambiguous: Set<String> = ["ill", "id", "lets", "cant", "wont"]

    init() {
        let available = UITextChecker.availableLanguages
        let region = Locale.current.region?.identifier ?? "US"
        let preferred = ["en_\(region)", "en_GB", "en_US", "en"]
        language = preferred.first { available.contains($0) } ?? available.first { $0.hasPrefix("en") } ?? "en_US"
    }

    /// Text Replacements and contact names (contacts only arrive with Full Access).
    func load(lexicon: UILexicon) {
        for e in lexicon.entries {
            let key = e.userInput.lowercased()
            if key != e.documentText.lowercased() { shortcuts[key] = e.documentText }
            knownWords.insert(e.documentText.lowercased())
        }
    }

    func ignore(_ word: String) {
        ignored.insert(word.lowercased())
        UITextChecker.learnWord(word)
    }

    // MARK: Queries

    func isMisspelled(_ word: String) -> Bool {
        let ns = word as NSString
        let r = checker.rangeOfMisspelledWord(in: word, range: NSRange(location: 0, length: ns.length),
                                              startingAt: 0, wrap: false, language: language)
        return r.location != NSNotFound
    }

    /// The correction space would apply, if any.
    func autocorrection(for word: String) -> String? {
        let lower = word.lowercased()
        guard !word.isEmpty, !ignored.contains(lower), !knownWords.contains(lower),
              word.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) || $0 == "'" }) else { return nil }
        if let s = shortcuts[lower] { return s }
        if let c = Self.contractions[lower], !Self.ambiguous.contains(lower) { return matchCase(c, like: word) }
        guard word.count >= 2, isMisspelled(word) else { return nil }
        // All-caps words are usually acronyms; leave them.
        if word == word.uppercased() { return nil }
        let ns = word as NSString
        let guesses = checker.guesses(forWordRange: NSRange(location: 0, length: ns.length), in: word, language: language) ?? []
        let limit = word.count <= 4 ? 1 : 2
        guard let best = guesses.first(where: { !$0.contains(" ") && editDistance($0.lowercased(), lower) <= limit }) else { return nil }
        return matchCase(best, like: word)
    }

    /// Up to `limit` suggestions for the word being typed: corrections first, then completions.
    func suggestions(for word: String, limit: Int = 3) -> [String] {
        guard !word.isEmpty else { return [] }
        let lower = word.lowercased()
        let ns = word as NSString
        let range = NSRange(location: 0, length: ns.length)
        var out: [String] = []
        func add(_ s: String) {
            if !out.contains(where: { $0.lowercased() == s.lowercased() }), s.lowercased() != lower { out.append(s) }
        }
        if let s = shortcuts[lower] { add(s) }
        if let c = Self.contractions[lower] { add(matchCase(c, like: word)) }
        if isMisspelled(word) {
            (checker.guesses(forWordRange: range, in: word, language: language) ?? []).prefix(3).forEach { add(matchCase($0, like: word)) }
        }
        (checker.completions(forPartialWordRange: range, in: word, language: language) ?? [])
            .filter { $0.count > word.count }
            .prefix(4)
            .forEach { add(matchCase($0, like: word)) }
        return Array(out.prefix(limit))
    }

    // MARK: Helpers

    private func matchCase(_ s: String, like word: String) -> String {
        if word.count > 1, word == word.uppercased() { return s.uppercased() }
        if let f = word.first, f.isUppercase, let sf = s.first {
            return String(sf).uppercased() + s.dropFirst()
        }
        return s
    }

    /// Damerau–Levenshtein distance (a swap like "teh" → "the" counts as one edit).
    private func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }
}
