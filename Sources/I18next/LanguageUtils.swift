// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Fallback language configuration (`fallbackLng`).
public enum FallbackLanguages: Sendable, Hashable {
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

public enum LanguageUtils {
    private static let scriptSubtags: Set<String> = ["hans", "hant", "latn", "cyrl", "cans", "mong", "arab"]

    /// Normalizes casing: `pt-br` → `pt-BR`, `zh-hans-cn` → `zh-Hans-CN`. Codes without `-` are returned as-is.
    public static func format(_ code: String) -> String {
        guard code.contains("-") else { return code }
        var parts = code.split(separator: "-", omittingEmptySubsequences: false).map(String.init)

        switch parts.count {
        case 2:
            parts[0] = parts[0].lowercased()
            parts[1] = parts[1].uppercased()
            if scriptSubtags.contains(parts[1].lowercased()) { parts[1] = capitalized(parts[1]) }
        case 3:
            parts[0] = parts[0].lowercased()
            if parts[1].count == 2 { parts[1] = parts[1].uppercased() }
            if parts[0] != "sgn", parts[2].count == 2 { parts[2] = parts[2].uppercased() }
            if scriptSubtags.contains(parts[1].lowercased()) { parts[1] = capitalized(parts[1]) }
            if scriptSubtags.contains(parts[2].lowercased()) { parts[2] = capitalized(parts[2]) }
        default:
            break
        }
        return parts.joined(separator: "-")
    }

    /// `pt-BR` → `pt`.
    public static func languagePart(_ code: String) -> String {
        guard let dash = code.firstIndex(of: "-") else { return code }
        return format(String(code[..<dash]))
    }

    /// Ordered, de-duplicated list of languages to try: the code, its language part, then the fallbacks.
    public static func hierarchy(
        for code: String?,
        fallback: FallbackLanguages,
        load: LoadStrategy = .all
    ) -> [String] {
        var codes: [String] = []
        func add(_ candidate: String) {
            guard !candidate.isEmpty, !codes.contains(candidate) else { return }
            codes.append(candidate)
        }

        if let code, !code.isEmpty {
            if load != .languageOnly || !code.contains("-") { add(format(code)) }
            if load != .currentOnly, code.contains("-") { add(languagePart(code)) }
        }
        for fallbackCode in fallbackCodes(fallback, for: code) {
            add(format(fallbackCode))
        }
        return codes
    }

    static func fallbackCodes(_ fallback: FallbackLanguages, for code: String?) -> [String] {
        switch fallback {
        case .none:
            return []
        case .list(let list):
            return list
        case .perLanguage(let map):
            guard let code else { return map["default"] ?? [] }
            return map[code] ?? map[languagePart(code)] ?? map["default"] ?? []
        }
    }

    private static func capitalized(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst().lowercased()
    }
}
