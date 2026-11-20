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
