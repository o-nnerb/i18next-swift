// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Backend-driven loading. All of these are no-ops (returning an empty report) when no backend is in use.
extension I18next {
    /// Loads the active language, its fallbacks and `preload` for every configured namespace.
    /// Call once after creating the instance, like `i18next.init()`.
    @discardableResult
    public func initialize() async -> LoadReport {
        if language == nil { await detectLanguage() }
        let report = await load(languages: languagesToLoad(for: language), namespaces: namespacesToLoad())
        state.withLock { $0.isInitialized = true }
        refreshResolvedLanguage()
        hub.emit(.initialized)
        return report
    }

    /// Asks the language detector for candidates and picks the best supported one. Without a detector, nothing
    /// changes.
    func detectLanguage() async {
        guard let detector = options.languageDetector else { return }
        let candidates = await detector.detect()
        guard let chosen = languageUtils.bestMatch(from: candidates) else { return }
        state.withLock { state in
            guard state.language == nil else { return }
            state.language = chosen
        }
        refreshResolvedLanguage()
        await detector.cacheUserLanguage(chosen)
    }

    /// Loads `lng` (and its fallbacks), then makes it the active language.
    ///
    /// If another change starts, or the task is cancelled, before loading ends, the language is left as is:
    /// the most recently *requested* change wins, whatever order the loads finish in.
    @discardableResult
    public func changeLanguage(_ lng: String?) async -> LoadReport {
        var requested = lng
        if requested == nil, let detector = options.languageDetector {
            requested = languageUtils.bestMatch(from: await detector.detect())
        }
        let formatted = requested.map(languageUtils.format)
        hub.emit(.languageChanging(formatted))
        let token = state.withLock { state -> Int in
            state.languageChangeToken += 1
            return state.languageChangeToken
        }

        let report = await load(languages: languagesToLoad(for: formatted), namespaces: namespacesToLoad())

        guard !Task.isCancelled else { return report }
        let applied = state.withLock { state -> Bool in
            guard state.languageChangeToken == token else { return false }
            state.language = formatted
            return true
        }
        if applied {
            refreshResolvedLanguage()
            hub.emit(.languageChanged(formatted))
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
            force: true,
            onEvent: { [hub] in hub.emit($0) }
        )
    }

    // MARK: Helpers

    private func load(languages: [String], namespaces: [String]) async -> LoadReport {
        guard let connector else { return LoadReport() }
        return await connector.load(languages: languages, namespaces: namespaces) { [hub] in hub.emit($0) }
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
