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
    /// Restricts the languages that are resolved and loaded. `nil` (or an empty list) allows everything.
    public var supportedLngs: [String]?
    /// With `supportedLngs`, accept `de-AT` when `de` is supported.
    public var nonExplicitSupportedLngs: Bool

    public init(
        fallbackLng: FallbackLanguages = .none,
        load: LoadStrategy = .all,
        lowerCaseLng: Bool = false,
        cleanCode: Bool? = nil,
        supportedLngs: [String]? = nil,
        nonExplicitSupportedLngs: Bool = false
    ) {
        self.fallbackLng = fallbackLng
        self.load = load
        self.lowerCaseLng = lowerCaseLng
        self.cleanCode = cleanCode
        self.supportedLngs = supportedLngs
        self.nonExplicitSupportedLngs = nonExplicitSupportedLngs
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

    // MARK: Supported languages

    /// Whether `code` may be resolved and loaded under `supportedLngs`.
    public func isSupported(_ code: String?) -> Bool {
        guard var code else { return supportedLngs?.isEmpty ?? true }
        if load == .languageOnly || nonExplicitSupportedLngs { code = languagePart(code) }
        guard let supported = supportedLngs, !supported.isEmpty else { return true }
        let formatted = format(code)
        return supported.contains { format($0) == formatted }
    }

    /// The first of `codes` that is supported, else the closest supported language (script, then language part,
    /// then a regional variant of it), else the first fallback. i18next's `getBestMatchFromCodes`.
    public func bestMatch(from codes: [String]) -> String? {
        var found: String?
        for code in codes where found == nil {
            let cleaned = format(code)
            if supportedLngs == nil || isSupported(cleaned) { found = cleaned }
        }

        if found == nil, let supported = supportedLngs {
            for code in codes where found == nil {
                if let script = scriptPart(code), isSupported(script) {
                    found = script
                    continue
                }
                let languageOnly = languagePart(code)
                if isSupported(languageOnly) {
                    found = languageOnly
                    continue
                }
                found = supported.map(format).first { candidate in
                    if candidate == languageOnly { return true }
                    if !candidate.contains("-"), !languageOnly.contains("-") { return false }
                    if let dash = candidate.firstIndex(of: "-"), !languageOnly.contains("-"),
                        candidate[..<dash] == languageOnly
                    {
                        return true
                    }
                    return false
                }
            }
        }
        return found ?? fallbackCodes(fallbackLng, for: nil).first
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
            guard let candidate, !candidate.isEmpty, isSupported(candidate) else { return }
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

/// Canonicalization of language tags, as `Intl.getCanonicalLocales` does it: the structure (case, order of variants and
/// extensions) and the aliases of the Unicode CLDR (`iw` → `he`, `UK` → `GB`, `sgn-US` → `ase`; see
/// ``BCP47AliasData``). Keywords of the `-u-` extension are left as written, and so is the tag of a language this
/// doesn't know.
enum BCP47 {
    /// Tags whose three subtags were registered as one: the sign languages of Belgium and Switzerland.
    private static let combinedTags = ["sgn-be-fr": "sfb", "sgn-be-nl": "vgt", "sgn-ch-de": "sgg"]

    /// A variant that, with this language, stands for a language of its own (`zh-hakka` → `hak`).
    private static let languageOfVariant = [
        "zh-guoyu": "zh", "zh-hakka": "hak", "zh-xiang": "hsn", "art-lojban": "jbo", "cel-gaulish": "xtg",
        "no-bokmal": "nb", "no-nynorsk": "nn", "aa-saaho": "ssy", "hy-arevela": "hy", "hy-arevmda": "hyw",
    ]
    /// Variants that are left out of the tag, whatever the language.
    private static let retiredVariants: Set<String> = [
        "lojban", "hakka", "xiang", "bokmal", "nynorsk", "saaho", "arevela", "arevmda", "aaland",
    ]
    private static let renamedVariants = ["heploc": "alalc97", "polytoni": "polyton"]

    static func canonical(_ tag: String) -> String? {
        if let combined = combinedTags[tag.lowercased()] { return combined }
        let subtags = tag.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard !subtags.isEmpty,
            subtags.allSatisfy({
                !$0.isEmpty && $0.count <= 8 && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
            })
        else { return nil }

        let rawLanguage = subtags[0]
        guard rawLanguage.allSatisfy(\.isLetter),
            (2...3).contains(rawLanguage.count) || (5...8).contains(rawLanguage.count)
        else { return nil }

        var language = rawLanguage.lowercased()
        var script: String?
        var region: String?
        var index = 1

        if index < subtags.count, subtags[index].count == 4, subtags[index].allSatisfy(\.isLetter) {
            script = subtags[index].prefix(1).uppercased() + subtags[index].dropFirst().lowercased()
            index += 1
        }
        if index < subtags.count {
            let candidate = subtags[index]
            if (candidate.count == 2 && candidate.allSatisfy(\.isLetter))
                || (candidate.count == 3 && candidate.allSatisfy(\.isNumber))
            {
                region = candidate.uppercased()
                index += 1
            }
        }

        var variants: [String] = []
        while index < subtags.count, isVariant(subtags[index]) {
            variants.append(subtags[index].lowercased())
            index += 1
        }

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

        var privateUse: [String] = []
        if index < subtags.count {
            guard subtags[index].lowercased() == "x", index + 1 < subtags.count else { return nil }
            privateUse = subtags[index...].map { $0.lowercased() }
            index = subtags.count
        }
        guard index == subtags.count else { return nil }

        // Aliases. A variant may stand for the language (`zh-hakka`); then the language's own alias, the script's, the
        // region's (which may depend on the language) and the sign language of the region.
        for variant in variants {
            if let replacement = languageOfVariant["\(language)-\(variant)"] {
                language = replacement
                variants.removeAll { $0 == variant }
            }
        }
        if variants.contains("aaland"), region == nil { region = "AX" }
        if variants.contains("hepburn"), variants.contains("heploc") { variants.removeAll { $0 == "hepburn" } }
        variants = variants.filter { !retiredVariants.contains($0) }.map { renamedVariants[$0] ?? $0 }

        if let alias = BCP47AliasData.languages[language] {
            let parts = alias.split(separator: "-").map(String.init)
            language = parts[0]
            for part in parts.dropFirst() {
                if part.count == 4 { script = script ?? part } else { region = region ?? part }
            }
        }
        if let current = script, let replacement = BCP47AliasData.scripts[current] { script = replacement }
        if let current = region {
            region = BCP47AliasData.regionByLanguage[current]?[language] ?? BCP47AliasData.regions[current] ?? current
        }
        if language == "sgn", let current = region, let signLanguage = BCP47AliasData.signLanguages[current] {
            language = signLanguage
            region = nil
        }

        var result = [language]
        if let script { result.append(script) }
        if let region { result.append(region) }
        result += variants.sorted()
        for ext in extensions.sorted(by: { $0.singleton < $1.singleton }) {
            result.append(ext.singleton)
            result += ext.subtags
        }
        result += privateUse
        return result.joined(separator: "-")
    }

    private static func isVariant(_ subtag: String) -> Bool {
        (5...8).contains(subtag.count) || (subtag.count == 4 && subtag.first?.isNumber == true)
    }
}
