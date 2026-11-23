// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Serves `resources`, takes `delay` milliseconds per read, and records what it is asked to create.
private actor RecordingBackend: Backend {
    private let resources: ResourceStore.Resources
    private let delay: UInt64
    private(set) var reads: [String] = []
    private(set) var created: [String] = []

    init(_ resources: ResourceStore.Resources, delay: UInt64 = 0) {
        self.resources = resources
        self.delay = delay
    }

    func read(language: String, namespace: String) async throws -> JSONValue {
        reads.append("\(language)/\(namespace)")
        if delay > 0 { try? await Task.sleep(nanoseconds: delay * 1_000_000) }
        guard let bundle = resources[language]?[namespace] else {
            throw BackendError.notFound(language: language, namespace: namespace)
        }
        return bundle
    }

    func create(
        languages: [String],
        namespace: String,
        key: String,
        fallbackValue: String?,
        isUpdate: Bool
    )
        async throws
    {
        created.append("\(namespace):\(key)")
    }
}

private let resources: ResourceStore.Resources = [
    "en": ["translation": ["hello": "Hello"], "common": ["ok": "OK"], "slow": ["a": "A"]],
    "pt": ["translation": ["hello": "Olá"]],
]

private func makeI18n(
    _ backend: any Backend,
    lng: String? = "en",
    configure: (inout I18next.Options) -> Void = { _ in }
) -> I18next {
    I18next { options in
        options.lng = lng
        options.fallbackLng = ["en"]
        options.backend = backend
        options.backendOptions.retryDelayMilliseconds = 1
        configure(&options)
    }
}

@Suite("Namespace readiness")
struct NamespaceReadinessTests {
    @Test func aBackedInstanceIsNotReadyUntilInitialized() async {
        let i18n = makeI18n(RecordingBackend(resources))
        #expect(!i18n.hasLoadedNamespace("translation"))

        await i18n.initialize()
        #expect(i18n.hasLoadedNamespace("translation"))
    }

    @Test func aNamespaceNeverRequestedIsNotLoaded() async {
        let i18n = makeI18n(RecordingBackend(resources))
        await i18n.initialize()

        #expect(!i18n.hasLoadedNamespace("common"))
        await i18n.loadNamespaces(["common"])
        #expect(i18n.hasLoadedNamespace("common"))
    }

    @Test func aFailedLoadCountsAsFinished() async {
        let i18n = makeI18n(RecordingBackend(resources))
        await i18n.initialize()

        let report = await i18n.loadNamespaces(["nowhere"])
        #expect(!report.isComplete)
        #expect(i18n.hasLoadedNamespace("nowhere"))
    }

    @Test func aRunningLoadIsNotFinished() async {
        let backend = RecordingBackend(resources, delay: 150)
        let i18n = makeI18n(backend)
        await i18n.initialize()

        let loading = Task { await i18n.loadNamespaces(["slow"]) }
        for _ in 0..<200 where await !backend.reads.contains("en/slow") {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(!i18n.hasLoadedNamespace("slow"))

        await loading.value
        #expect(i18n.hasLoadedNamespace("slow"))
    }

    @Test func languageOptionChecksThatLanguageAlone() async {
        let i18n = makeI18n(RecordingBackend(resources), lng: "pt")
        await i18n.initialize()

        #expect(i18n.hasLoadedNamespace("translation", lng: "pt"))
        #expect(i18n.hasLoadedNamespace("translation", lng: "cimode"))
        // `fr` is not requested, so nothing has settled for it.
        #expect(!i18n.hasLoadedNamespace("translation", lng: "fr"))
    }

    @Test func instancesWithoutABackendAreAlwaysReady() {
        let i18n = I18next { options in
            options.lng = "en"
            options.resources = ["en": ["translation": ["a": "b"]]]
        }
        #expect(i18n.hasLoadedNamespace("translation"))
        #expect(i18n.hasLoadedNamespace("never-added"))
    }

    @Test func saveMissingWaitsForTheNamespace() async {
        let backend = RecordingBackend(resources)
        let i18n = makeI18n(backend) { $0.saveMissing = true }
        await i18n.initialize()

        // `common` was never loaded: the key might exist there, so it is not reported.
        _ = i18n.t("not.there", .init(ns: ["common"], defaultValue: "x"))
        _ = i18n.t("also.missing", .init(defaultValue: "y"))
        for _ in 0..<200 where await backend.created.isEmpty { try? await Task.sleep(nanoseconds: 5_000_000) }

        #expect(await backend.created == ["translation:also.missing"])
    }

    @Test func defaultNamespaceCanBeReplaced() {
        let i18n = I18next { options in
            options.lng = "en"
            options.resources = ["en": ["translation": ["ok": "no"], "common": ["ok": "OK"]]]
        }
        #expect(i18n.t("ok") == "no")

        i18n.setDefaultNamespace("common")
        #expect(i18n.defaultNamespaces == ["common"])
        #expect(i18n.t("ok") == "OK")
        #expect(i18n.t("translation:ok") == "no")

        i18n.setDefaultNamespace(["translation", "common"])
        #expect(i18n.t("ok") == "no")
    }
}

@Suite("Resolved language")
struct ResolvedLanguageTests {
    @Test func followsWhatHasBeenLoaded() async {
        let i18n = makeI18n(RecordingBackend(resources), lng: "pt-BR")
        #expect(i18n.resolvedLanguage == nil)

        await i18n.initialize()
        #expect(i18n.language == "pt-BR")
        #expect(i18n.resolvedLanguage == "pt")

        await i18n.changeLanguage("en")
        #expect(i18n.resolvedLanguage == "en")
    }

    @Test func isNotRefreshedByResourcesAddedLater() {
        let i18n = I18next { options in
            options.lng = "de"
            options.fallbackLng = ["en"]
            options.resources = ["en": ["translation": ["a": "b"]]]
        }
        #expect(i18n.resolvedLanguage == "en")

        i18n.addResourceBundle(lng: "de", ns: "translation", resources: ["a": "c"])
        #expect(i18n.resolvedLanguage == "en")
        i18n.setLanguage("de")
        #expect(i18n.resolvedLanguage == "de")
    }

    @Test func dirFollowsTheResolvedLanguage() {
        let i18n = I18next { options in
            options.lng = "ar-EG"
            options.fallbackLng = ["en"]
            options.resources = ["en": ["translation": ["a": "b"]]]
        }
        #expect(i18n.resolvedLanguage == "en")
        #expect(i18n.dir() == .ltr)
        #expect(i18n.dir("ar-EG") == .rtl)
        #expect(I18next().dir() == .ltr)
    }
}

@Suite("Fixed translate functions")
struct FixedTranslateTests {
    @Test func prefixesEveryKeyOfAnArray() {
        let i18n = I18next { options in
            options.lng = "en"
            options.resources = ["en": ["translation": ["screen": ["title": "Title"]]]]
        }
        let t = i18n.getFixedT(keyPrefix: "screen")
        #expect(t("title") == "Title")
        #expect(t(["nope", "title"]) == "Title")
        #expect(t("title", .init(keyPrefix: "")) == "title")
        #expect(i18n.t("title", .init(keyPrefix: "screen")) == "title")
    }
}
