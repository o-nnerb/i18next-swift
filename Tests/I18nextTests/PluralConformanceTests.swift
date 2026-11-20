// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

/// Checks the generated tables against the samples CLDR publishes next to each rule.
@Suite("CLDR plural conformance")
struct PluralConformanceTests {
    private func verify(_ samples: String, ordinal: Bool) {
        var checked = 0
        var failures: [String] = []

        for line in samples.split(separator: "\n") {
            let fields = line.split(separator: " ")
            guard fields.count == 3 else {
                failures.append("malformed line: \(line)")
                continue
            }
            let (locale, expected, value) = (String(fields[0]), String(fields[1]), String(fields[2]))

            guard let rule = PluralResolver.rule(for: locale, ordinal: ordinal) else {
                failures.append("no rule for \(locale)")
                continue
            }
            guard let operands = PluralOperands(decimal: value) else {
                failures.append("unparsable sample \(value)")
                continue
            }
            checked += 1
            let actual = rule(operands).rawValue
            if actual != expected {
                failures.append("\(locale) \(value): expected \(expected), got \(actual)")
            }
        }

        #expect(checked > 1000)
        #expect(failures.isEmpty, "\(failures.count) mismatches, first: \(failures.prefix(10))")
    }

    @Test func cardinalSamples() { verify(CLDRPluralSamples.cardinal, ordinal: false) }
    @Test func ordinalSamples() { verify(CLDRPluralSamples.ordinal, ordinal: true) }

    @Test func tablesComeFromCLDR49() {
        #expect(CLDRPluralData.version == "49")
        #expect(CLDRPluralData.cardinal.count > 200)
        #expect(CLDRPluralData.ordinal.count > 100)
    }
}

@Suite("Plural operands")
struct PluralOperandsTests {
    @Test func fromDouble() {
        let whole = PluralOperands(3)
        #expect(whole.i == 3 && whole.v == 0 && whole.f == 0 && whole.t == 0 && whole.n == 3)

        let fraction = PluralOperands(-1.25)
        #expect(
            fraction.n == 1.25 && fraction.i == 1 && fraction.v == 2 && fraction.f == 25 && fraction.t == 25
                && fraction.w == 2
        )

        // A Double has no trailing zeros: 1.0 is 1.
        #expect(PluralOperands(1.0).v == 0)
    }

    @Test func fromDecimalKeepsTrailingZeros() throws {
        let operands = try #require(PluralOperands(decimal: "1.50"))
        #expect(operands.i == 1 && operands.v == 2 && operands.f == 50 && operands.t == 5 && operands.w == 1)
        #expect(PluralOperands(decimal: "abc") == nil)
        #expect(PluralOperands(decimal: "1e3") == nil)
    }

    @Test func exponentNotationIsExpanded() {
        let tiny = PluralOperands(0.00001)  // prints as 1e-05
        #expect(tiny.i == 0 && tiny.v == 5 && tiny.f == 1)

        let huge = PluralOperands(1.5e16)
        #expect(huge.i == 15_000_000_000_000_000 && huge.v == 0)

        let mixed = PluralOperands(1.25e-3)
        #expect(mixed.i == 0 && mixed.v == 5 && mixed.f == 125)
    }

    @Test func resolverFallbacks() {
        let resolver = PluralResolver()
        #expect(resolver.category(for: 1, lng: "xx") == .one)  // unknown → English
        #expect(resolver.category(for: 1, lng: "xx", ordinal: true) == .other)
        #expect(resolver.category(for: 1, lng: "pt-BR") == .one)  // → pt
        #expect(resolver.category(for: 1, lng: "pt-PT") == .one)  // exact tag
        #expect(resolver.category(for: 0, lng: "pt-PT") == .other)
        #expect(resolver.category(for: 0, lng: "pt-BR") == .one)
        #expect(resolver.suffix(for: 2, lng: "en", ordinal: true) == "_ordinal_two")
        #expect(PluralResolver(separator: "-").suffix(for: 5, lng: "ru") == "-many")
    }
}
