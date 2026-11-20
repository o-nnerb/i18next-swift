// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import I18next
import Testing

@testable import I18nextFormatters

private func makeI18n(
    lng: String = "en-US",
    _ templates: [String: String]
) -> I18next {
    I18next { options in
        options.lng = lng
        let bundle: [String: JSONValue] = templates.mapValues { JSONValue.string($0) }
        options.resources = [lng: ["translation": .object(bundle)]]
        options.formats = BuiltInFormats.all
    }
}

@Suite("Built-in formatters")
struct BuiltInFormatsTests {
    @Test func numbersFollowTheLanguageAndOptions() {
        let en = makeI18n([
            "n": "{{v, number}}", "d": "{{v, number(minimumFractionDigits: 2)}}", "p": "{{v, number(style: percent)}}",
        ])
        #expect(en.t("n", .init(variables: ["v": 1234567.891])) == "1,234,567.891")
        #expect(en.t("d", .init(variables: ["v": 5])) == "5.00")
        #expect(en.t("p", .init(variables: ["v": 0.256])) == "26%")

        let de = makeI18n(lng: "de-DE", ["n": "{{v, number}}"])
        #expect(de.t("n", .init(variables: ["v": 1234567.891])) == "1.234.567,891")
    }

    @Test func roundingIsHalfAwayFromZeroLikeIntl() {
        let i18n = makeI18n(["n": "{{v, number(maximumFractionDigits: 0)}}"])
        #expect(i18n.t("n", .init(variables: ["v": 2.5])) == "3")
        #expect(i18n.t("n", .init(variables: ["v": -2.5])) == "-3")
        #expect(i18n.t("n", .init(variables: ["v": 3.5])) == "4")
    }

    @Test func currencyTakesItsCodeFromTheTemplateTheCallOrFormatParams() {
        let i18n = makeI18n([
            "t": "{{v, currency(EUR)}}", "c": "{{v, currency}}", "f": "{{amount, currency}}",
        ])
        #expect(i18n.t("t", .init(variables: ["v": 1234.5])) == "€1,234.50")
        #expect(i18n.t("c", .init(variables: ["v": 1234.5, "currency": "USD"])) == "$1,234.50")
        let params: JSONValue = ["amount": ["currency": "EUR", "locale": "de-DE"]]
        #expect(i18n.t("f", .init(variables: ["amount": 1234.5, "formatParams": params])) == "1.234,50\u{00A0}€")
    }

    @Test func datesUseTheTimeZoneGiven() {
        let i18n = makeI18n(["d": "{{when, datetime(dateStyle: long; timeZone: UTC)}}"])
        #expect(i18n.t("d", .init(variables: ["when": 1_700_000_000_000])) == "November 14, 2023")
        #expect(i18n.t("d", .init(variables: ["when": "2023-11-14T22:13:20Z"])) == "November 14, 2023")  // ISO text
    }

    @Test func relativeTimes() {
        let i18n = makeI18n(["r": "{{n, relativetime(day)}}", "a": "{{n, relativetime(range: day; numeric: auto)}}"])
        #expect(i18n.t("r", .init(variables: ["n": -3])) == "3 days ago")
        #expect(i18n.t("r", .init(variables: ["n": 1])) == "in 1 day")
        #expect(i18n.t("a", .init(variables: ["n": 1])) == "tomorrow")
    }

    @Test func lists() {
        let i18n = makeI18n(["l": "{{items, list}}", "o": "{{items, list(type: disjunction)}}"])
        let items: JSONValue = ["a", "b", "c"]
        #expect(i18n.t("l", .init(variables: ["items": items])) == "a, b, and c")
        #expect(i18n.t("o", .init(variables: ["items": items])) == "a, b, or c")
    }

    @Test func valuesAFormatterRefusesAreLeftAsTheyAre() {
        let i18n = makeI18n([
            "q": "{{n, relativetime(quarter)}}", "l": "{{items, list}}", "x": "{{v, number(style: weird)}}",
        ])
        #expect(i18n.t("q", .init(variables: ["n": 2])) == "2")  // no quarter unit in Foundation
        #expect(i18n.t("l", .init(variables: ["items": [1, 2]])) == "1,2")  // Intl.ListFormat wants strings
        #expect(i18n.t("x", .init(variables: ["v": 7])) == "7")  // an invalid option is a RangeError
    }

    @Test func formatNamesAreCaseInsensitiveAndNullIsNotFormatted() {
        let i18n = makeI18n(["a": "{{ v , NUMBER }}", "b": "{{v, number}}"])
        #expect(i18n.t("a", .init(variables: ["v": 1000])) == "1,000")
        #expect(i18n.t("b", .init(variables: ["v": nil])) == "")
    }

    @Test func addBuiltInFormatsRegistersThemOnAnInstance() {
        let i18n = I18next { options in
            options.lng = "en-US"
            options.resources = ["en-US": ["translation": ["n": "{{v, number}}"]]]
        }
        #expect(i18n.t("n", .init(variables: ["v": 1000])) == "1000")  // no formatters yet
        i18n.addBuiltInFormats()
        #expect(i18n.t("n", .init(variables: ["v": 1000])) == "1,000")
    }
}
