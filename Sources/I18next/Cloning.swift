// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Seeding an instance with resources it didn't load itself, and making independent copies of one.
extension I18next {
    /// Seeds the instance with resources that were produced elsewhere, as i18next's `hydrate`: the server rendered a
    /// page with some resources and the client starts from the same ones, without loading anything.
    ///
    /// - Parameters:
    ///   - resources: Replaces everything in the store. Its namespaces join the ones the instance keeps loaded, and
    ///     an instance with a backend counts as initialized from then on (see ``hasLoadedNamespace(_:lng:)``).
    ///   - lng: The language to switch to, immediately and without loading, as ``setLanguage(_:)`` does.
    ///
    /// Each part happens once: a second call's `resources`, and a second call's `lng`, are ignored. This is what
    /// makes it safe to call from code that may run twice. A clone (see ``cloneInstance(forkResourceStore:_:)``)
    /// ignores `hydrate` altogether, because it may share its store with the instance that was seeded.
    public func hydrate(_ resources: ResourceStore.Resources? = nil, lng: String? = nil) {
        guard !isClone else { return }

        if let resources, state.withLock({ claim(&$0.hydratedStore) }) {
            store.replaceAll(with: resources)
            let hydrated = Set(resources.values.flatMap { $0.keys }).sorted()
            state.withLock { state in
                for ns in hydrated where !state.namespaces.contains(ns) { state.namespaces.append(ns) }
                state.isInitialized = true
            }
        }
        if let lng, !lng.isEmpty, state.withLock({ claim(&$0.hydratedLanguage) }) {
            setLanguage(lng)
        }
    }

    /// Sets `flag` and says whether it was clear.
    private func claim(_ flag: inout Bool) -> Bool {
        defer { flag = true }
        return !flag
    }

    /// A new instance that starts out like this one, for a request, a screen or a test that needs its own language or
    /// options without disturbing the original (i18next's `cloneInstance`).
    ///
    /// `configure` receives a copy of this instance's options to change, with these starting values:
    /// - ``Options/lng`` is the language this instance is in now, not the one it was created with.
    /// - ``Options/defaultNS`` is the current default namespaces (see ``setDefaultNamespace(_:)-(String)``).
    /// - ``Options/preload`` is empty, so the clone doesn't load languages the original already did.
    /// - ``Options/formats`` and ``Options/postProcessors`` are empty: they are the clone's own.
    ///
    /// What is shared, and what isn't:
    /// - **Resources.** The clone uses the same ``store`` unless `forkResourceStore` is true; then it gets a copy
    ///   (what is stored now), and additions on either side stay on that side. A shared store reports its changes to
    ///   the events of every instance using it.
    /// - **Backend.** A clone sharing the store also shares the original's loading: bundles are fetched once, a
    ///   failed one isn't retried by the other, and the backend options of the original apply (`backend`,
    ///   `backendOptions`, `resources` and `partialBundledLanguages` set in `configure` are ignored). A forked store
    ///   is loaded from `configure`'s `backend`, through a connector of its own.
    /// - **Language.** Independent from then on: ``changeLanguage(_:)`` or ``setLanguage(_:)`` on either instance
    ///   doesn't move the other. Everything derived from the options (fallbacks, `load`, `supportedLngs`, plural
    ///   separator, interpolation...) follows the clone's options, where i18next reuses the original's language
    ///   settings.
    /// - **Formats and post-processors.** The clone sees those registered on the original, also the ones added after
    ///   the clone was made; what the clone registers is its own and doesn't reach the original.
    /// - **Events.** ``events`` are the clone's own: its language changes, its loads and its missing keys.
    ///
    /// The clone's ``isClone`` is true. If this instance has a backend and wasn't initialized yet, neither is the
    /// clone: call ``initialize()`` on either.
    public func cloneInstance(
        forkResourceStore: Bool = false,
        _ configure: (inout Options) -> Void = { _ in }
    ) -> I18next {
        var cloned = options
        cloned.lng = language
        cloned.defaultNS = defaultNamespaces
        cloned.preload = []
        cloned.formats = [:]
        cloned.postProcessors = [:]
        configure(&cloned)

        let hub = EventHub()
        let store: ResourceStore
        let connector: BackendConnector?
        if forkResourceStore {
            store = ResourceStore(
                data: self.store.data,
                keySeparator: cloned.keySeparator,
                ignoreJSONStructure: true,
                onChange: { hub.emit($0) }
            )
            connector =
                self.connector == nil
                ? nil
                : cloned.backend.map { BackendConnector(backend: $0, store: store, options: cloned.backendOptions) }
        } else {
            store = self.store
            store.share(with: hub)
            connector = self.connector
        }

        let languageUtils = Self.makeLanguageUtils(cloned)
        var namespaces = state.withLock { $0.namespaces }
        for ns in (cloned.ns ?? []) + cloned.defaultNS where !namespaces.contains(ns) { namespaces.append(ns) }
        var state = State(
            language: cloned.lng.map(languageUtils.format),
            namespaces: namespaces,
            defaultNS: cloned.defaultNS,
            isInitialized: self.state.withLock { $0.isInitialized }
        )
        for (name, format) in cloned.formats { state.formats[Self.formatName(name)] = format }
        state.postProcessors = cloned.postProcessors

        return I18next(
            options: cloned,
            hub: hub,
            store: store,
            connector: connector,
            languageUtils: languageUtils,
            state: state,
            parent: self
        )
    }
}
