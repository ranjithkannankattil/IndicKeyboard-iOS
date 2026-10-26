//  Engines.swift
//  Transliteration engines shared by the keyboard extension, the container app and the tests.
//  Mirrors tools/engine_prototype.py exactly; Tests/golden.json checks the two stay in step.

import Foundation

/// A suggestion shown in the candidate bar.
public struct Candidate: Equatable {
    /// Text to display (and to commit, if `keys` is nil).
    public let text: String
    /// Replacement raw key sequence for the composer, or nil to commit `text` as-is.
    public let keys: String?
}

/// Turns a sequence of typed (Latin) keys into script output.
/// Engines are stateless with respect to the document: they always map the
/// whole current word's keys to its output, so the composer can recompute freely.
public protocol TransliterationEngine: AnyObject {
    var id: String { get }
    func output(for keys: String) -> String
    func candidates(for keys: String) -> [Candidate]
}

// MARK: - Swanalekha

/// Swanalekha (SMC) — greedy longest-match over a key→output table,
/// with numbered alternatives ("ka2", "ka3") exposed as candidates.
public final class SwanalekhaEngine: TransliterationEngine {
    public let id: String
    let rules: [String: String]
    let maxPatternLength: Int

    struct Segment { var pattern: String; var output: String }

    public init(id: String, rules: [String: String], maxPatternLength: Int) {
        self.id = id
        self.rules = rules
        self.maxPatternLength = maxPatternLength
    }

    func segments(_ keys: String) -> [Segment] {
        var segs: [Segment] = []
        for c in keys {
            let s = String(c)
            if let last = segs.last {
                let p = last.pattern + s
                if p.count <= maxPatternLength, let o = rules[p] {
                    segs[segs.count - 1] = Segment(pattern: p, output: o)
                    continue
                }
            }
            segs.append(Segment(pattern: s, output: rules[s] ?? s))
        }
        return segs
    }

    public func output(for keys: String) -> String {
        segments(keys).map(\.output).joined()
    }

    /// Alternatives for the last segment: pattern, pattern2, pattern3 …
    public func candidates(for keys: String) -> [Candidate] {
        guard let last = segments(keys).last else { return [] }
        let p = last.pattern
        var base = p
        if p.count > 1, let lastChar = p.last, lastChar.isASCII, lastChar.isNumber {
            let stripped = String(p.reversed().drop(while: { $0.isASCII && $0.isNumber }).reversed())
            if rules[stripped] != nil { base = stripped }
        }
        let prefix = String(keys.dropLast(p.count))
        var result: [Candidate] = []
        var seen = Set<String>()
        let suffixes: [Int?] = [nil, 2, 3, 4, 5, 6, 7, 8, 9]
        for i in suffixes {
            let pat = i.map { base + String($0) } ?? base
            if rules[pat] != nil, pat.count <= maxPatternLength {
                let newKeys = prefix + pat
                let out = output(for: newKeys)
                if !seen.contains(out) {
                    seen.insert(out)
                    result.append(Candidate(text: out, keys: newKeys))
                }
            } else if let i = i, i > 2 {
                break
            }
        }
        return result
    }
}

// MARK: - jquery.ime rule engine

/// Runs jquery.ime-format rules (regex patterns with optional key context),
/// the same rule format the Android Indic Keyboard uses for its transliteration methods.
public final class JQueryIMEEngine: TransliterationEngine {
    public let id: String
    let contextLength: Int
    let maxKeyLength: Int
    let patterns: [Pattern]

    struct Pattern {
        let input: NSRegularExpression
        let context: NSRegularExpression?
        let template: String
    }

    /// Cache of intermediate states for the most recent key sequence, so typing
    /// one more key only runs the rules once instead of replaying the whole word.
    private var cacheKeys: [Character] = []
    private var cacheStates: [(text: String, context: String)] = [("", "")]

    public init(id: String, contextLength: Int, maxKeyLength: Int, rules: [(input: String, context: String?, replacement: String)]) throws {
        self.id = id
        self.contextLength = contextLength
        self.maxKeyLength = maxKeyLength
        self.patterns = try rules.map { r in
            Pattern(input: try NSRegularExpression(pattern: r.input + "$"),
                    context: try r.context.map { try NSRegularExpression(pattern: $0 + "$") },
                    template: JQueryIMEEngine.icuTemplate(fromJS: r.replacement))
        }
    }

    /// Converts a JavaScript String.replace() replacement into an ICU template.
    /// JS: $1…$9 groups, $& whole match, $$ literal dollar; backslash is literal.
    static func icuTemplate(fromJS js: String) -> String {
        // Work on code points: as Characters, "1ാ" (digit + vowel sign) would be one cluster.
        var out = String.UnicodeScalarView()
        let chars = Array(js.unicodeScalars)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "$", i + 1 < chars.count {
                let n = chars[i + 1]
                if ("0"..."9").contains(n) { out.append(c); out.append(n); i += 2; continue }
                if n == "&" { out.append(contentsOf: "$0".unicodeScalars); i += 2; continue }
                if n == "$" { out.append(contentsOf: "\\$".unicodeScalars); i += 2; continue }
            }
            if c == "\\" { out.append(contentsOf: "\\\\".unicodeScalars) }
            else if c == "$" { out.append(contentsOf: "\\$".unicodeScalars) }
            else { out.append(c) }
            i += 1
        }
        return String(out)
    }

    /// One jquery.ime transliterate() call. Returns the replaced input.
    func transliterate(_ input: String, context: String) -> String {
        let ns = input as NSString
        let range = NSRange(location: 0, length: ns.length)
        for p in patterns {
            guard let m = p.input.firstMatch(in: input, options: [], range: range) else { continue }
            if let cx = p.context {
                let cns = context as NSString
                if cx.firstMatch(in: context, options: [], range: NSRange(location: 0, length: cns.length)) == nil { continue }
            }
            let rep = p.input.replacementString(for: m, in: input, offset: 0, template: p.template)
            return ns.replacingCharacters(in: m.range, with: rep)
        }
        return input
    }

    /// Applies one key to a state, exactly like jquery.ime's keypress handler.
    func step(_ state: (text: String, context: String), _ c: Character) -> (text: String, context: String) {
        let text = state.text as NSString
        let start = max(0, text.length - maxKeyLength)   // UTF-16 units, as in JavaScript
        let input = text.substring(from: start) + String(c)
        let out = transliterate(input, context: state.context)
        var ctx = state.context + String(c)
        if contextLength > 0 {
            if ctx.count > contextLength { ctx = String(ctx.suffix(contextLength)) }
        } else {
            ctx = ""
        }
        return (text.substring(to: start) + out, ctx)
    }

    public func output(for keys: String) -> String {
        let k = Array(keys)
        // Reuse the cached prefix when possible.
        var common = 0
        while common < k.count, common < cacheKeys.count, k[common] == cacheKeys[common] { common += 1 }
        cacheKeys = Array(k.prefix(common))
        cacheStates = Array(cacheStates.prefix(common + 1))
        var state = cacheStates[common]
        for c in k[common...] {
            state = step(state, c)
            cacheKeys.append(c)
            cacheStates.append(state)
        }
        return state.text
    }

    public func candidates(for keys: String) -> [Candidate] {
        let out = output(for: keys)
        return out.isEmpty ? [] : [Candidate(text: out, keys: keys)]
    }
}

// MARK: - Loading

public enum EngineError: Error { case missingResource(String), badFormat(String) }

/// Finds bundled JSON resources whether Xcode copied them flat or kept their folder.
public enum ResourceLocator {
    public static var bundle: Bundle { Bundle(for: BundleToken.self) }
    private final class BundleToken {}

    public static func url(_ name: String, subdirectory: String?) -> URL? {
        bundle.url(forResource: name, withExtension: "json")
            ?? subdirectory.flatMap { bundle.url(forResource: name, withExtension: "json", subdirectory: $0) }
            ?? subdirectory.flatMap { bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources/" + $0) }
    }

    public static func json(_ name: String, subdirectory: String?) throws -> [String: Any] {
        guard let url = url(name, subdirectory: subdirectory) else { throw EngineError.missingResource(name) }
        let data = try Data(contentsOf: url)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw EngineError.badFormat(name) }
        return obj
    }
}

public enum EngineLoader {
    private static var cache: [String: TransliterationEngine] = [:]

    /// Loads a transliteration scheme from Schemes/<file>.json.
    public static func engine(file: String) throws -> TransliterationEngine {
        if let e = cache[file] { return e }
        let j = try ResourceLocator.json(file, subdirectory: "Schemes")
        let engine: TransliterationEngine
        switch j["engine"] as? String {
        case "swanalekha":
            guard let rules = j["rules"] as? [String: String] else { throw EngineError.badFormat(file) }
            engine = SwanalekhaEngine(id: j["id"] as? String ?? file, rules: rules,
                                      maxPatternLength: j["maxPatternLength"] as? Int ?? 5)
        case "jqueryime":
            guard let pats = j["patterns"] as? [[String: String]] else { throw EngineError.badFormat(file) }
            let rules = pats.compactMap { p -> (input: String, context: String?, replacement: String)? in
                guard let input = p["input"], let rep = p["replacement"] else { return nil }
                return (input, p["context"], rep)
            }
            engine = try JQueryIMEEngine(id: j["id"] as? String ?? file,
                                         contextLength: j["contextLength"] as? Int ?? 0,
                                         maxKeyLength: j["maxKeyLength"] as? Int ?? 1,
                                         rules: rules)
        default:
            throw EngineError.badFormat(file)
        }
        cache[file] = engine
        return engine
    }
}
