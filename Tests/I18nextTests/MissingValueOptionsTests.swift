// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

private func makeI18n(configure: (inout I18next.Options) -> Void = { _ in }) -> I18next {
    I18next { options in
        options.lng = "en"
        options.resources = [
            "en": [
                "translation": [
                    "greeting": "Hello {{name}}",
                    "plain": "plain",
                    "nothing": .null,
                    "steps": ["one", "two"],
                    "group": ["title": "Title"],
                ]
            ]
        ]
        configure(&options)
    }
}

@Suite("Missing interpolation handler")
struct MissingInterpolationHandlerTests {
    @Test func describesThePlaceholder() {
        let seen = Protected<[I18next.MissingInterpolation]>([])
        let i18n = makeI18n { options in
            options.missingInterpolationHandler = { missing in
                seen.withLock { $0.append(missing) }
                return "?"
            }
        }
        #expect(i18n.t("greeting", .init(variables: ["other": 1])) == "Hello ?")

        let missing = seen.withLock { $0 }
        #expect(missing.count == 1)
        #expect(missing[0].placeholder == "{{name}}")
        #expect(missing[0].expression == "name")
        #expect(missing[0].text == "Hello {{name}}")
        #expect(missing[0].options.variables["other"] == 1)
    }

    @Test func theAnswerIsEscapedAndNilMeansEmpty() {
        let i18n = makeI18n { options in
            options.missingInterpolationHandler = { $0.expression == "name" ? "<b>" : nil }
        }
        #expect(i18n.t("greeting") == "Hello &lt;b&gt;")
        #expect(i18n.t("greeting", .init(escapeValue: false)) == "Hello <b>")
        #expect(i18n.t("greeting", .init(missingInterpolationHandler: { _ in nil })) == "Hello ")
    }

    @Test func aProvidedVariableNeverReachesIt() {
        let i18n = makeI18n { options in
            options.missingInterpolationHandler = { _ in
                Issue.record("asked for a variable that was given")
                return nil
            }
        }
        #expect(i18n.t("greeting", .init(variables: ["name": "Ana"])) == "Hello Ana")
    }
}

@Suite("Raw values")
struct RawValueTests {
    @Test func onlyStringsAreEscapedWhenRawValuesAreOn() {
        let escaped = makeI18n()
        let raw = makeI18n { $0.interpolation.useRawValueToEscape = true }
        let list: JSONValue = ["<a>", "&"]

        #expect(escaped.t("greeting", .init(variables: ["name": list])) == "Hello &lt;a&gt;,&amp;")
        #expect(raw.t("greeting", .init(variables: ["name": list])) == "Hello <a>,&")
        #expect(raw.t("greeting", .init(variables: ["name": "<b>"])) == "Hello &lt;b&gt;")
        #expect(raw.t("greeting", .init(variables: ["name": 5])) == "Hello 5")
    }
}

@Suite("Null values and returned objects")
struct ReturnedValueTests {
    @Test func nullCountsAsMissingByDefault() {
        let i18n = makeI18n()
        #expect(i18n.t("nothing", .init(defaultValue: "fallback")) == "fallback")
        #expect(i18n.object("nothing") == "nothing")
        // i18next's `exists` is true for anything that was found.
        #expect(i18n.exists("nothing"))
    }

    @Test func returnNullKeepsIt() {
        let i18n = makeI18n { $0.returnNull = true }
        #expect(i18n.object("nothing") == nil)
        #expect(i18n.t("nothing") == "")
        #expect(i18n.t("nothing", .init(defaultValue: "fallback")) == "")
        #expect(i18n.t("plain") == "plain")
    }

    @Test func returnedObjectHandlerTakesOverForObjectsAndArrays() {
        let seen = Protected<[String]>([])
        let i18n = makeI18n { options in
            options.returnedObjectHandler = { key, value, call in
                seen.withLock { $0.append("\(key)|\(call.ns ?? [])") }
                if case .array(let items) = value { return items.first ?? .null }
                return value["title"] ?? .null
            }
        }
        #expect(i18n.t("group") == "Title")
        #expect(i18n.t("steps") == "one")
        #expect(i18n.t("plain") == "plain")
        // `returnObjects` and `joinArrays` bypass it.
        #expect(i18n.object("group") == ["title": "Title"])
        #expect(i18n.t("steps", .init(joinArrays: "+")) == "one+two")
        #expect(seen.withLock { $0 } == ["group|[\"translation\"]", "steps|[\"translation\"]"])
    }
}

@Suite("Reporting keys without a value")
struct NoValueFallbackTests {
    private func reported(
        instance: Bool = false,
        call: Bool? = nil,
        defaultValue: String? = nil
    ) -> [String?] {
        let values = Protected<[String?]>([])
        let i18n = makeI18n { options in
            options.saveMissing = true
            options.missingKeyNoValueFallbackToKey = instance
            options.missingKeyHandler = { missing in values.withLock { $0.append(missing.fallbackValue) } }
        }
        _ = i18n.t("absent", .init(defaultValue: defaultValue, missingKeyNoValueFallbackToKey: call))
        return values.withLock { $0 }
    }

    @Test func theKeyIsTheValueByDefault() {
        #expect(reported() == ["absent"])
    }

    @Test func noValueIsReportedWhenSwitchedOn() {
        #expect(reported(instance: true) == [nil])
        #expect(reported(call: true) == [nil])
        #expect(reported(instance: true, defaultValue: "dv") == ["dv"])
    }

    @Test func aCallCannotSwitchItOff() {
        #expect(reported(instance: true, call: false) == [nil])
    }
}
