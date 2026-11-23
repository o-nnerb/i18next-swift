// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation
import I18next

/// `{{value, number}}` and `{{value, currency}}`: `Intl.NumberFormat` options mapped onto `FormatStyle`.
enum NumberFormats {
    static func number(_ value: JSONValue, _ context: I18next.FormatContext) throws -> JSONValue {
        try format(value, context, forceCurrency: false)
    }

    static func currency(_ value: JSONValue, _ context: I18next.FormatContext) throws -> JSONValue {
        try format(value, context, forceCurrency: true)
    }

    private static func format(
        _ value: JSONValue,
        _ context: I18next.FormatContext,
        forceCurrency: Bool
    ) throws -> JSONValue {
        // `Intl.NumberFormat` turns anything that isn't a number into NaN and prints that.
        let number = value.asNumber ?? .nan
        let options = FormatOptions(values: context.options)
        let locale = FormatOptions.locale(for: context.language)

        let style =
            forceCurrency
            ? "currency" : try options.choice("style", ["decimal", "percent", "currency", "unit"]) ?? "decimal"

        var digits = try digitOptions(options, style: style, currency: options.string("currency"))
        let sign = try options.choice("signDisplay", ["auto", "never", "always", "exceptZero", "negative"]) ?? "auto"
        let grouping = options.bool("useGrouping") ?? true
        let notation =
            try options.choice("notation", ["standard", "scientific", "engineering", "compact"]) ?? "standard"

        // `Intl` caps decimals at 3 and percents at 0; `FormatStyle` only does when told. Currencies bring their own.
        if digits.significant == nil, digits.fraction == nil, notation != "compact" {
            switch style {
            case "percent": digits.fraction = 0...0
            case "currency": break
            default: digits.fraction = 0...3
            }
        }

        switch style {
        case "unit":
            guard let unit = options.string("unit") else { throw FormatFailure("unit is required") }
            let display = try options.choice("unitDisplay", ["short", "narrow", "long"]) ?? "short"
            var format = FloatingPointFormatStyle<Double>(locale: locale)
            format = format.grouping(grouping ? .automatic : .never).sign(strategy: signStrategy(sign))
            format = apply(digits, to: format).rounded(rule: .toNearestOrAwayFromZero)
            return .string(try Units.format(number, unit: unit, display: display, locale: locale, number: format))
        case "percent":
            var format = FloatingPointFormatStyle<Double>.Percent(locale: locale)
            format = format.grouping(grouping ? .automatic : .never).sign(strategy: signStrategy(sign))
            format = apply(digits, to: format).rounded(rule: .toNearestOrAwayFromZero)
            return .string(format.format(number))
        case "currency":
            guard let code = options.string("currency") else { throw FormatFailure("currency code is required") }
            var format = FloatingPointFormatStyle<Double>.Currency(code: code.uppercased(), locale: locale)
            let display = try options.choice("currencyDisplay", ["symbol", "narrowSymbol", "code", "name"]) ?? "symbol"
            let presentation: CurrencyFormatStyleConfiguration.Presentation =
                switch display {
                case "code": .isoCode
                case "name": .fullName
                case "narrowSymbol": .narrow
                default: .standard
                }
            format = format.presentation(presentation).grouping(grouping ? .automatic : .never)
                .sign(strategy: currencySignStrategy(sign))
            format = apply(digits, to: format).rounded(rule: .toNearestOrAwayFromZero)
            return .string(format.format(number))
        default:
            var format = FloatingPointFormatStyle<Double>(locale: locale)
            format = format.grouping(grouping ? .automatic : .never).sign(strategy: signStrategy(sign))
            switch notation {
            case "compact": format = format.notation(.compactName)
            case "scientific", "engineering": format = format.notation(.scientific)
            default: break
            }
            format = apply(digits, to: format).rounded(rule: .toNearestOrAwayFromZero)
            return .string(format.format(number))
        }
    }

    // MARK: digits

    private struct Digits {
        var integerMinimum: Int?
        var fraction: ClosedRange<Int>?
        var significant: ClosedRange<Int>?
    }

    /// `minimumFractionDigits` and friends, with `Intl`'s defaults and its rule that an unset bound follows the
    /// other (`min` 4 raises the default `max`; `max` 1 lowers the default `min`).
    private static func digitOptions(_ options: FormatOptions, style: String, currency: String?) throws -> Digits {
        var digits = Digits()
        digits.integerMinimum = try options.int("minimumIntegerDigits")

        let minimumSignificant = try options.int("minimumSignificantDigits")
        let maximumSignificant = try options.int("maximumSignificantDigits")
        if minimumSignificant != nil || maximumSignificant != nil {
            let low = minimumSignificant ?? 1
            let high = maximumSignificant ?? 21
            guard 1...21 ~= low, low <= high, high <= 21 else { throw FormatFailure("invalid significant digits") }
            digits.significant = low...high
            return digits
        }

        let minimum = try options.int("minimumFractionDigits")
        let maximum = try options.int("maximumFractionDigits")
        guard minimum != nil || maximum != nil else { return digits }

        let defaults: (min: Int, max: Int)
        switch style {
        case "percent": defaults = (0, 0)
        case "currency": defaults = (currencyDigits(currency), currencyDigits(currency))
        default: defaults = (0, 3)
        }
        let low = minimum ?? min(defaults.min, maximum ?? defaults.min)
        let high = maximum ?? max(defaults.max, low)
        guard (0...100) ~= low, (0...100) ~= high, low <= high else { throw FormatFailure("invalid fraction digits") }
        digits.fraction = low...high
        return digits
    }

    private static func currencyDigits(_ code: String?) -> Int {
        guard let code else { return 2 }
        let none: Set<String> = [
            "JPY", "KRW", "VND", "CLP", "ISK", "UGX", "XAF", "XOF", "PYG", "RWF", "VUV", "BIF", "DJF", "GNF", "KMF",
            "XPF",
        ]
        let three: Set<String> = ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"]
        if none.contains(code.uppercased()) { return 0 }
        return three.contains(code.uppercased()) ? 3 : 2
    }

    private static func apply(
        _ digits: Digits,
        to format: FloatingPointFormatStyle<Double>
    ) -> FloatingPointFormatStyle<Double> {
        if let significant = digits.significant { return format.precision(.significantDigits(significant)) }
        if let integer = digits.integerMinimum, let fraction = digits.fraction {
            return format.precision(
                .integerAndFractionLength(integerLimits: integer...Int.max, fractionLimits: fraction)
            )
        }
        if let integer = digits.integerMinimum { return format.precision(.integerLength(integer...)) }
        if let fraction = digits.fraction { return format.precision(.fractionLength(fraction)) }
        return format
    }

    private static func apply(
        _ digits: Digits,
        to format: FloatingPointFormatStyle<Double>.Percent
    ) -> FloatingPointFormatStyle<Double>.Percent {
        if let significant = digits.significant { return format.precision(.significantDigits(significant)) }
        if let integer = digits.integerMinimum, let fraction = digits.fraction {
            return format.precision(
                .integerAndFractionLength(integerLimits: integer...Int.max, fractionLimits: fraction)
            )
        }
        if let integer = digits.integerMinimum { return format.precision(.integerLength(integer...)) }
        if let fraction = digits.fraction { return format.precision(.fractionLength(fraction)) }
        return format
    }

    private static func apply(
        _ digits: Digits,
        to format: FloatingPointFormatStyle<Double>.Currency
    ) -> FloatingPointFormatStyle<Double>.Currency {
        if let significant = digits.significant { return format.precision(.significantDigits(significant)) }
        if let integer = digits.integerMinimum, let fraction = digits.fraction {
            return format.precision(
                .integerAndFractionLength(integerLimits: integer...Int.max, fractionLimits: fraction)
            )
        }
        if let integer = digits.integerMinimum { return format.precision(.integerLength(integer...)) }
        if let fraction = digits.fraction { return format.precision(.fractionLength(fraction)) }
        return format
    }

    // MARK: sign

    private static func signStrategy(_ display: String) -> NumberFormatStyleConfiguration.SignDisplayStrategy {
        switch display {
        case "never": .never
        case "always": .always(includingZero: true)
        case "exceptZero": .always(includingZero: false)
        default: .automatic
        }
    }

    private static func currencySignStrategy(_ display: String) -> CurrencyFormatStyleConfiguration.SignDisplayStrategy
    {
        switch display {
        case "never": .never
        case "always": .always(showZero: true)
        case "exceptZero": .always(showZero: false)
        default: .automatic
        }
    }
}
