// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Backend-driven loading. All of these are no-ops (returning an empty report) when no backend is in use.
extension I18next {
    /// Loads the active language, its fallbacks and `preload` for every configured namespace.
    /// Call once after creating the instance, like `i18next.init()`.
    @discardableResult
    public func initialize() async -> LoadReport {
        await load(languages: languagesToLoad(for: language), namespaces: namespacesToLoad())
    }

    /// Loads `lng` (and its fallbacks), then makes it the active language.
    ///
    /// If another change starts, or the task is cancelled, before loading ends, the language is left as is:
    /// the most recently *requested* change wins, whatever order the loads finish in.
    @discardableResult
    public func changeLanguage(_ lng: String?) async -> LoadReport {
        let formatted = lng.map(languageUtils.format)
        let token = state.withLock { state -> Int in
            state.languageChangeToken += 1
            return state.languageChangeToken
        }

        let report = await load(languages: languagesToLoad(for: formatted), namespaces: namespacesToLoad())

        guard !Task.isCancelled else { return report }
        state.withLock { state in
            guard state.languageChangeToken == token else { return }
            state.language = formatted
        }
        return report
    }

    /// Adds namespaces to the ones kept loaded and loads them for the active language.
    @discardableResult
    public func loadNamespaces(_ namespaces: [String]) async -> LoadReport {
        state.withLock { state in
            for ns in namespaces where !state.namespaces.contains(ns) { state.namespaces.append(ns) }
        }
        return await load(languages: languagesToLoad(for: language), namespaces: namespaces)
    }

    /// Loads other languages without activating them.
    @discardableResult
    public func loadLanguages(_ languages: [String]) async -> LoadReport {
        var codes: [String] = []
        for language in languages {
            for code in languagesToLoad(for: language) where !codes.contains(code) { codes.append(code) }
        }
        return await load(languages: codes, namespaces: namespacesToLoad())
    }

    /// Re-reads bundles from the backend, replacing what is stored (and retrying earlier failures).
    @discardableResult
    public func reloadResources(languages: [String]? = nil, namespaces: [String]? = nil) async -> LoadReport {
        guard let connector else { return LoadReport() }
        return await connector.load(
            languages: languages ?? languagesToLoad(for: language),
            namespaces: namespaces ?? namespacesToLoad(),
            force: true
        )
    }

    // MARK: Helpers

    private func load(languages: [String], namespaces: [String]) async -> LoadReport {
        guard let connector else { return LoadReport() }
        return await connector.load(languages: languages, namespaces: namespaces)
    }

    func languagesToLoad(for code: String?) -> [String] {
        var codes = languageUtils.hierarchy(for: code)
        for preloaded in options.preload {
            let extra = languageUtils.hierarchy(for: preloaded, fallback: FallbackLanguages.none)
            for candidate in extra where !codes.contains(candidate) { codes.append(candidate) }
        }
        // `cimode` is a key-echo mode and `dev` is i18next's placeholder fallback; neither has files to fetch.
        return codes.filter { $0 != "cimode" && $0 != "dev" }
    }

    func namespacesToLoad() -> [String] {
        var namespaces = state.withLock { $0.namespaces }
        for ns in options.fallbackNS where !namespaces.contains(ns) { namespaces.append(ns) }
        return namespaces
    }
}
