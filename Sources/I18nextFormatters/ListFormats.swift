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
        guard type != "unit" else { throw FormatFailure("unit lists are not supported") }
        let width = try options.choice("style", ["long", "short", "narrow"]) ?? "long"

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
}
