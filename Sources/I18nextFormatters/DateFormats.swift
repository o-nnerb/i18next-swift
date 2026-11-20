// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation
import I18next

/// `{{value, datetime}}` and `{{value, relativetime}}`: `Intl.DateTimeFormat` and `Intl.RelativeTimeFormat` options
/// mapped onto `DateFormatter` and `RelativeDateTimeFormatter`.
enum DateFormats {
    // MARK: datetime

    static func datetime(_ value: JSONValue, _ context: I18next.FormatContext) throws -> JSONValue {
        let options = FormatOptions(values: context.options)
        let date = try self.date(from: value)

        let formatter = DateFormatter()
        formatter.locale = FormatOptions.locale(for: context.language)
        if let zone = options.string("timeZone") {
            guard let timeZone = TimeZone(identifier: zone) ?? TimeZone(abbreviation: zone) else {
                throw FormatFailure("invalid time zone \(zone)")
            }
            formatter.timeZone = timeZone
        }

        let styles = ["full", "long", "medium", "short"]
        let dateStyle = try options.choice("dateStyle", styles)
        let timeStyle = try options.choice("timeStyle", styles)
        let template = try componentTemplate(options)

        if dateStyle != nil || timeStyle != nil {
            guard template.isEmpty else {
                throw FormatFailure("dateStyle and timeStyle can't be mixed with components")
            }
            formatter.dateStyle = dateStyle.map(style) ?? .none
            formatter.timeStyle = timeStyle.map(style) ?? .none
        } else {
            formatter.setLocalizedDateFormatFromTemplate(template.isEmpty ? "yMd" : template)
        }
        return .string(formatter.string(from: date))
    }

    /// JavaScript reads a number (or numeric text, or a boolean) as milliseconds since the epoch. Beyond what `Intl`
    /// accepts, text is also read as an ISO 8601 date, since JSON has no date type.
    private static func date(from value: JSONValue) throws -> Date {
        switch value {
        case .number(let milliseconds): return Date(timeIntervalSince1970: milliseconds / 1000)
        case .bool(let flag): return Date(timeIntervalSince1970: flag ? 0.001 : 0)
        case .string(let text):
            if let milliseconds = Double(text) { return Date(timeIntervalSince1970: milliseconds / 1000) }
            let formats: [Date.ISO8601FormatStyle] = [
                .iso8601, Date.ISO8601FormatStyle(includingFractionalSeconds: true),
                Date.ISO8601FormatStyle(timeZone: .current).year().month().day(),
            ]
            for style in formats { if let date = try? style.parse(text) { return date } }
            throw FormatFailure("not a date: \(text)")
        default: throw FormatFailure("not a date")
        }
    }

    private static func style(_ name: String) -> DateFormatter.Style {
        switch name {
        case "full": .full
        case "long": .long
        case "medium": .medium
        default: .short
        }
    }

    /// The ICU skeleton for `weekday`, `year`, `month`, `hour`, … , or "" when none is given.
    private static func componentTemplate(_ options: FormatOptions) throws -> String {
        var template = ""

        if let weekday = try options.choice("weekday", ["long", "short", "narrow"]) {
            template += ["long": "EEEE", "short": "EEE", "narrow": "EEEEE"][weekday] ?? ""
        }
        if let era = try options.choice("era", ["long", "short", "narrow"]) {
            template += ["long": "GGGG", "short": "G", "narrow": "GGGGG"][era] ?? ""
        }
        if let year = try options.choice("year", ["numeric", "2-digit"]) {
            template += year == "2-digit" ? "yy" : "y"
        }
        if let month = try options.choice("month", ["numeric", "2-digit", "long", "short", "narrow"]) {
            template +=
                ["numeric": "M", "2-digit": "MM", "long": "MMMM", "short": "MMM", "narrow": "MMMMM"][month] ?? ""
        }
        if let day = try options.choice("day", ["numeric", "2-digit"]) {
            template += day == "2-digit" ? "dd" : "d"
        }

        let hourCycle = try options.choice("hourCycle", ["h11", "h12", "h23", "h24"])
        let hour12 = options.bool("hour12")
        if let hour = try options.choice("hour", ["numeric", "2-digit"]) {
            var symbol = "j"
            if let hour12 {
                symbol = hour12 ? "h" : "H"
            } else if let hourCycle {
                symbol = ["h11": "K", "h12": "h", "h23": "H", "h24": "k"][hourCycle] ?? "j"
            }
            template += hour == "2-digit" ? symbol + symbol : symbol
        }
        if let minute = try options.choice("minute", ["numeric", "2-digit"]) {
            template += minute == "2-digit" ? "mm" : "m"
        }
        if let second = try options.choice("second", ["numeric", "2-digit"]) {
            template += second == "2-digit" ? "ss" : "s"
        }
        if let fraction = try options.int("fractionalSecondDigits") {
            guard (1...3).contains(fraction) else { throw FormatFailure("fractionalSecondDigits must be 1...3") }
            template += String(repeating: "S", count: fraction)
        }
        if let zone = try options.choice(
            "timeZoneName",
            ["short", "long", "shortOffset", "longOffset", "shortGeneric", "longGeneric"]
        ) {
            template +=
                [
                    "short": "z", "long": "zzzz", "shortOffset": "O", "longOffset": "OOOO", "shortGeneric": "v",
                    "longGeneric": "vvvv",
                ][zone] ?? ""
        }
        return template
    }

    // MARK: relativetime

    private static let units: [String: Calendar.Component] = [
        "second": .second, "minute": .minute, "hour": .hour, "day": .day, "week": .weekOfMonth, "month": .month,
        "quarter": .quarter, "year": .year,
    ]

    static func relativetime(_ value: JSONValue, _ context: I18next.FormatContext) throws -> JSONValue {
        guard let amount = value.asNumber, amount.isFinite else { throw FormatFailure("not a number") }
        let options = FormatOptions(values: context.options)

        var unitName = options.string("range") ?? "day"
        if unitName.hasSuffix("s") { unitName.removeLast() }
        guard let unit = units[unitName] else { throw FormatFailure("invalid unit \(unitName)") }

        let numeric = try options.choice("numeric", ["always", "auto"]) ?? "always"
        let width = try options.choice("style", ["long", "short", "narrow"]) ?? "long"

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = FormatOptions.locale(for: context.language)
        formatter.dateTimeStyle = numeric == "auto" ? .named : .numeric
        formatter.unitsStyle =
            switch width {
            case "short": .short
            case "narrow": .abbreviated
            default: .full
            }

        // `RelativeDateTimeFormatter` takes whole numbers, where `Intl` prints "in 2.5 days".
        guard amount == amount.rounded() else { throw FormatFailure("relative times must be whole numbers") }

        var components = DateComponents()
        components.setValue(Int(amount), for: unit)
        let text = formatter.localizedString(from: components)
        guard !text.isEmpty else { throw FormatFailure("\(unitName) is not supported") }  // quarters
        return .string(text)
    }
}
