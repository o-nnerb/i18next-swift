// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Fallback language configuration (`fallbackLng`).
public enum FallbackLanguages: Sendable, Hashable {
    /// `fallbackLng: false`.
    case none
    case list([String])
    /// Per-language fallbacks. The `"default"` entry applies when nothing else matches.
    case perLanguage([String: [String]])
}

extension FallbackLanguages: ExpressibleByArrayLiteral, ExpressibleByStringLiteral {
    public init(arrayLiteral elements: String...) { self = .list(elements) }
    public init(stringLiteral value: String) { self = .list([value]) }
}

/// Which variants of the active language are resolved and loaded (`load`).
public enum LoadStrategy: Sendable, Hashable {
    /// `pt-BR` and `pt`.
    case all
    /// `pt-BR` only.
    case currentOnly
    /// `pt` only.
    case languageOnly
}

/// Language code handling, following i18next's `LanguageUtils`.
public struct LanguageUtils: Sendable {
    public var fallbackLng: FallbackLanguages
    public var load: LoadStrategy
    public var lowerCaseLng: Bool
    /// `nil` is i18next's "unset", which behaves like `true` when a code is canonicalized.
    public var cleanCode: Bool?

    public init(
        fallbackLng: FallbackLanguages = .none,
        load: LoadStrategy = .all,
        lowerCaseLng: Bool = false,
        cleanCode: Bool? = nil
    ) {
        self.fallbackLng = fallbackLng
        self.load = load
        self.lowerCaseLng = lowerCaseLng
        self.cleanCode = cleanCode
    }

    // MARK: Codes

    /// `pt-br` → `pt-BR`, `zh-hant` → `zh-Hant`. A code that isn't a well-formed BCP 47 tag is returned as it is
    /// (`pt_BR` stays `pt_BR`).
    public func format(_ code: String) -> String {
        let hasSubtags = code.contains("-")
        if hasSubtags || cleanCode != false {
            let canonical = BCP47.canonical(code)
            if let canonical, hasSubtags || canonical.lowercased() == code.lowercased() {
                return lowerCaseLng ? canonical.lowercased() : canonical
            }
            if canonical != nil { return code.lowercased() }
        }
        return (lowerCaseLng || (cleanCode == true && !hasSubtags)) ? code.lowercased() : code
    }

    /// `pt-BR` → `pt`. Underscores count as hyphens.
    public func languagePart(_ code: String) -> String {
        let cleaned = Self.hyphenated(code)
        guard let dash = cleaned.firstIndex(of: "-") else { return cleaned }
        return format(String(cleaned[..<dash]))
    }

    /// `zh-Hant-TW` → `zh-Hant`; nil when the code has no script or region to drop, or ends in a private use tag.
    public func scriptPart(_ code: String) -> String? {
        let parts = Self.hyphenated(code).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count > 2 else { return nil }
        let kept = parts.dropLast()
        if kept.last?.lowercased() == "x" { return nil }
        return format(kept.joined(separator: "-"))
    }

    private static func hyphenated(_ code: String) -> String {
        String(code.map { $0 == "_" ? "-" : $0 })
    }

    // MARK: Fallbacks

    /// The fallback languages for `code`. For per-language maps: the exact code, its script part, its formatted
    /// form, its language part, then `default`.
    public func fallbackCodes(_ fallbacks: FallbackLanguages, for code: String?) -> [String] {
        switch fallbacks {
        case .none:
            return []
        case .list(let list):
            return list
        case .perLanguage(let map):
            guard let code else { return map["default"] ?? [] }
            let candidates = [code, scriptPart(code), format(code), languagePart(code), "default"]
            for candidate in candidates {
                if let candidate, let found = map[candidate], !found.isEmpty { return found }
            }
            return []
        }
    }

    /// Ordered, de-duplicated languages to try for `code`: the code, its script part, its language part, then the
    /// fallbacks. `fallback` overrides `fallbackLng` for this call (`.none` is `false`).
    public func hierarchy(for code: String?, fallback: FallbackLanguages? = nil) -> [String] {
        var codes: [String] = []
        func add(_ candidate: String?) {
            guard let candidate, !candidate.isEmpty else { return }
            codes.append(candidate)
        }

        if let code {
            if code.contains("-") || code.contains("_") {
                if load != .languageOnly { add(format(code)) }
                if load != .languageOnly, load != .currentOnly { add(scriptPart(code)) }
                if load != .currentOnly { add(languagePart(code)) }
            } else {
                add(format(code))
            }
        }
        for fallbackCode in fallbackCodes(fallback ?? fallbackLng, for: code) {
            let formatted = format(fallbackCode)
            if !codes.contains(formatted) { add(formatted) }
        }
        return codes
    }
}

// MARK: - BCP 47

/// Structural canonicalization of language tags (case, ordering of variants and extensions) plus a few of the
/// deprecated-subtag aliases. This is what `Intl.getCanonicalLocales` does for the tags that matter here; ICU's full
/// alias data (for example `sgn-BE-FR` → `sfb`) is not included.
enum BCP47 {
    private static let languageAliases = ["iw": "he", "ji": "yi", "in": "id", "jw": "jv", "mo": "ro"]
    private static let regionAliases = [
        "UK": "GB", "BU": "MM", "DD": "DE", "FX": "FR", "TP": "TL", "YD": "YE", "ZR": "CD",
    ]

    static func canonical(_ tag: String) -> String? {
        let subtags = tag.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard !subtags.isEmpty,
            subtags.allSatisfy({
                !$0.isEmpty && $0.count <= 8 && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
            })
        else { return nil }

        let language = subtags[0]
        guard language.allSatisfy(\.isLetter), (2...3).contains(language.count) || (5...8).contains(language.count)
        else { return nil }

        var result = [languageAliases[language.lowercased()] ?? language.lowercased()]
        var index = 1

        if index < subtags.count, subtags[index].count == 4, subtags[index].allSatisfy(\.isLetter) {
            result.append(subtags[index].prefix(1).uppercased() + subtags[index].dropFirst().lowercased())
            index += 1
        }
        if index < subtags.count {
            let region = subtags[index]
            if (region.count == 2 && region.allSatisfy(\.isLetter))
                || (region.count == 3 && region.allSatisfy(\.isNumber))
            {
                result.append(regionAliases[region.uppercased()] ?? region.uppercased())
                index += 1
            }
        }

        var variants: [String] = []
        while index < subtags.count, isVariant(subtags[index]) {
            variants.append(subtags[index].lowercased())
            index += 1
        }
        result += variants.sorted()

        var extensions: [(singleton: String, subtags: [String])] = []
        while index < subtags.count, subtags[index].count == 1, subtags[index].lowercased() != "x" {
            let singleton = subtags[index].lowercased()
            index += 1
            var body: [String] = []
            while index < subtags.count, (2...8).contains(subtags[index].count) {
                body.append(subtags[index].lowercased())
                index += 1
            }
            guard !body.isEmpty else { return nil }
            extensions.append((singleton, body))
        }
        for ext in extensions.sorted(by: { $0.singleton < $1.singleton }) {
            result.append(ext.singleton)
            result += ext.subtags
        }

        if index < subtags.count {
            guard subtags[index].lowercased() == "x", index + 1 < subtags.count else { return nil }
            result += subtags[index...].map { $0.lowercased() }
            index = subtags.count
        }
        return index == subtags.count ? result.joined(separator: "-") : nil
    }

    private static func isVariant(_ subtag: String) -> Bool {
        (5...8).contains(subtag.count) || (subtag.count == 4 && subtag.first?.isNumber == true)
    }
}
