// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation
import I18next

/// Why a built-in formatter declined a value or option. i18next logs this and keeps the value, and so does `t`.
struct FormatFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Typed reads of the options a formatter was given, with the leniency of `Intl` (numeric strings count as numbers).
struct FormatOptions {
    let values: [String: JSONValue]

    func string(_ name: String) -> String? {
        guard let value = values[name] else { return nil }
        switch value {
        case .string(let text): return text
        case .number, .bool: return value.interpolationString
        default: return nil
        }
    }

    func int(_ name: String) throws -> Int? {
        guard let value = values[name] else { return nil }
        switch value {
        case .number(let number) where number == number.rounded(): return Int(number)
        case .string(let text): if let number = Int(text) { return number }
        default: break
        }
        throw FormatFailure("\(name) must be an integer")
    }

    func bool(_ name: String) -> Bool? {
        guard let value = values[name] else { return nil }
        switch value {
        case .bool(let flag): return flag
        case .string("true"): return true
        case .string("false"): return false
        default: return nil
        }
    }

    /// One of `allowed`, or nil when the option is absent. Anything else is a `RangeError` in `Intl`.
    func choice(_ name: String, _ allowed: [String]) throws -> String? {
        guard let text = string(name) else { return nil }
        guard allowed.contains(text) else { throw FormatFailure("\(name): \(text) is not one of \(allowed)") }
        return text
    }

    static func locale(for language: String?) -> Locale {
        guard let language, !language.isEmpty else { return Locale.current }
        return Locale(identifier: language)
    }

    /// The tags to look a locale up under in CLDR data, most specific first: `pt-br` is tried as `pt-BR`, then `pt`.
    /// Unicode extensions (`-u-nu-latn`) and POSIX suffixes (`@x`, `.UTF-8`) are not part of the lookup. CLDR's parent
    /// locales are followed where they aren't the plain truncation: `es-MX` inherits from `es-419`, `pt-AO` from
    /// `pt-PT`, and Chinese without a script is `zh-Hant` in Taiwan, Hong Kong and Macao, `zh-Hans` elsewhere.
    static func lookupTags(for language: String?) -> [String] {
        guard let language, !language.isEmpty else { return lookupTags(for: Locale.current.identifier) }
        var text = language.replacingOccurrences(of: "_", with: "-")
        for separator in ["@", "."] { text = text.components(separatedBy: separator).first ?? text }
        var parts: [String] = []
        for (index, part) in text.split(separator: "-").enumerated() {
            if index > 0, part.count == 1 { break }  // "u", "x", …: an extension starts here
            switch (index, part.count) {
            case (0, _): parts.append(part.lowercased())
            case (_, 4): parts.append(part.prefix(1).uppercased() + part.dropFirst().lowercased())
            case (_, 2), (_, 3): parts.append(part.uppercased())
            default: parts.append(String(part))
            }
        }
        guard let languageCode = parts.first else { return [] }
        let hasScript = parts.count > 1 && parts[1].count == 4
        let region = parts.dropFirst().first { $0.count == 2 || ($0.count == 3 && $0.allSatisfy(\.isNumber)) }

        if languageCode == "zh", !hasScript {
            parts.insert(["TW", "HK", "MO"].contains(region) ? "Hant" : "Hans", at: 1)
        }
        var tags = (1...parts.count).reversed().map { parts.prefix($0).joined(separator: "-") }
        let latinAmerica: Set<String> = [
            "419", "AR", "BO", "CL", "CO", "CR", "CU", "DO", "EC", "GT", "HN", "MX", "NI", "PA", "PE", "PR", "PY", "SV",
            "US", "UY", "VE",
        ]
        if languageCode == "es", let region, latinAmerica.contains(region), region != "419" {
            tags.insert("es-419", at: tags.count - 1)
        }
        if languageCode == "pt", let region, region != "BR" {
            tags.insert("pt-PT", at: tags.count - 1)
        }
        return tags
    }

    /// The entry of a generated CLDR table for `language`: its own, or the nearest parent's.
    static func lookup<Value>(_ table: [String: Value], for language: String?) -> Value? {
        for tag in lookupTags(for: language) { if let value = table[tag] { return value } }
        return nil
    }
}

extension JSONValue {
    /// A number, or text that reads as one, as `Intl.NumberFormat` accepts.
    var asNumber: Double? {
        switch self {
        case .number(let number): return number
        case .string(let text): return Double(text.trimmingCharacters(in: .whitespaces))
        case .bool(let flag): return flag ? 1 : 0
        default: return nil
        }
    }
}
