// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

private func makeI18n(lng: String = "en") -> I18next {
    I18next { options in
        options.lng = lng
        options.fallbackLng = ["en"]
        options.resources = [
            "en": [
                "translation": [
                    "hello": "Hello",
                    "nested": ["deep": ["key": "Deep value"]],
                    "greeting": "Hi {{name}}!",
                    "raw": "{{- html}} vs {{html}}",
                    "item_one": "{{count}} item",
                    "item_other": "{{count}} items",
                    "item_zero": "no items",
                    "friend": "A friend",
                    "friend_male": "A boyfriend",
                    "friend_female_one": "A girlfriend",
                    "friend_female_other": "{{count}} girlfriends",
                    "ref": "See $t(hello) and $t(greeting, {\"name\": \"Ann\"})",
                    "cycle": "$t(cycle)",
                    "place": "{{user.address.city}}",
                    "price": "Cost: {{value, double}}",
                    "place_ordinal_one": "{{count}}st",
                    "place_ordinal_two": "{{count}}nd",
                    "place_ordinal_few": "{{count}}rd",
                    "place_ordinal_other": "{{count}}th",
                    "empty": "",
                ],
                "common": ["ok": "OK"],
            ],
            "pt": ["translation": ["hello": "Olá"]],
            "pt-BR": ["translation": ["greeting": "Oi {{name}}!"]],
            "ru": [
                "translation": [
                    "item_one": "{{count}} предмет", "item_few": "{{count}} предмета",
                    "item_many": "{{count}} предметов", "item_other": "{{count}} предмета",
                ]
            ],
        ]
    }
}

@Suite("Lookup")
struct LookupTests {
    @Test func plainAndNestedKeys() {
        let i18n = makeI18n()
        #expect(i18n.t("hello") == "Hello")
        #expect(i18n.t("nested.deep.key") == "Deep value")
    }

    @Test func namespaceInKeyAndOption() {
        let i18n = makeI18n()
        #expect(i18n.t("common:ok") == "OK")
        #expect(i18n.t("ok", .init(ns: ["common"])) == "OK")
    }

    @Test func missingKeyReturnsKeyOrDefault() {
        let i18n = makeI18n()
        #expect(i18n.t("nope") == "nope")
        #expect(i18n.t("nope", .init(defaultValue: "Hi {{name}}", variables: ["name": "Bo"])) == "Hi Bo")
        #expect(i18n.t("nested.deep") == "nested.deep")  // object, not string
    }

    @Test func languageFallbackChain() {
        let i18n = makeI18n(lng: "pt-BR")
        #expect(i18n.t("greeting", .init(variables: ["name": "Léo"])) == "Oi Léo!")  // pt-BR
        #expect(i18n.t("hello") == "Olá")  // pt
        #expect(i18n.t("item", .init(count: 2)) == "2 items")  // fallbackLng en
        #expect(i18n.languages == ["pt-BR", "pt", "en"])
    }

    @Test func perCallLanguageAndFixedT() {
        let i18n = makeI18n()
        #expect(i18n.t("hello", .init(lng: "pt")) == "Olá")
        #expect(i18n.getFixedT(lng: "pt")("hello") == "Olá")
        #expect(i18n.getFixedT(ns: ["common"])("ok") == "OK")
    }

    @Test func setLanguage() {
        let i18n = makeI18n()
        i18n.setLanguage("pt")
        #expect(i18n.t("hello") == "Olá")
    }

    @Test func existsAndEmptyString() {
        let i18n = makeI18n()
        #expect(i18n.exists("hello"))
        #expect(!i18n.exists("nope"))
        #expect(i18n.t("empty") == "")

        let strict = I18next { o in
            o.lng = "en"
            o.returnEmptyString = false
            o.resources = ["en": ["translation": ["empty": ""]]]
        }
        #expect(strict.t("empty") == "empty")
    }
}

@Suite("Plurals and context")
struct PluralTests {
    @Test func englishCardinal() {
        let i18n = makeI18n()
        #expect(i18n.t("item", .init(count: 1)) == "1 item")
        #expect(i18n.t("item", .init(count: 5)) == "5 items")
        #expect(i18n.t("item", .init(count: 0)) == "no items")
        #expect(i18n.t("item", .init(count: 1.5)) == "1.5 items")
    }

    @Test func russianCategories() {
        let ru = PluralResolver()
        #expect(ru.category(for: 1, lng: "ru") == .one)
        #expect(ru.category(for: 21, lng: "ru") == .one)
        #expect(ru.category(for: 3, lng: "ru") == .few)
        #expect(ru.category(for: 5, lng: "ru") == .many)
        #expect(ru.category(for: 11, lng: "ru") == .many)
        #expect(ru.category(for: 1.5, lng: "ru") == .other)

        let i18n = makeI18n(lng: "ru")
        #expect(i18n.t("item", .init(count: 3)) == "3 предмета")
        #expect(i18n.t("item", .init(count: 12)) == "12 предметов")
    }

    @Test func otherLanguages() {
        let r = PluralResolver()
        #expect(r.category(for: 0, lng: "ar") == .zero)
        #expect(r.category(for: 2, lng: "ar") == .two)
        #expect(r.category(for: 11, lng: "ar") == .many)
        #expect(r.category(for: 0, lng: "fr") == .one)
        #expect(r.category(for: 2, lng: "fr") == .other)
        #expect(r.category(for: 1_000_000, lng: "es") == .many)
        #expect(r.category(for: 3, lng: "pl") == .few)
        #expect(r.category(for: 5, lng: "pl") == .many)
        #expect(r.category(for: 100, lng: "ja") == .other)
        #expect(r.category(for: 1, lng: "pt-PT") == .one)
        #expect(r.category(for: 0, lng: "pt-BR") == .one)  // falls back to `pt`
        #expect(r.category(for: 1, lng: "xx") == .one)  // unknown → English rules
    }

    @Test func ordinals() {
        let i18n = makeI18n()
        let cases: [(Double, String)] = [(1, "1st"), (2, "2nd"), (3, "3rd"), (4, "4th"), (11, "11th"), (22, "22nd")]
        for (count, expected) in cases {
            #expect(i18n.t("place", .init(count: count, ordinal: true)) == expected)
        }
    }

    @Test func context() {
        let i18n = makeI18n()
        #expect(i18n.t("friend") == "A friend")
        #expect(i18n.t("friend", .init(context: "male")) == "A boyfriend")
        #expect(i18n.t("friend", .init(context: "unknown")) == "A friend")
        #expect(i18n.t("friend", .init(count: 1, context: "female")) == "A girlfriend")
        #expect(i18n.t("friend", .init(count: 3, context: "female")) == "3 girlfriends")
    }
}

@Suite("Interpolation")
struct InterpolationTests {
    @Test func variablesAreEscapedByDefault() {
        let i18n = makeI18n()
        #expect(i18n.t("greeting", .init(variables: ["name": "<b>Ann</b>"])) == "Hi &lt;b&gt;Ann&lt;&#x2F;b&gt;!")
        #expect(i18n.t("greeting", .init(variables: ["name": "<b>"], escapeValue: false)) == "Hi <b>!")
        #expect(i18n.t("raw", .init(variables: ["html": "<i>"])) == "<i> vs &lt;i&gt;")
    }

    @Test func missingVariableBecomesEmpty() {
        #expect(makeI18n().t("greeting") == "Hi !")
    }

    @Test func nestedVariablePaths() {
        let vars: [String: JSONValue] = ["user": ["address": ["city": "Lisbon"]]]
        #expect(makeI18n().t("place", .init(variables: vars)) == "Lisbon")
    }

    @Test func valuesAreNotReScanned() {
        let out = makeI18n().t("greeting", .init(variables: ["name": "{{x}} $t(hello)"], escapeValue: false))
        #expect(out == "Hi {{x}} $t(hello)!")
    }

    @Test func numbersAndBooleans() {
        let i18n = I18next { $0.resources = ["dev": ["translation": ["k": "{{a}}|{{b}}|{{c}}|{{d}}"]]] }
        let out = i18n.t("k", .init(variables: ["a": 3, "b": 2.5, "c": true, "d": nil]))
        #expect(out == "3|2.5|true|")
    }

    @Test func customFormat() {
        let i18n = makeI18n()
        i18n.addFormat("double") { value, _, args in
            let n = Double(value.interpolationString) ?? 0
            return "\(n * 2)\(args["suffix"] ?? "")"
        }
        #expect(i18n.t("price", .init(variables: ["value": 4])) == "Cost: 8.0")
    }

    @Test func nesting() {
        let i18n = makeI18n()
        #expect(i18n.t("ref") == "See Hello and Hi Ann!")
    }

    @Test func nestingCycleTerminates() {
        #expect(makeI18n().t("cycle") == "")
    }

    @Test func unterminatedTokensAreLeftAlone() {
        let i18n = I18next { $0.resources = ["dev": ["translation": ["a": "x {{oops", "b": "y $t(oops"]]] }
        #expect(i18n.t("a") == "x {{oops")
        #expect(i18n.t("b") == "y $t(oops")
    }
}

@Suite("Resources and languages")
struct ResourceTests {
    @Test func languageFormatting() {
        #expect(LanguageUtils.format("pt-br") == "pt-BR")
        #expect(LanguageUtils.format("zh-hans-cn") == "zh-Hans-CN")
        #expect(LanguageUtils.format("EN") == "EN")
        #expect(LanguageUtils.languagePart("pt-BR") == "pt")
        #expect(LanguageUtils.hierarchy(for: "pt-BR", fallback: ["en", "pt"]) == ["pt-BR", "pt", "en"])
        #expect(
            LanguageUtils.hierarchy(for: "fr", fallback: .perLanguage(["fr": ["en"], "default": ["de"]])) == [
                "fr", "en",
            ]
        )
        #expect(LanguageUtils.hierarchy(for: "es", fallback: .perLanguage(["default": ["de"]])) == ["es", "de"])
        #expect(LanguageUtils.hierarchy(for: nil, fallback: .none).isEmpty)
    }

    @Test func storeMerging() {
        let store = ResourceStore()
        store.addResource(lng: "en", ns: "t", key: "a.b", value: "1")
        store.addResourceBundle(lng: "en", ns: "t", resources: ["a": ["c": "2"], "z": "3"], deep: true)
        #expect(store.getResource(lng: "en", ns: "t", key: "a.b") == "1")
        #expect(store.getResource(lng: "en", ns: "t", key: "a.c") == "2")

        store.addResourceBundle(lng: "en", ns: "t", resources: ["a": ["b": "new"]], deep: true)
        #expect(store.getResource(lng: "en", ns: "t", key: "a.b") == "1")  // no overwrite
        store.addResourceBundle(lng: "en", ns: "t", resources: ["a": ["b": "new"]], deep: true, overwrite: true)
        #expect(store.getResource(lng: "en", ns: "t", key: "a.b") == "new")

        store.removeResourceBundle(lng: "en", ns: "t")
        #expect(!store.hasResourceBundle(lng: "en", ns: "t"))
        #expect(store.languages.isEmpty)
    }

    @Test func flatKeysWinWhenIgnoringJSONStructure() {
        let store = ResourceStore(data: ["en": ["t": ["a.b": "flat", "a": ["b": "nested"]]]])
        #expect(store.getResource(lng: "en", ns: "t", key: "a.b") == "flat")
    }

    @Test func jsonRoundTrip() throws {
        let value = try JSONValue(json: #"{"a":[1,true,null,"x"],"b":{"c":1.5}}"#)
        #expect(value["b"]?["c"] == 1.5)
        #expect(value.value(at: ["a", "3"]) == "x")
        #expect(JSONValue.object(["k": [1, 2]]).interpolationString == #"{"k":[1,2]}"#)
    }
}
