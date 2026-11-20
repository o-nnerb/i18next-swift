// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Foundation
import I18next
import Testing

@testable import I18nextFormatters

// The expected values are what i18next answers with Apple's ICU (through JavaScriptCore). Other platforms ship another
// ICU, whose CLDR release can word things differently, so this suite only runs on Apple platforms.
#if canImport(Darwin)

/// A scenario from `FormatterFixtures`: a template read with `t`, and what i18next itself answers.
struct FormatterCase: Sendable, CustomTestStringConvertible {
    let id: String
    let language: String
    let key: String
    let template: String
    let variables: [String: JSONValue]
    let expected: String

    var testDescription: String {
        "\(id) \(template) \(variables.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.interpolationString)" }.joined(separator: " "))"
    }

    static let all: [FormatterCase] = {
        guard let records = try? JSONValue(json: FormatterFixtures.json), case .array(let items) = records else {
            return []
        }
        return items.compactMap { record in
            guard case .object(let fields) = record, case .string(let id)? = fields["id"],
                case .string(let key)? = fields["key"], case .object(let initial)? = fields["init"],
                case .string(let language)? = initial["lng"], case .object(let resources)? = initial["resources"],
                case .object(let languageResources)? = resources[language],
                case .object(let namespaces)? = languageResources["translation"],
                case .string(let template)? = namespaces[key], case .string(let expected)? = fields["expected"]
            else { return nil }
            var variables: [String: JSONValue] = [:]
            if case .object(let options)? = fields["options"] { variables = options }
            return FormatterCase(
                id: id,
                language: language,
                key: key,
                template: template,
                variables: variables,
                expected: expected
            )
        }
    }()

    /// Newer ICU releases put a narrow no-break space before `PM`, older ones a plain space; that is data, not logic.
    static func normalized(_ text: String) -> String {
        String(text.map { $0 == "\u{202F}" || $0 == "\u{00A0}" ? " " : $0 })
    }

    func run() -> String {
        let i18n = I18next { options in
            options.lng = language
            options.resources = [language: ["translation": [key: .string(template)]]]
            options.formats = BuiltInFormats.all
            options.interpolation.escapeValue = false  // i18next escapes too; the fixtures were made with it on
        }
        return i18n.t(key, .init(variables: variables, escapeValue: true))
    }
}

/// Where Foundation can't do what `Intl` does. A case that is listed and starts matching fails the run, so the
/// rules can't go stale.
private func knownDifference(for scenario: FormatterCase) -> String? {
    let template = scenario.template
    if template.contains("relativetime") {
        if template.contains("quarter") {
            return "RelativeDateTimeFormatter has no quarter unit; the value is left as written"
        }
        if scenario.variables["n"] == 2.5 {
            return "RelativeDateTimeFormatter takes whole numbers; Intl prints \"in 2.5 days\""
        }
    }
    if template.contains("list(type: unit)") {
        return "ListFormatStyle has no `unit` list type"
    }
    if template.contains("timeZoneName") {
        return "Foundation names UTC \"GMT\" where Intl says \"UTC\" (time zone display names differ)"
    }
    return nil
}

@Suite("Built-in formatters vs i18next")
struct FormatterConformanceTests {
    /// `CONFORMANCE_REPORT=1 swift test --filter FormatterConformanceTests/report` prints every divergence.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CONFORMANCE_REPORT"] != nil))
    func report() {
        var lines: [String] = []
        for scenario in FormatterCase.all where knownDifference(for: scenario) == nil {
            let actual = scenario.run()
            if FormatterCase.normalized(actual) != FormatterCase.normalized(scenario.expected) {
                lines.append(
                    "DIFF  \(scenario.id)  \(scenario.template)  \(scenario.variables.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value.interpolationString)" }.joined(separator: " "))\n      i18next: \(scenario.expected)\n      port:    \(actual)"
                )
            }
        }
        print("FORMATTERS: \(lines.count) of \(FormatterCase.all.count)\n" + lines.joined(separator: "\n"))
    }

    @Test func fixturesAreLoaded() {
        #expect(FormatterFixtures.i18nextVersion == "27.2.2")
        #expect(FormatterCase.all.count > 1000)
    }

    @Test(arguments: FormatterCase.all)
    func matchesI18next(_ scenario: FormatterCase) {
        let actual = FormatterCase.normalized(scenario.run())
        let expected = FormatterCase.normalized(scenario.expected)
        if let reason = knownDifference(for: scenario) {
            withKnownIssue(Comment(rawValue: reason), isIntermittent: true) { #expect(actual == expected) }
        } else {
            #expect(actual == expected, "\(scenario.testDescription)")
        }
    }
}

#endif
