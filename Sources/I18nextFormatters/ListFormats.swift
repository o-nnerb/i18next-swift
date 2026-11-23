// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation
import I18next

/// `{{value, list}}`: `Intl.ListFormat` options mapped onto `ListFormatStyle`.
enum ListFormats {
    static func list(_ value: JSONValue, _ context: I18next.FormatContext) throws -> JSONValue {
        // `Intl.ListFormat` takes strings only (a string is a list of its characters).
        let strings: [String]
        switch value {
        case .array(let items):
            strings = try items.map {
                guard case .string(let text) = $0 else { throw FormatFailure("list items must be strings") }
                return text
            }
        case .string(let text):
            strings = text.map(String.init)
        default:
            throw FormatFailure("not a list")
        }
        let options = FormatOptions(values: context.options)

        let type = try options.choice("type", ["conjunction", "disjunction", "unit"]) ?? "conjunction"
        let width = try options.choice("style", ["long", "short", "narrow"]) ?? "long"
        if type == "unit" { return .string(unitList(strings, width: width, language: context.language)) }

        let widthStyle: ListFormatStyle<StringStyle, [String]>.Width =
            switch width {
            case "short": .short
            case "narrow": .narrow
            default: .standard
            }
        var style = ListFormatStyle<StringStyle, [String]>.list(
            type: type == "disjunction" ? .or : .and,
            width: widthStyle
        )
        style.locale = FormatOptions.locale(for: context.language)
        return .string(style.format(strings))
    }

    // MARK: unit lists

    /// `ListFormatStyle` has no `unit` type, so these come from CLDR's patterns (`CLDRListPatternData`): the pair
    /// pattern for two items, and for more, `start` joins the first to the rest, `end` the last two, `middle` the
    /// ones between.
    private static func unitList(_ items: [String], width: String, language: String?) -> String {
        let offset = ["long": 0, "short": 4, "narrow": 8][width] ?? 0
        let all =
            FormatOptions.lookup(CLDRListPatternData.unit, for: language)
            ?? CLDRListPatternData.unit["en"] ?? []
        guard all.count == 12 else { return items.joined(separator: ", ") }
        let (start, middle, end, pair) = (all[offset], all[offset + 1], all[offset + 2], all[offset + 3])

        let isolated = items.map { isolating($0, language: language) }
        func join(_ pattern: String, _ first: String, _ second: String) -> String {
            pattern.replacingOccurrences(of: "{0}", with: first).replacingOccurrences(of: "{1}", with: second)
        }
        switch isolated.count {
        case 0: return ""
        case 1: return isolated[0]
        case 2: return join(pair, isolated[0], isolated[1])
        default:
            var text = join(end, isolated[isolated.count - 2], isolated[isolated.count - 1])
            for index in stride(from: isolated.count - 3, through: 0, by: -1) {
                text = join(index == 0 ? start : middle, isolated[index], text)
            }
            return text
        }
    }

    /// ICU wraps an item in first-strong isolates when it reads in the other direction than the locale does
    /// (an English word in an Arabic list, a Hebrew one in an English list).
    private static func isolating(_ item: String, language: String?) -> String {
        guard let itemRightToLeft = firstStrongIsRightToLeft(item) else { return item }
        let tag = FormatOptions.lookupTags(for: language).last ?? "en"
        let localeRightToLeft = Locale.characterDirection(forLanguage: tag) == .rightToLeft
        return itemRightToLeft == localeRightToLeft ? item : "\u{2068}" + item + "\u{2069}"
    }

    /// The direction of the first letter that has one, or nil when the text has none (digits, punctuation).
    private static func firstStrongIsRightToLeft(_ text: String) -> Bool? {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF, 0x10800...0x10FFF, 0x1E800...0x1EFFF:
                if scalar.properties.isAlphabetic { return true }
            default:
                if scalar.properties.isAlphabetic { return false }
            }
        }
        return nil
    }
}
