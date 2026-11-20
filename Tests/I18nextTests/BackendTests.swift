// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Backend that records every read and can delay or fail them.
private actor ScriptedBackend: Backend {
    struct Transient: RetryableBackendError {}
    struct Fatal: Error {}

    private let resources: ResourceStore.Resources
    private let delays: [String: UInt64]
    private var transientFailuresLeft: [String: Int]
    private(set) var reads: [String] = []
    private var running = 0
    private(set) var peakConcurrency = 0

    init(
        _ resources: ResourceStore.Resources,
        delays: [String: UInt64] = [:],
        transientFailures: [String: Int] = [:]
    ) {
        self.resources = resources
        self.delays = delays
        self.transientFailuresLeft = transientFailures
    }

    func read(language: String, namespace: String) async throws -> JSONValue {
        let key = "\(language)/\(namespace)"
        reads.append(key)
        running += 1
        peakConcurrency = max(peakConcurrency, running)
        defer { running -= 1 }

        if let delay = delays[language] ?? delays[key] {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
        }
        if let left = transientFailuresLeft[key], left > 0 {
            transientFailuresLeft[key] = left - 1
            throw Transient()
        }
        guard let bundle = resources[language]?[namespace] else {
            throw BackendError.notFound(language: language, namespace: namespace)
        }
        return bundle
    }

    func readCount(of key: String) -> Int { reads.filter { $0 == key }.count }
}

private let sample: ResourceStore.Resources = [
    "en": ["translation": ["hello": "Hello", "only_en": "English"], "common": ["ok": "OK"]],
    "pt": ["translation": ["hello": "Olá"], "common": ["ok": "Certo"]],
    "fr": ["translation": ["hello": "Bonjour"]],
]

private func makeI18n(
    backend: any Backend,
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

@Suite("Backend loading")
struct BackendLoadingTests {
    @Test func initializeLoadsLanguageFallbacksAndNamespaces() async {
        let i18n = makeI18n(backend: InMemoryBackend(sample), lng: "pt-BR") { $0.ns = ["translation", "common"] }
        #expect(i18n.t("hello") == "hello")  // nothing loaded yet

        let report = await i18n.initialize()

        #expect(i18n.t("hello") == "Olá")
        #expect(i18n.t("only_en") == "English")  // fallbackLng
        #expect(i18n.t("common:ok") == "Certo")
        #expect(report.loaded.map(\.description) == ["en/common", "en/translation", "pt/common", "pt/translation"])
        // pt-BR has no files: reported once, and never fatal.
        #expect(report.failures.map(\.key.description) == ["pt-BR/common", "pt-BR/translation"])
    }

    @Test func failedBundlesAreNotRequestedAgain() async {
        let backend = ScriptedBackend(sample)
        let i18n = makeI18n(backend: backend, lng: "pt-BR")

        await i18n.initialize()
        let second = await i18n.initialize()

        #expect(await backend.readCount(of: "pt-BR/translation") == 1)
        #expect(await backend.readCount(of: "pt/translation") == 1)
        #expect(second.loaded.isEmpty && second.failures.isEmpty)
    }

    @Test func concurrentLoadsShareOneRead() async {
        let backend = ScriptedBackend(sample, delays: ["en": 30])
        let i18n = makeI18n(backend: backend)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 { group.addTask { await i18n.initialize() } }
        }

        #expect(await backend.readCount(of: "en/translation") == 1)
        #expect(i18n.t("hello") == "Hello")
    }

    @Test func transientErrorsAreRetried() async {
        let backend = ScriptedBackend(sample, transientFailures: ["en/translation": 2])
        let i18n = makeI18n(backend: backend)

        let report = await i18n.initialize()

        #expect(report.isComplete)
        #expect(await backend.readCount(of: "en/translation") == 3)
        #expect(i18n.t("hello") == "Hello")
    }

    @Test func retriesStopAtMaxRetries() async {
        let backend = ScriptedBackend(sample, transientFailures: ["en/translation": 100])
        let i18n = makeI18n(backend: backend) { $0.backendOptions.maxRetries = 2 }

        let report = await i18n.initialize()

        #expect(report.failures.count == 1)
        #expect(await backend.readCount(of: "en/translation") == 3)  // first try + 2 retries
        #expect(i18n.t("hello") == "hello")
    }

    @Test func nonRetryableErrorsFailImmediately() async {
        let backend = ScriptedBackend([:])  // everything is `notFound`
        let report = await makeI18n(backend: backend).initialize()
        #expect(report.failures.count == 1)
        #expect(await backend.readCount(of: "en/translation") == 1)
    }

    @Test func readsAreCappedByMaxParallelReads() async {
        let langs = (0..<8).map { "l\($0)" }
        let resources = Dictionary(
            uniqueKeysWithValues: langs.map { ($0, ["translation": JSONValue.object(["k": "v"])]) }
        )
        let backend = ScriptedBackend(resources, delays: Dictionary(uniqueKeysWithValues: langs.map { ($0, 20) }))
        let i18n = makeI18n(backend: backend, lng: nil) {
            $0.backendOptions.maxParallelReads = 2
            $0.fallbackLng = .none
        }

        await i18n.loadLanguages(langs)

        #expect(await backend.peakConcurrency == 2)
        #expect(i18n.store.languages.count == 8)
    }

    @Test func loadNamespacesAddsToLaterLanguageChanges() async {
        let i18n = makeI18n(backend: InMemoryBackend(sample))
        await i18n.initialize()
        #expect(i18n.t("common:ok") == "ok")  // namespace not loaded yet: the key comes back

        await i18n.loadNamespaces(["common"])
        #expect(i18n.t("common:ok") == "OK")

        await i18n.changeLanguage("pt")
        #expect(i18n.t("common:ok") == "Certo")  // `common` follows the new language
    }

    @Test func reloadReplacesBundles() async {
        let backend = ScriptedBackend(sample)
        let i18n = makeI18n(backend: backend)
        await i18n.initialize()

        i18n.addResourceBundle(lng: "en", ns: "translation", resources: ["stale": "x"])
        #expect(i18n.t("stale") == "x")

        await i18n.reloadResources()
        #expect(i18n.t("stale") == "stale")
        #expect(i18n.t("hello") == "Hello")
        #expect(await backend.readCount(of: "en/translation") == 2)
    }

    @Test func bundledResourcesDisableBackendUnlessPartial() async {
        let backend = ScriptedBackend(sample)
        let bundled: ResourceStore.Resources = ["en": ["translation": ["own": "Bundled"]]]

        let strict = makeI18n(backend: backend) { $0.resources = bundled }
        await strict.initialize()
        #expect(await backend.reads.isEmpty)
        #expect(strict.t("hello") == "hello")

        let partial = makeI18n(backend: backend) {
            $0.resources = bundled
            $0.partialBundledLanguages = true
        }
        await partial.initialize()
        #expect(await backend.reads.isEmpty)  // `en/translation` is already bundled
        let other = makeI18n(backend: backend, lng: "pt") {
            $0.resources = bundled
            $0.partialBundledLanguages = true
        }
        await other.initialize()
        #expect(other.t("hello") == "Olá")
        #expect(other.t("own", .init(lng: "en")) == "Bundled")
    }

    @Test func noBackendIsHarmless() async {
        let i18n = I18next { $0.lng = "en" }
        let report = await i18n.initialize()
        #expect(report.isComplete && report.loaded.isEmpty)
        await i18n.changeLanguage("pt")
        #expect(i18n.language == "pt")
    }

    @Test func languageIsAppliedOnlyAfterLoading() async {
        let backend = ScriptedBackend(sample, delays: ["pt": 60])
        let i18n = makeI18n(backend: backend)
        await i18n.initialize()

        let change = Task { await i18n.changeLanguage("pt") }
        try? await Task.sleep(nanoseconds: 15_000_000)
        #expect(i18n.language == "en")  // still loading
        _ = await change.value
        #expect(i18n.language == "pt")
    }

    @Test func latestRequestedLanguageWins() async {
        let backend = ScriptedBackend(sample, delays: ["pt": 80])
        let i18n = makeI18n(backend: backend)

        let slow = Task { await i18n.changeLanguage("pt") }
        try? await Task.sleep(nanoseconds: 10_000_000)
        await i18n.changeLanguage("fr")  // finishes first
        _ = await slow.value

        #expect(i18n.language == "fr")
        #expect(i18n.t("hello") == "Bonjour")
    }

    @Test func cancelledChangeDoesNotSwitchLanguage() async {
        let backend = ScriptedBackend(sample, delays: ["pt": 50])
        let i18n = makeI18n(backend: backend)
        await i18n.initialize()

        let change = Task { await i18n.changeLanguage("pt") }
        try? await Task.sleep(nanoseconds: 10_000_000)
        change.cancel()
        _ = await change.value

        #expect(i18n.language == "en")
        #expect(i18n.store.hasResourceBundle(lng: "pt", ns: "translation"))  // the shared read still completed
    }

    @Test func loadStrategies() {
        func hierarchy(_ code: String, _ load: LoadStrategy) -> [String] {
            LanguageUtils(fallbackLng: ["en"], load: load).hierarchy(for: code)
        }
        #expect(hierarchy("pt-BR", .all) == ["pt-BR", "pt", "en"])
        #expect(hierarchy("pt-BR", .currentOnly) == ["pt-BR", "en"])
        #expect(hierarchy("pt-BR", .languageOnly) == ["pt", "en"])
        #expect(hierarchy("pt", .languageOnly) == ["pt", "en"])
    }
}

@Suite("FileSystemBackend")
struct FileSystemBackendTests {
    private func makeDirectory() throws -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("i18next-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url.appendingPathComponent("pt"), withIntermediateDirectories: true)
        try Data(#"{"hello":"Olá","nested":{"a":"b"}}"#.utf8).write(
            to: url.appendingPathComponent("pt/translation.json")
        )
        return url.path
    }

    @Test func readsJSONFiles() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let i18n = I18next { options in
            options.lng = "pt"
            options.backend = FileSystemBackend(directory: directory)
            options.fallbackLng = .none
        }
        let report = await i18n.initialize()

        #expect(report.isComplete)
        #expect(i18n.t("hello") == "Olá")
        #expect(i18n.t("nested.a") == "b")
    }

    @Test func missingFileIsNotFound() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(atPath: directory) }

        let backend = FileSystemBackend(directory: directory)
        await #expect(throws: BackendError.notFound(language: "xx", namespace: "translation")) {
            try await backend.read(language: "xx", namespace: "translation")
        }
    }

    @Test func rejectsPathTraversal() async throws {
        let backend = FileSystemBackend(directory: "/tmp")
        for (language, namespace) in [("../etc", "passwd"), ("en", "../../x"), ("a/b", "c"), ("", "c")] {
            await #expect(throws: BackendError.self) {
                try await backend.read(language: language, namespace: namespace)
            }
        }
    }
}
