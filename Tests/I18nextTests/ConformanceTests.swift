// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Runs the scenarios in `ConformanceFixtures` (taken from the i18next test suite, with the answers i18next itself
/// gave) against this port. Regenerate them with `Scripts/conformance/generate.swift`.
struct ConformanceCase: Sendable, CustomTestStringConvertible {
    let id: String
    let source: String
    let kind: String
    let initOptions: JSONValue
    let key: JSONValue
    let options: JSONValue
    let expected: JSONValue

    /// `t` returns a `String` here, where JavaScript returns the number or boolean a resource holds.
    var normalizedExpected: JSONValue {
        guard kind == "t" else { return expected }
        switch expected {
        case .number, .bool: return .string(expected.interpolationString)
        default: return expected
        }
    }

    var testDescription: String {
        "\(id) \(kind) \(key.interpolationString) \(options.interpolationString)"
    }

    static let all: [ConformanceCase] = {
        guard let records = try? JSONValue(json: ConformanceFixtures.json), case .array(let items) = records else {
            return []
        }
        return items.compactMap { record in
            guard case .object(let fields) = record, case .string(let id)? = fields["id"],
                case .string(let source)? = fields["source"], case .string(let kind)? = fields["kind"]
            else { return nil }
            return ConformanceCase(
                id: id,
                source: source,
                kind: kind,
                initOptions: fields["init"] ?? .object([:]),
                key: fields["key"] ?? .null,
                options: fields["options"] ?? .object([:]),
                expected: fields["expected"] ?? .null
            )
        }
    }()
}

/// The scenario uses something this port does not offer (yet). Reported, never silently skipped.
struct Unsupported: Error, CustomStringConvertible {
    let reason: String
    var description: String { "unsupported: \(reason)" }
}

/// Cases where this port deliberately answers differently, with the reason. A case listed here that starts
/// matching fails the run, so entries can't go stale.
private let knownDifferences: [String: String] = [
    "translate/arrayOfKeys#11": "i18next returns undefined for an empty array of keys; here `t` always returns a String"
]

@Suite("i18next conformance")
struct ConformanceTests {
    /// `CONFORMANCE_REPORT=1 swift test --filter report` prints every divergence on one line.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["CONFORMANCE_REPORT"] != nil))
    func report() {
        var lines: [String] = []
        for scenario in ConformanceCase.all where knownDifferences[scenario.id] == nil {
            switch Result(catching: { try ConformanceRunner.run(scenario) }) {
            case .success(let actual) where actual == scenario.normalizedExpected: continue
            case .success(let actual):
                lines.append(
                    "DIFF  \(scenario.id) \(scenario.key.interpolationString) \(scenario.options.interpolationString)\n      i18next: \(scenario.expected.interpolationString)\n      port:    \(actual.interpolationString)"
                )
            case .failure(let error):
                lines.append("SKIP  \(scenario.id) \(error)")
            }
        }
        print("CONFORMANCE: \(lines.count) of \(ConformanceCase.all.count)\n" + lines.joined(separator: "\n"))
    }

    @Test func fixturesAreLoaded() {
        #expect(ConformanceFixtures.i18nextVersion == "27.2.2")
        #expect(ConformanceCase.all.count > 100)
    }

    @Test(arguments: ConformanceCase.all)
    func matchesI18next(_ scenario: ConformanceCase) {
        let outcome = Result { try ConformanceRunner.run(scenario) }

        if let reason = knownDifferences[scenario.id] {
            withKnownIssue(Comment(rawValue: reason)) {
                guard case .success(let actual) = outcome else {
                    Issue.record("\(outcome)")
                    return
                }
                #expect(actual == scenario.normalizedExpected)
            }
            return
        }

        switch outcome {
        case .success(let actual):
            #expect(actual == scenario.normalizedExpected, "\(scenario.source): \(scenario.testDescription)")
        case .failure(let error):
            Issue.record("\(scenario.source): \(scenario.testDescription) — \(error)")
        }
    }
}

// MARK: - Mapping i18next's JSON options onto this port's API

enum ConformanceRunner {
    static func run(_ scenario: ConformanceCase) throws -> JSONValue {
        if scenario.kind == "missing" { return try runMissing(scenario) }
        let i18n = try makeInstance(scenario.initOptions)
        switch scenario.kind {
        case "t":
            let (keys, options) = try translationArguments(scenario)
            if case .object(let fields) = scenario.options, case .bool(true)? = fields["returnDetails"] {
                guard keys.count == 1 else { throw Unsupported(reason: "details with several keys") }
                let details = i18n.details(keys[0], options)
                return .object([
                    "res": details.result, "usedKey": .string(details.usedKey),
                    "exactUsedKey": .string(details.exactUsedKey),
                    "usedLng": details.usedLng.map(JSONValue.string) ?? .null,
                    "usedNS": details.usedNS.map(JSONValue.string) ?? .null, "usedParams": .object(details.usedParams),
                ])
            }
            let initReturnsObjects = scenario.initOptions["returnObjects"] == .bool(true)
            if options.returnObjects == true || initReturnsObjects {
                return i18n.translateValue(keys, options)
            }
            return .string(i18n.t(keys, options))
        case "exists":
            let (keys, options) = try translationArguments(scenario)
            guard let key = keys.first, keys.count == 1 else { throw Unsupported(reason: "exists with several keys") }
            return .bool(i18n.exists(key, options))
        case "resolveHierarchy":
            guard case .string(let code) = scenario.key else { throw Unsupported(reason: "non-string key") }
            var fallback: FallbackLanguages?
            if case .object(let fields) = scenario.options, let value = fields["fallbackLng"] {
                fallback = try Self.fallback(value)
            }
            return .array(i18n.languageUtils.hierarchy(for: code, fallback: fallback).map(JSONValue.string))
        case "bestMatch":
            guard case .array(let items) = scenario.key else { throw Unsupported(reason: "bestMatch arguments") }
            let match = i18n.languageUtils.bestMatch(from: try items.map(string))
            return match.map(JSONValue.string) ?? .null
        case "formatCode":
            guard case .string(let code) = scenario.key else { throw Unsupported(reason: "non-string key") }
            return .string(i18n.languageUtils.format(code))
        case "languagePart":
            guard case .string(let code) = scenario.key else { throw Unsupported(reason: "non-string key") }
            return .string(i18n.languageUtils.languagePart(code))
        case "pluralSuffix":
            guard case .string(let language) = scenario.key, case .object(let fields) = scenario.options,
                case .number(let count)? = fields["count"]
            else { throw Unsupported(reason: "pluralSuffix arguments") }
            var ordinal = false
            if case .bool(true)? = fields["ordinal"] { ordinal = true }
            return .string(i18n.plurals.suffix(for: count, lng: language, ordinal: ordinal))
        case "getResource":
            guard case .array(let parts) = scenario.key, parts.count == 3, case .string(let lng) = parts[0],
                case .string(let ns) = parts[1], case .string(let key) = parts[2]
            else { throw Unsupported(reason: "getResource arguments") }
            var keySeparator: SeparatorSetting?
            var ignore: Bool?
            if case .object(let fields) = scenario.options {
                if let value = fields["keySeparator"] {
                    keySeparator = (try separator(value)).map { .custom($0) } ?? .disabled
                }
                if case .bool(let flag)? = fields["ignoreJSONStructure"] { ignore = flag }
            }
            return i18n.store.getResource(
                lng: lng,
                ns: ns,
                key: key,
                keySeparator: keySeparator,
                ignoreJSONStructure: ignore
            ) ?? .null
        default:
            throw Unsupported(reason: "kind \(scenario.kind)")
        }
    }

    /// Runs `t` and records every key the `missingKeyHandler` receives.
    private static func runMissing(_ scenario: ConformanceCase) throws -> JSONValue {
        let recorder = Protected<[JSONValue]>([])
        let i18n = try makeInstance(scenario.initOptions) { options in
            options.missingKeyHandler = { missing in
                recorder.withLock {
                    $0.append(
                        .object([
                            "languages": .array(missing.languages.map(JSONValue.string)),
                            "namespace": .string(missing.namespace), "key": .string(missing.key),
                            "fallbackValue": missing.fallbackValue.map(JSONValue.string) ?? .null,
                            "isUpdate": .bool(missing.isUpdate),
                        ])
                    )
                }
            }
        }
        let (keys, options) = try translationArguments(scenario)
        let result = i18n.t(keys, options)
        return .object(["result": .string(result), "calls": .array(recorder.withLock { $0 })])
    }

    private static func translationArguments(_ scenario: ConformanceCase) throws -> ([String], TranslationOptions) {
        let keys: [String]
        switch scenario.key {
        case .string(let key): keys = [key]
        case .array(let items): keys = try items.map(string)
        default: throw Unsupported(reason: "non-string key")
        }
        return (keys, try translationOptions(scenario.options))
    }

    // MARK: init options

    static func makeInstance(_ init: JSONValue, configure: (inout I18next.Options) -> Void = { _ in }) throws -> I18next
    {
        guard case .object(let fields) = `init` else { throw Unsupported(reason: "init is not an object") }
        var options = I18next.Options()

        for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
            switch name {
            case "initAsync", "debug":
                continue
            case "lng":
                options.lng = value.stringValue
            case "fallbackLng":
                options.fallbackLng = try fallback(value)
            case "ns":
                options.ns = try strings(value)
            case "defaultNS":
                options.defaultNS = try strings(value)
            case "fallbackNS":
                options.fallbackNS = try strings(value)
            case "resources":
                options.resources = try resources(value)
            case "keySeparator":
                options.keySeparator = try separator(value)
            case "nsSeparator":
                options.nsSeparator = try separator(value)
            case "contextSeparator":
                options.contextSeparator = value.stringValue ?? "_"
            case "pluralSeparator":
                options.pluralSeparator = value.stringValue ?? "_"
            case "returnEmptyString":
                if case .bool(let flag) = value { options.returnEmptyString = flag }
            case "returnObjects":
                if case .bool(let flag) = value { options.returnObjects = flag }
            case "joinArrays":
                options.joinArrays = value.stringValue
            case "postProcess":
                options.postProcess = value.stringValue == "" ? [] : try strings(value)
            case "saveMissing":
                if case .bool(let flag) = value { options.saveMissing = flag }
            case "saveMissingPlurals":
                if case .bool(let flag) = value { options.saveMissingPlurals = flag }
            case "updateMissing":
                if case .bool(let flag) = value { options.updateMissing = flag }
            case "appendNamespaceToMissingKey":
                if case .bool(let flag) = value { options.appendNamespaceToMissingKey = flag }
            case "saveMissingTo":
                switch value.stringValue {
                case "current": options.saveMissingTo = .current
                case "all": options.saveMissingTo = .all
                case "fallback": options.saveMissingTo = .fallback
                default: throw Unsupported(reason: "saveMissingTo \(value)")
                }
            case "supportedLngs":
                options.supportedLngs = try strings(value)
            case "nonExplicitSupportedLngs":
                if case .bool(let flag) = value { options.nonExplicitSupportedLngs = flag }
            case "load":
                switch value.stringValue {
                case "languageOnly": options.load = .languageOnly
                case "currentOnly": options.load = .currentOnly
                case "all": options.load = .all
                default: throw Unsupported(reason: "load \(value)")
                }
            case "lowerCaseLng":
                if case .bool(let flag) = value { options.lowerCaseLng = flag }
            case "cleanCode":
                if case .bool(let flag) = value { options.cleanCode = flag }
            case "interpolation":
                try apply(interpolation: value, to: &options.interpolation)
            default:
                throw Unsupported(reason: "init option `\(name)`")
            }
        }
        configure(&options)
        let i18n = I18next(options)
        for (name, processor) in postProcessors { i18n.addPostProcessor(name, processor) }
        return i18n
    }

    /// The post-processors `harness.js` registers on every instance.
    static let postProcessors: [String: I18next.PostProcessor] = [
        "uppercase": { value, _ in value.uppercased() },
        "wrap": { value, _ in "[\(value)]" },
        "bang": { value, _ in value + "!" },
        "keyed": { value, context in value + "@" + context.keys.joined(separator: "|") },
        "noop": { _, _ in nil },
        "times": { value, context in
            let count: Int
            if case .number(let number)? = context.options.variables["times"] { count = Int(number) } else { count = 1 }
            return Array(repeating: value, count: max(count, 1)).joined(separator: "-")
        },
    ]

    private static func apply(interpolation value: JSONValue, to options: inout InterpolationOptions) throws {
        guard case .object(let fields) = value else { return }
        for (name, setting) in fields {
            switch (name, setting) {
            case ("escapeValue", .bool(let flag)): options.escapeValue = flag
            case ("prefix", .string(let text)): options.prefix = text
            case ("suffix", .string(let text)): options.suffix = text
            case ("unescapePrefix", .string(let text)): options.unescapePrefix = text
            case ("unescapeSuffix", .string(let text)): options.unescapeSuffix = text
            case ("maxReplaces", .number(let number)): options.maxReplaces = Int(number)
            case ("skipOnVariables", .bool(let flag)): options.skipOnVariables = flag
            case ("defaultVariables", .object(let variables)): options.defaultVariables = variables
            default: throw Unsupported(reason: "interpolation option `\(name)`")
            }
        }
    }

    private static func resources(_ value: JSONValue) throws -> ResourceStore.Resources {
        guard case .object(let languages) = value else { throw Unsupported(reason: "resources") }
        var result: ResourceStore.Resources = [:]
        for (language, namespaces) in languages {
            guard case .object(let bundles) = namespaces else { throw Unsupported(reason: "resources.\(language)") }
            result[language] = bundles
        }
        return result
    }

    private static func fallback(_ value: JSONValue) throws -> FallbackLanguages {
        switch value {
        case .bool(false), .null: return .none
        case .string(let code): return .list([code])
        case .array(let codes): return .list(try codes.map { try string($0) })
        case .object(let map):
            return .perLanguage(try map.mapValues { try strings($0) })
        default: throw Unsupported(reason: "fallbackLng \(value)")
        }
    }

    private static func separator(_ value: JSONValue) throws -> String? {
        switch value {
        case .bool(false): return nil
        case .string(let text): return text
        default: throw Unsupported(reason: "separator \(value)")
        }
    }

    // MARK: call options

    /// Option names that i18next treats as settings rather than interpolation variables.
    private static let settings: Set<String> = [
        "lng", "lngs", "fallbackLng", "ns", "count", "ordinal", "context", "defaultValue", "replace",
        "interpolation", "keySeparator", "nsSeparator", "returnObjects", "returnDetails", "joinArrays",
        "postProcess", "skipInterpolation", "ignoreJSONStructure", "defaultVariables",
    ]

    static func translationOptions(_ value: JSONValue) throws -> TranslationOptions {
        guard case .object(let fields) = value else { return TranslationOptions() }
        var options = TranslationOptions()

        for (name, setting) in fields.sorted(by: { $0.key < $1.key }) {
            switch name {
            case "lng":
                options.lng = setting.stringValue
            case "lngs":
                options.lngs = try strings(setting)
            case "fallbackLng":
                options.fallbackLng = try fallback(setting)
            case "keySeparator":
                options.keySeparator = try separator(setting).map { .custom($0) } ?? .disabled
            case "nsSeparator":
                options.nsSeparator = try separator(setting).map { .custom($0) } ?? .disabled
            case "ignoreJSONStructure":
                if case .bool(let flag) = setting { options.ignoreJSONStructure = flag }
            case "returnObjects":
                if case .bool(let flag) = setting { options.returnObjects = flag }
            case "joinArrays":
                options.joinArrays = setting.stringValue
                if case .bool(false) = setting { options.joinArraysDisabled = true }
            case "returnDetails":
                continue
            case "skipInterpolation":
                if case .bool(let flag) = setting { options.skipInterpolation = flag }
            case "postProcess":
                // `''` is falsy in i18next, so it falls back to the instance's list; `[]` (truthy) switches them off.
                if setting.stringValue != "" { options.postProcess = try strings(setting) }
            case "ns":
                options.ns = try strings(setting)
            case "count":
                // i18next applies plural rules only to numeric counts; a string count is just a variable.
                if case .number(let number) = setting {
                    options.count = number
                } else {
                    options.variables["count"] = setting
                }
            case "ordinal":
                if case .bool(let flag) = setting { options.ordinal = flag }
            case "context":
                options.context = setting.interpolationString
            case "defaultValue":
                options.defaultValue = setting.stringValue
            case "replace":
                guard case .object(let replacements) = setting else { throw Unsupported(reason: "replace") }
                for (variable, replacement) in replacements { options.variables[variable] = replacement }
            case "interpolation":
                guard case .object(let nested) = setting else { continue }
                for (key, flag) in nested {
                    guard key == "escapeValue", case .bool(let escape) = flag else {
                        throw Unsupported(reason: "call interpolation option `\(key)`")
                    }
                    options.escapeValue = escape
                }
            default:
                if name.hasPrefix("defaultValue_"), case .string(let text) = setting {
                    let form = String(name.dropFirst("defaultValue_".count))
                    if form.hasPrefix("ordinal_"), let category = PluralCategory(rawValue: String(form.dropFirst(8))) {
                        options.ordinalDefaultValues[category] = text
                    } else if let category = PluralCategory(rawValue: form) {
                        options.defaultValues[category] = text
                    } else {
                        throw Unsupported(reason: "option `\(name)`")
                    }
                    continue
                }
                if settings.contains(name) { throw Unsupported(reason: "option `\(name)`") }
                options.variables[name] = setting
            }
        }
        return options
    }

    // MARK: helpers

    private static func string(_ value: JSONValue) throws -> String {
        guard case .string(let text) = value else { throw Unsupported(reason: "expected a string, got \(value)") }
        return text
    }

    private static func strings(_ value: JSONValue) throws -> [String] {
        switch value {
        case .string(let text): return [text]
        case .array(let items): return try items.map(string)
        default: throw Unsupported(reason: "expected a string or an array of strings, got \(value)")
        }
    }
}
