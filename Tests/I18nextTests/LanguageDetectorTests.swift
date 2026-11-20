// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

private actor Remembered {
    private(set) var languages: [String] = []
    func record(_ language: String) { languages.append(language) }
}

private struct FixedDetector: LanguageDetector {
    let codes: [String]
    let remembered = Remembered()

    func detect() async -> [String] { codes }
    func cacheUserLanguage(_ language: String) async { await remembered.record(language) }
}

private let resources: ResourceStore.Resources = [
    "en": ["translation": ["hello": "Hello"]],
    "pt": ["translation": ["hello": "Olá"]],
]

private func makeI18n(
    detector: FixedDetector?,
    lng: String? = nil,
    supported: [String]? = ["en", "pt"],
    nonExplicit: Bool = false
) -> I18next {
    I18next { options in
        options.lng = lng
        options.fallbackLng = ["en"]
        options.resources = resources
        options.supportedLngs = supported
        options.nonExplicitSupportedLngs = nonExplicit
        options.languageDetector = detector
    }
}

@Suite("Language detection")
struct LanguageDetectorTests {
    @Test func initializeUsesTheFirstSupportedCandidate() async {
        let detector = FixedDetector(codes: ["xx", "pt-BR"])
        let i18n = makeI18n(detector: detector)
        #expect(i18n.language == nil)

        await i18n.initialize()

        #expect(i18n.language == "pt")  // `xx` is unsupported, `pt-BR` narrows to its supported language part
        #expect(i18n.t("hello") == "Olá")
        #expect(await detector.remembered.languages == ["pt"])
    }

    @Test func aDirectlySupportedCandidateBeatsANarrowedOne() async {
        let i18n = makeI18n(detector: FixedDetector(codes: ["pt-BR", "en"]))
        await i18n.initialize()
        #expect(i18n.language == "en")  // `en` is supported as is; `pt-BR` would need narrowing to `pt`
    }

    @Test func aConfiguredLanguageIsNotDetected() async {
        let detector = FixedDetector(codes: ["pt"])
        let i18n = makeI18n(detector: detector, lng: "en")

        await i18n.initialize()

        #expect(i18n.language == "en")
        #expect(await detector.remembered.languages.isEmpty)
    }

    @Test func noSupportedCandidateFallsBackToFallbackLng() async {
        let i18n = makeI18n(detector: FixedDetector(codes: ["ja", "ko"]))
        await i18n.initialize()
        #expect(i18n.language == "en")
    }

    @Test func withoutSupportedLngsTheFirstCandidateWins() async {
        let i18n = makeI18n(detector: FixedDetector(codes: ["pt-br", "en"]), supported: nil)
        await i18n.initialize()
        #expect(i18n.language == "pt-BR")
    }

    @Test func nothingDetectedAndNoFallbackLeavesTheLanguageUnset() async {
        let i18n = I18next { options in
            options.resources = resources
            options.languageDetector = FixedDetector(codes: [])
        }
        await i18n.initialize()
        #expect(i18n.language == nil)
    }

    @Test func changeLanguageWithNilDetectsAgain() async {
        let i18n = makeI18n(detector: FixedDetector(codes: ["pt"]), lng: "en")
        await i18n.initialize()
        #expect(i18n.language == "en")

        await i18n.changeLanguage(nil)

        #expect(i18n.language == "pt")
    }

    @Test func nonExplicitSupportedLngsAcceptsRegionalVariants() async {
        let i18n = makeI18n(detector: FixedDetector(codes: ["pt-BR"]), nonExplicit: true)
        await i18n.initialize()
        #expect(i18n.language == "pt-BR")
    }
}

@Suite("System language detector")
struct SystemLanguageDetectorTests {
    @Test func parsesLocaleEnvironmentVariables() {
        func languages(_ environment: [String: String]) -> [String] {
            SystemLanguageDetector.languages(fromEnvironment: environment)
        }
        #expect(languages(["LANG": "pt_BR.UTF-8"]) == ["pt-BR"])
        #expect(languages(["LANGUAGE": "pt_BR:en_US", "LANG": "C"]) == ["pt-BR", "en-US"])
        #expect(languages(["LC_ALL": "de_DE@euro"]) == ["de-DE"])
        #expect(languages(["LANG": "POSIX"]).isEmpty)
        #expect(languages(["LANGUAGE": "fr", "LANG": "fr_FR.UTF-8"]) == ["fr", "fr-FR"])
        #expect(languages([:]).isEmpty)
    }

    @Test func detectReturnsSomethingUsable() async {
        // Whatever the machine is set to, every candidate must be a non-empty tag.
        let codes = await SystemLanguageDetector().detect()
        #expect(codes.allSatisfy { !$0.isEmpty })
    }
}

@Suite("Objects and details")
struct ObjectsAndDetailsTests {
    private func makeI18n() -> I18next {
        I18next { options in
            options.lng = "en"
            options.resources = [
                "en": [
                    "translation": [
                        "list": ["a", "b {{x}}"], "nested": ["k": ["deep": "D"]], "text": "T", "n_one": "one",
                        "n_other": "many",
                    ]
                ]
            ]
        }
    }

    @Test func objectReturnsStructureWithTranslatedLeaves() {
        let i18n = makeI18n()
        #expect(i18n.object("list", .init(variables: ["x": "X"])) == ["a", "b X"])
        #expect(i18n.object("nested") == ["k": ["deep": "D"]])
        #expect(i18n.object("text") == "T")
        #expect(i18n.object("missing") == "missing")
    }

    @Test func tDoesNotReturnObjectsUnlessAsked() {
        let i18n = makeI18n()
        #expect(i18n.t("list") == "list")  // an array counts as missing
        #expect(i18n.t("list", .init(variables: ["x": "X"], joinArrays: "+")) == "a+b X")
    }

    @Test func detailsReportWhereTheResultCameFrom() {
        let details = makeI18n().details("n", .init(count: 2))
        #expect(details.result == "many")
        #expect(details.usedKey == "n")
        #expect(details.exactUsedKey == "n_other")
        #expect(details.usedLng == "en")
        #expect(details.usedNS == "translation")
        #expect(details.usedParams["count"] == 2)
    }
}
