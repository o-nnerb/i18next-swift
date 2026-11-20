// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

private actor CreateRecorder {
    private(set) var calls: [MissingKey] = []
    func record(_ call: MissingKey) { calls.append(call) }
}

private struct RecordingBackend: Backend {
    let resources: ResourceStore.Resources
    let recorder = CreateRecorder()

    func read(language: String, namespace: String) async throws -> JSONValue {
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
    ) async throws {
        await recorder.record(
            MissingKey(
                languages: languages,
                namespace: namespace,
                key: key,
                fallbackValue: fallbackValue,
                isUpdate: isUpdate
            )
        )
    }
}

/// Polls until `condition` holds, for at most about a second.
private func eventually(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<100 {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return false
}

@Suite("Events")
struct EventTests {
    private func collect(
        _ stream: AsyncStream<I18nextEvent>,
        until stop: (I18nextEvent) -> Bool
    ) async -> [I18nextEvent] {
        var events: [I18nextEvent] = []
        for await event in stream {
            events.append(event)
            if stop(event) { break }
        }
        return events
    }

    @Test func loadingReportsEachBundleThenInitialized() async {
        let i18n = I18next { options in
            options.lng = "en"
            options.fallbackLng = ["pt"]
            options.backend = InMemoryBackend(["en": ["translation": ["a": "A"]]])
        }
        let stream = i18n.events

        await i18n.initialize()
        let events = await collect(stream) {
            if case .initialized = $0 { return true }
            return false
        }

        var loaded: [ResourceKey] = []
        var failed: [ResourceKey] = []
        var added = 0
        for event in events {
            switch event {
            case .loaded(let key): loaded.append(key)
            case .failedLoading(let failure): failed.append(failure.key)
            case .added: added += 1
            default: break
            }
        }
        #expect(loaded == [ResourceKey(language: "en", namespace: "translation")])
        #expect(failed == [ResourceKey(language: "pt", namespace: "translation")])
        #expect(added == 1)
    }

    @Test func changeLanguageReportsChangingThenChanged() async {
        let i18n = I18next { $0.lng = "en" }
        let stream = i18n.events

        await i18n.changeLanguage("pt-br")
        let events = await collect(stream) {
            if case .languageChanged = $0 { return true }
            return false
        }

        guard events.count == 2, case .languageChanging("pt-BR") = events[0], case .languageChanged("pt-BR") = events[1]
        else {
            Issue.record("unexpected events: \(events)")
            return
        }
    }

    @Test func aSupersededChangeDoesNotReportChanged() async {
        let i18n = I18next { $0.lng = "en" }
        let stream = i18n.events

        async let first = i18n.changeLanguage("pt")
        i18n.setLanguage("de")  // a newer request, made while the first is still pending
        _ = await first
        i18n.setLanguage("fr")
        let events = await collect(stream) {
            if case .languageChanged("fr") = $0 { return true }
            return false
        }

        let changed = events.compactMap { event -> String? in
            if case .languageChanged(let language) = event { return language }
            return nil
        }
        #expect(changed.last == "fr")
        #expect(i18n.language == "fr")
    }

    @Test func storeChangesAreReported() async {
        let i18n = I18next()
        let stream = i18n.events

        i18n.store.addResource(lng: "en", ns: "t", key: "a", value: "A")
        i18n.store.addResources(lng: "en", ns: "t", resources: ["b": "B", "c": "C"])
        i18n.store.removeResourceBundle(lng: "en", ns: "t")
        let events = await collect(stream) {
            if case .removed = $0 { return true }
            return false
        }

        guard events.count == 3, case .added("en", "t") = events[0], case .added("en", "t") = events[1],
            case .removed("en", "t") = events[2]
        else {
            Issue.record("unexpected events: \(events)")
            return
        }
    }

    @Test func eachStreamSeesTheEventsAfterItWasCreated() async {
        let i18n = I18next()
        i18n.store.addResource(lng: "en", ns: "t", key: "before", value: "x")
        let stream = i18n.events
        i18n.store.addResource(lng: "en", ns: "t", key: "after", value: "y")

        let events = await collect(stream) { _ in true }
        #expect(events.count == 1)
    }
}

@Suite("Missing keys")
struct MissingKeyTests {
    private func makeI18n(
        backend: (any Backend)? = nil,
        configure: (inout I18next.Options) -> Void = { _ in }
    ) -> I18next {
        I18next { options in
            options.lng = "en"
            options.fallbackLng = ["en"]
            options.saveMissing = true
            options.backend = backend
            options.resources = backend == nil ? ["en": ["translation": ["known": "Known"]]] : [:]
            configure(&options)
        }
    }

    @Test func theBackendCreatesAMissingKeyAndTheStoreKeepsIt() async {
        let backend = RecordingBackend(resources: ["en": ["translation": ["known": "Known"]]])
        let i18n = makeI18n(backend: backend)
        await i18n.initialize()

        #expect(i18n.t("fresh", .init(defaultValue: "Fresh {{n}}", variables: ["n": 1])) == "Fresh 1")

        #expect(await eventually { await backend.recorder.calls.count == 1 })
        let call = await backend.recorder.calls.first
        #expect(call?.key == "fresh")
        #expect(call?.namespace == "translation")
        #expect(call?.languages == ["en"])
        #expect(call?.fallbackValue == "Fresh {{n}}")
        #expect(call?.isUpdate == false)
        // i18next also stores the key under the first language, so it resolves from now on.
        #expect(i18n.t("fresh") == "Fresh {{n}}")
    }

    @Test func missingKeyHandlerTakesOverFromTheBackend() async {
        let backend = RecordingBackend(resources: ["en": ["translation": [:]]])
        let received = Protected<[MissingKey]>([])
        let i18n = makeI18n(backend: backend) { options in
            options.missingKeyHandler = { missing in received.withLock { $0.append(missing) } }
        }
        await i18n.initialize()

        _ = i18n.t("nope")

        #expect(received.withLock { $0.map(\.key) } == ["nope"])
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(await backend.recorder.calls.isEmpty)
    }

    @Test func theMissingKeyEventCarriesWhatTReturned() async {
        let i18n = makeI18n()
        let stream = i18n.events

        let text = i18n.t("nope", .init(defaultValue: "Fallback"))

        var received: (MissingKey, String)?
        for await event in stream {
            if case .missingKey(let missing, let value) = event {
                received = (missing, value)
                break
            }
        }
        #expect(text == "Fallback")
        #expect(received?.0.key == "nope")
        #expect(received?.1 == "Fallback")
    }

    @Test func nothingIsReportedWhenSaveMissingIsOff() async {
        let received = Protected<[MissingKey]>([])
        let i18n = makeI18n { options in
            options.saveMissing = false
            options.missingKeyHandler = { missing in received.withLock { $0.append(missing) } }
        }
        _ = i18n.t("nope")
        #expect(received.withLock { $0.isEmpty })
    }

    @Test func appendNamespaceAndParseMissingKeyHandler() {
        let appended = makeI18n { $0.appendNamespaceToMissingKey = true }
        #expect(appended.t("nope") == "translation:nope")
        #expect(appended.t("other:nope") == "other:nope")
        #expect(appended.t("known") == "Known")

        let parsed = makeI18n { options in
            options.parseMissingKeyHandler = { key, defaultValue, _ in
                defaultValue.map { "default(\($0))" } ?? "missing(\(key))"
            }
        }
        #expect(parsed.t("nope") == "missing(nope)")
        // (A reported key is stored by `saveMissing`, so each check needs a key of its own.)
        #expect(parsed.t("withDefault", .init(defaultValue: "dv")) == "default(dv)")
        #expect(parsed.t("known") == "Known")  // found keys are untouched
    }
}
