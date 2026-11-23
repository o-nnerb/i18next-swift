// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

/// Counts what the backend was asked for.
private actor ReadCounter {
    private(set) var reads: [ResourceKey] = []
    func record(_ key: ResourceKey) { reads.append(key) }
}

private struct CountingBackend: Backend {
    let resources: ResourceStore.Resources
    let counter = ReadCounter()

    func read(language: String, namespace: String) async throws -> JSONValue {
        await counter.record(ResourceKey(language: language, namespace: namespace))
        guard let bundle = resources[language]?[namespace] else {
            throw BackendError.notFound(language: language, namespace: namespace)
        }
        return bundle
    }
}

private let sampleResources: ResourceStore.Resources = [
    "en": ["translation": ["a": "A en", "shout": "{{v, shout}}"], "common": ["ok": "OK"]],
    "de": ["translation": ["a": "A de"]],
]

private func makeInstance(_ configure: (inout I18next.Options) -> Void = { _ in }) -> I18next {
    I18next { options in
        options.lng = "en"
        options.fallbackLng = ["en"]
        options.resources = sampleResources
        configure(&options)
    }
}

/// Everything that arrives on `stream` up to the sentinel, which the caller emits last.
private func drain(_ stream: AsyncStream<I18nextEvent>, upTo sentinel: String) async -> [I18nextEvent] {
    var events: [I18nextEvent] = []
    for await event in stream {
        if case .languageChanged(sentinel) = event { break }
        events.append(event)
    }
    return events
}

@Suite("cloneInstance")
struct CloneInstanceTests {
    @Test func startsInTheLanguageTheOriginalIsIn() {
        let original = makeInstance()
        original.setLanguage("de")
        let clone = original.cloneInstance()

        #expect(clone.isClone)
        #expect(!original.isClone)
        #expect(clone.language == "de")
        #expect(clone.t("a") == "A de")
        #expect(clone.options.lng == "de")
        #expect(clone.options.preload.isEmpty)
    }

    @Test func theConfigurationCanChangeTheLanguageAndOptions() {
        let original = makeInstance()
        let clone = original.cloneInstance { options in
            options.lng = "de"
            options.interpolation.prefix = "<<"
            options.interpolation.suffix = ">>"
        }
        original.store.addResource(lng: "de", ns: "translation", key: "ip", value: "{{n}} <<n>>")
        #expect(clone.language == "de")
        #expect(clone.t("ip", .init(variables: ["n": 1])) == "{{n}} 1")
        #expect(original.language == "en")
    }

    @Test func languageChangesStayOnTheirSide() {
        let original = makeInstance()
        let clone = original.cloneInstance()
        clone.setLanguage("de")
        #expect(original.language == "en")
        original.setLanguage("fr")
        #expect(clone.language == "de")
        #expect(clone.resolvedLanguage == "de")
        #expect(original.resolvedLanguage == "en")
    }

    @Test func theDefaultNamespacesAreTheCurrentOnes() {
        let original = makeInstance()
        original.setDefaultNamespace("common")
        let clone = original.cloneInstance()
        #expect(clone.defaultNamespaces == ["common"])
        #expect(clone.t("ok") == "OK")
        clone.setDefaultNamespace("translation")
        #expect(original.defaultNamespaces == ["common"])
    }

    @Test func theStoreIsSharedByDefault() {
        let original = makeInstance()
        let clone = original.cloneInstance()
        #expect(clone.store === original.store)

        clone.addResourceBundle(lng: "de", ns: "translation", resources: ["b": "B de"])
        #expect(original.t("b", .init(lng: "de")) == "B de")
        original.store.addResource(lng: "en", ns: "translation", key: "c", value: "C")
        #expect(clone.t("c") == "C")
    }

    @Test func aForkedStoreIsACopy() {
        let original = makeInstance()
        let clone = original.cloneInstance(forkResourceStore: true)
        #expect(clone.store !== original.store)
        #expect(clone.t("a") == "A en")

        clone.store.addResource(lng: "en", ns: "translation", key: "only", value: "clone")
        original.store.addResource(lng: "en", ns: "translation", key: "also", value: "original")
        #expect(original.t("only") == "only")
        #expect(clone.t("only") == "clone")
        #expect(clone.t("also") == "also")
        original.store.removeResourceBundle(lng: "en", ns: "common")
        #expect(clone.hasResourceBundle(lng: "en", ns: "common"))
    }

    @Test func aForkedStoreSeesWhatWasStoredAtTheMoment() {
        let original = makeInstance()
        original.store.addResource(lng: "en", ns: "translation", key: "late", value: "late")
        let clone = original.cloneInstance(forkResourceStore: true)
        #expect(clone.t("late") == "late")
    }

    @Test func formatsAndPostProcessorsAreInheritedAndPrivate() {
        let original = makeInstance { $0.postProcess = ["bang"] }
        original.addPostProcessor("bang") { value, _ in value + "!" }
        original.addFormat("shout") { value, _ in .string(value.interpolationString.uppercased()) }
        let clone = original.cloneInstance()

        #expect(clone.t("shout", .init(variables: ["v": "hey"])) == "HEY!")

        // what the clone adds stays with it
        clone.addFormat("whisper") { value, _ in .string(value.interpolationString.lowercased()) }
        clone.addPostProcessor("question") { value, _ in value + "?" }
        original.store.addResource(lng: "en", ns: "translation", key: "w", value: "{{v, whisper}}")
        let call = TranslationOptions(variables: ["v": "HEY"], postProcess: ["question"])
        #expect(clone.t("w", call) == "hey?")
        #expect(original.t("w", call) == "HEY")

        // what the original adds later is seen
        original.addPostProcessor("angle") { value, _ in "<\(value)>" }
        #expect(clone.t("a", .init(postProcess: ["angle", "question"])) == "<A en>?")

        // and the clone's own entry wins
        clone.addPostProcessor("angle") { value, _ in "[\(value)]" }
        #expect(clone.t("a", .init(postProcess: ["angle"])) == "[A en]")
        #expect(original.t("a", .init(postProcess: ["angle"])) == "<A en>")
    }

    @Test func configuredFormatsBelongToTheClone() {
        let original = makeInstance()
        let clone = original.cloneInstance { options in
            options.formats["shout"] = { value, _ in .string(value.interpolationString.uppercased()) }
        }
        #expect(clone.t("shout", .init(variables: ["v": "hey"])) == "HEY")
        #expect(original.t("shout", .init(variables: ["v": "hey"])) == "hey")  // no such format here
    }

    @Test func aCloneOfACloneInheritsFromBoth() {
        let original = makeInstance()
        original.addPostProcessor("one") { value, _ in value + "1" }
        let first = original.cloneInstance()
        first.addPostProcessor("two") { value, _ in value + "2" }
        let second = first.cloneInstance { $0.lng = "de" }

        #expect(second.t("a", .init(postProcess: ["one", "two"])) == "A de12")
        #expect(second.isClone)
        #expect(second.store === original.store)
    }

    @Test func languageSettingsFollowTheClonesOptions() {
        let original = makeInstance()
        let clone = original.cloneInstance { $0.fallbackLng = ["de"] }
        #expect(clone.languages == ["en", "de"])
        #expect(original.languages == ["en"])
    }

    @Test func eventsStayWithTheInstanceThatCausedThem() async {
        let original = makeInstance()
        let clone = original.cloneInstance()
        let fromOriginal = original.events
        let fromClone = clone.events

        clone.setLanguage("de")
        original.setLanguage("fr")
        original.setLanguage("end")
        clone.setLanguage("end")

        let originalEvents = await drain(fromOriginal, upTo: "end")
        let cloneEvents = await drain(fromClone, upTo: "end")
        #expect(originalEvents.count == 1)
        #expect(cloneEvents.count == 1)
        guard case .languageChanged("fr")? = originalEvents.first, case .languageChanged("de")? = cloneEvents.first
        else {
            Issue.record("unexpected events \(originalEvents) \(cloneEvents)")
            return
        }
    }

    @Test func aSharedStoreReportsToBothInstances() async {
        let original = makeInstance()
        let clone = original.cloneInstance()
        let fromOriginal = original.events
        let fromClone = clone.events

        clone.addResourceBundle(lng: "de", ns: "extra", resources: ["k": "v"])
        original.store.removeResourceBundle(lng: "de", ns: "extra")
        original.setLanguage("end")
        clone.setLanguage("end")

        for stream in [fromOriginal, fromClone] {
            let events = await drain(stream, upTo: "end")
            #expect(events.count == 2)
            guard case .added("de", "extra")? = events.first, case .removed("de", "extra")? = events.last else {
                Issue.record("unexpected events \(events)")
                return
            }
        }
    }

    @Test func aForkedStoreReportsToItsOwnInstance() async {
        let original = makeInstance()
        let clone = original.cloneInstance(forkResourceStore: true)
        let fromOriginal = original.events
        let fromClone = clone.events

        clone.addResourceBundle(lng: "de", ns: "extra", resources: ["k": "v"])
        original.setLanguage("end")
        clone.setLanguage("end")

        #expect(await drain(fromOriginal, upTo: "end").isEmpty)
        #expect(await drain(fromClone, upTo: "end").count == 1)
    }

    @Test func aReleasedCloneLeavesNothingBehind() {
        let original = makeInstance()
        for _ in 0..<50 {
            _ = original.cloneInstance().t("a")
        }
        // The store forgets clones that are gone: writing is still fine, and so is a clone made afterwards.
        original.store.addResource(lng: "en", ns: "translation", key: "k", value: "v")
        #expect(original.cloneInstance().t("k") == "v")
    }

    @Test func manyClonesCanWorkAtOnce() async {
        let original = makeInstance()
        let languages = ["en", "de"]

        let answers = await withTaskGroup(of: String.self) { group in
            for index in 0..<200 {
                group.addTask {
                    let fork = index % 2 == 0
                    let clone = original.cloneInstance(forkResourceStore: fork) { $0.lng = languages[index % 2] }
                    clone.store.addResource(lng: "en", ns: "translation", key: "k\(index)", value: .string("v\(index)"))
                    clone.addPostProcessor("tag") { value, _ in "\(value)#\(index)" }
                    return clone.t("k\(index)", .init(postProcess: ["tag"]))
                }
            }
            var all: [String] = []
            for await answer in group { all.append(answer) }
            return all.sorted()
        }
        #expect(answers == (0..<200).map { "v\($0)#\($0)" }.sorted())

        // shared clones wrote 100 keys into the original's store; forked ones none
        let written = original.getDataByLanguage(lng: "en")?["translation"]?.objectValue?.keys.filter {
            $0.hasPrefix("k")
        }
        #expect(written?.count == 100)
    }
}

@Suite("cloneInstance and backends")
struct CloneInstanceBackendTests {
    @Test func aCloneSharingTheStoreSharesTheLoading() async {
        let backend = CountingBackend(resources: sampleResources)
        let original = I18next { options in
            options.lng = "en"
            options.backend = backend
        }
        let clone = original.cloneInstance()
        #expect(!clone.hasLoadedNamespace("translation"))

        await original.initialize()
        await clone.initialize()
        #expect(clone.hasLoadedNamespace("translation"))
        #expect(clone.t("a") == "A en")
        let initial = await backend.counter.reads.filter { $0 == ResourceKey(language: "en", namespace: "translation") }
        #expect(initial.count == 1)

        await clone.changeLanguage("de")
        await original.changeLanguage("de")
        let reads = await backend.counter.reads
        #expect(reads.filter { $0 == ResourceKey(language: "de", namespace: "translation") }.count == 1)
        #expect(clone.language == "de")
    }

    @Test func eachInstanceHearsAboutItsOwnLoads() async {
        let backend = CountingBackend(resources: sampleResources)
        let original = I18next { options in
            options.lng = "en"
            options.backend = backend
        }
        let clone = original.cloneInstance()
        let fromOriginal = original.events
        let fromClone = clone.events

        await clone.changeLanguage("de")
        original.setLanguage("end")
        clone.setLanguage("end")

        let originalEvents = await drain(fromOriginal, upTo: "end")
        let cloneEvents = await drain(fromClone, upTo: "end")
        let cloneLoaded = cloneEvents.filter { if case .loaded = $0 { true } else { false } }
        let originalLoaded = originalEvents.filter { if case .loaded = $0 { true } else { false } }
        #expect(!cloneLoaded.isEmpty)
        #expect(originalLoaded.isEmpty)
    }

    @Test func aForkedStoreLoadsIntoItself() async {
        let backend = CountingBackend(resources: sampleResources)
        let original = I18next { options in
            options.lng = "en"
            options.backend = backend
        }
        await original.initialize()
        let clone = original.cloneInstance(forkResourceStore: true)

        await clone.changeLanguage("de")
        #expect(clone.hasResourceBundle(lng: "de", ns: "translation"))
        #expect(!original.hasResourceBundle(lng: "de", ns: "translation"))
        #expect(clone.t("a") == "A de")
    }

    @Test func aCloneOfAnUninitializedInstanceIsUninitializedToo() async {
        let original = I18next { options in
            options.lng = "en"
            options.backend = InMemoryBackend(sampleResources)
        }
        let clone = original.cloneInstance()
        #expect(!clone.hasLoadedNamespace("translation"))
        await clone.initialize()
        #expect(clone.hasLoadedNamespace("translation"))
        // being initialized is up to each instance, though the bundles they share are there for both
        #expect(!original.hasLoadedNamespace("translation"))
        #expect(original.t("a") == "A en")
    }
}

@Suite("hydrate")
struct HydrateTests {
    private let hydrated: ResourceStore.Resources = [
        "en": ["translation": ["hello": "Hello"], "extra": ["e": "E"]],
        "pt": ["translation": ["hello": "Olá"]],
    ]

    @Test func seedsTheStoreAndTheLanguage() {
        let i18n = I18next { $0.lng = "en" }
        #expect(i18n.t("hello") == "hello")

        i18n.hydrate(hydrated, lng: "pt")
        #expect(i18n.language == "pt")
        #expect(i18n.resolvedLanguage == "pt")
        #expect(i18n.t("hello") == "Olá")
        #expect(i18n.t("e", .init(lng: "en", ns: ["extra"])) == "E")
    }

    @Test func eachPartHappensOnce() {
        let i18n = I18next { $0.lng = "en" }
        i18n.hydrate(hydrated, lng: "pt")
        i18n.hydrate(["en": ["translation": ["hello": "Second"]]], lng: "en")
        #expect(i18n.language == "pt")
        #expect(i18n.t("hello") == "Olá")

        let partial = I18next { $0.lng = "en" }
        partial.hydrate(hydrated)
        partial.hydrate(["en": ["translation": ["hello": "Second"]]])
        #expect(partial.t("hello") == "Hello")
        partial.hydrate(lng: "pt")
        partial.hydrate(lng: "en")
        #expect(partial.language == "pt")
    }

    @Test func theLanguageIsAnnouncedAndTheResolvedLanguageRefreshed() async {
        let i18n = I18next { $0.lng = "en" }
        let events = i18n.events
        i18n.hydrate(hydrated, lng: "pt")
        i18n.setLanguage("end")
        let seen = await drain(events, upTo: "end")
        #expect(seen.contains { if case .languageChanged("pt") = $0 { true } else { false } })
    }

    @Test func resourcesAloneLeaveTheResolvedLanguageAsItWas() {
        // As in i18next: only a language change works it out again.
        let i18n = I18next { $0.lng = "en" }
        i18n.hydrate(hydrated)
        #expect(i18n.t("hello") == "Hello")
        #expect(i18n.resolvedLanguage == nil)
        i18n.setLanguage("en")
        #expect(i18n.resolvedLanguage == "en")
    }

    @Test func aCloneIgnoresIt() {
        let original = I18next { $0.lng = "en" }
        let clone = original.cloneInstance()
        clone.hydrate(hydrated, lng: "pt")
        #expect(clone.language == "en")
        #expect(clone.t("hello") == "hello")
        original.hydrate(hydrated, lng: "pt")
        #expect(clone.t("hello", .init(lng: "pt")) == "Olá")
    }

    @Test func anInstanceWithABackendCountsAsInitialized() {
        let i18n = I18next { options in
            options.lng = "en"
            options.backend = InMemoryBackend([:])
        }
        #expect(!i18n.hasLoadedNamespace("translation"))
        i18n.hydrate(hydrated, lng: "en")
        #expect(i18n.hasLoadedNamespace("translation"))
        #expect(i18n.hasLoadedNamespace("extra"))
    }

    @Test func itsNamespacesAreKeptLoaded() async {
        let backend = CountingBackend(resources: ["pt": ["translation": ["x": "y"], "extra": ["z": "w"]]])
        let i18n = I18next { options in
            options.lng = "en"
            options.fallbackLng = ["pt"]
            options.backend = backend
        }
        i18n.hydrate(hydrated)
        await i18n.changeLanguage("pt")
        // `translation` and `extra` are stored for `pt`/`en` by the hydration; only what is missing is read
        let reads = await backend.counter.reads
        #expect(!reads.contains(ResourceKey(language: "pt", namespace: "translation")))
        #expect(reads.contains(ResourceKey(language: "pt", namespace: "extra")))
    }
}

@Suite("Store accessors")
struct StoreAccessorTests {
    @Test func getDataByLanguageReturnsACopy() {
        let i18n = makeInstance()
        let data = i18n.getDataByLanguage(lng: "de")
        #expect(data == ["translation": ["a": "A de"]])
        i18n.store.addResource(lng: "de", ns: "translation", key: "b", value: "B")
        #expect(data == ["translation": ["a": "A de"]])
        #expect(i18n.getDataByLanguage(lng: "zz") == nil)
        #expect(i18n.store.data.keys.sorted() == ["de", "en"])
    }

    @Test func aLanguageStaysAfterItsLastBundleIsRemoved() {
        let i18n = makeInstance()
        i18n.store.removeResourceBundle(lng: "de", ns: "translation")
        #expect(i18n.getDataByLanguage(lng: "de") == [:])
        #expect(!i18n.store.hasLanguageSomeTranslations(lng: "de"))
    }

    @Test func anEmptyKeyReplacesTheBundle() {
        let i18n = makeInstance()
        i18n.store.addResource(lng: "en", ns: "translation", key: "", value: ["whole": "bundle"])
        #expect(i18n.store.getResourceBundle(lng: "en", ns: "translation") == ["whole": "bundle"])
    }
}
