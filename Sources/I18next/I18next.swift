// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

public final class I18next: Sendable {
    /// What a formatter is told: the language, and every option that applies to the value.
    public struct FormatContext: Sendable {
        /// The language to format for: the variable's `formatParams` locale, the call's `lng`, or the active language.
        public let language: String?
        /// The arguments written in the template (`number(minimumFractionDigits: 2)`), the call's options and
        /// variables, and the `formatParams` entry for the variable, the last one winning.
        public let options: [String: JSONValue]
        /// The name of the variable being formatted.
        public let variable: String
    }

    /// A `{{value, name(arg: x)}}` formatter. Throwing leaves the value as it was, as in i18next.
    public typealias Format = @Sendable (_ value: JSONValue, _ context: FormatContext) throws -> JSONValue

    /// What a post-processor is told about the translation it is handed.
    public struct PostProcessContext: Sendable {
        /// The keys `t` was called with (i18next passes the same array).
        public let keys: [String]
        /// The language the text is for: the call's `lng`, the active language, or the one the key was found in.
        public let language: String?
        /// The call's options. Variables passed to `t` are in ``TranslationOptions/variables``.
        public let options: TranslationOptions
        /// Where the text came from, as `details(_:_:)` reports it (i18next's `postProcessPassResolved`).
        public let usedKey: String
        public let usedLng: String?
        public let usedNS: String?
        /// The instance doing the translating.
        public let translator: I18next
    }

    /// Transforms a finished translation. Returning `nil` keeps the text as it was, as in i18next.
    public typealias PostProcessor = @Sendable (_ value: String, _ context: PostProcessContext) -> String?

    public struct Options: Sendable {
        public var lng: String?
        public var fallbackLng: FallbackLanguages = .none
        public var load: LoadStrategy = .all
        /// `pt-br` → `pt-br` instead of `pt-BR`.
        public var lowerCaseLng = false
        /// Lower-cases codes that aren't well-formed tags too. `nil` leaves them alone, as i18next does by default.
        public var cleanCode: Bool?
        /// Only these languages are resolved and loaded (`cimode` is always allowed).
        public var supportedLngs: [String]?
        /// With `supportedLngs`, accept `de-AT` when `de` is supported.
        public var nonExplicitSupportedLngs = false
        /// Formatters available from the start, by lower-cased name. See the `I18nextFormatters` product for the
        /// ones i18next ships (`number`, `currency`, `datetime`, `relativetime`, `list`).
        public var formats: [String: Format] = [:]
        /// Post-processors available from the start, by name (case-sensitive).
        public var postProcessors: [String: PostProcessor] = [:]
        /// Post-processors applied, in order, to every translation. A call's ``TranslationOptions/postProcess``
        /// replaces them (an empty list switches them off for that call). Names that aren't registered are skipped.
        public var postProcess: [String] = []
        /// Reports keys that `t` could not find, to `missingKeyHandler` or the backend.
        public var saveMissing = false
        public var saveMissingTo: SaveMissingTo = .fallback
        /// With a count, report every plural form of the language instead of the bare key.
        public var saveMissingPlurals = true
        /// Also report keys that exist but whose text differs from the `defaultValue` given.
        public var updateMissing = false
        /// A missing key comes back as `ns:key`.
        public var appendNamespaceToMissingKey = false
        /// Receives every key reported by `saveMissing`; without it the backend's `create` is used.
        public var missingKeyHandler: (@Sendable (MissingKey) -> Void)?
        /// Maps a missing key (and the default value, when one was used) to the text `t` returns.
        public var parseMissingKeyHandler: (@Sendable (String, String?, TranslationOptions) -> String)?
        /// Chooses the language when `lng` is not set. See ``LanguageDetector``.
        public var languageDetector: (any LanguageDetector)?
        /// In `cimode`, `t` returns `ns:key` instead of `key`.
        public var appendNamespaceToCIMode = false
        /// Languages to load in addition to the active one (and its fallbacks).
        public var preload: [String] = []
        public var defaultNS: [String] = ["translation"]
        /// Namespaces loaded from the backend. `defaultNS` is always included.
        public var ns: [String]?
        public var fallbackNS: [String] = []
        public var resources: ResourceStore.Resources = [:]
        /// `nil` switches the separator off (i18next's `keySeparator: false`).
        public var keySeparator: String? = "." { didSet { userDefinedKeySeparator = true } }
        public var nsSeparator: String? = ":" { didSet { userDefinedNsSeparator = true } }
        var userDefinedKeySeparator = false
        var userDefinedNsSeparator = false
        public var contextSeparator = "_"
        public var pluralSeparator = "_"
        /// When false (i18next's default), an empty string value is treated as missing.
        public var returnEmptyString = false
        /// Objects and arrays are returned by ``I18next/object(_:_:)`` regardless; this also lets `t` stringify them.
        public var returnObjects = false
        /// Joins array resources into a string with this separator when set.
        public var joinArrays: String?
        public var interpolation = InterpolationOptions()

        /// Where missing bundles are loaded from. Without one, only `resources` are available.
        public var backend: (any Backend)?
        public var backendOptions = BackendOptions()
        /// With `resources` set, the backend is ignored unless this is true (bundled resources are the whole truth).
        public var partialBundledLanguages = false

        public init() {}
    }

    /// Which languages `saveMissing` reports a key for.
    public enum SaveMissingTo: Sendable {
        /// The fallback languages (the current one when there are none).
        case fallback
        case current
        /// The whole resolution hierarchy.
        case all
    }

    struct State: Sendable {
        var language: String?
        var namespaces: [String]
        var formats: [String: Format] = [:]
        var postProcessors: [String: PostProcessor] = [:]
        var defaultNS: [String]
        /// The first language of the hierarchy that has translations (i18next's `resolvedLanguage`).
        var resolvedLanguage: String?
        /// False for an instance with a backend until `initialize()` has run.
        var isInitialized: Bool
        /// Bumped by every language change so an older, slower change can't override a newer one.
        var languageChangeToken = 0
    }

    public let options: Options
    public let store: ResourceStore
    let plurals: PluralResolver
    public let languageUtils: LanguageUtils
    let state: Protected<State>
    let connector: BackendConnector?
    let hub: EventHub

    public init(_ options: Options = Options()) {
        self.options = options
        let hub = EventHub()
        self.hub = hub
        let store = ResourceStore(
            data: options.resources,
            keySeparator: options.keySeparator,
            ignoreJSONStructure: true,
            onChange: { hub.emit($0) }
        )
        self.store = store
        self.plurals = PluralResolver(separator: options.pluralSeparator)
        let languageUtils = LanguageUtils(
            fallbackLng: options.fallbackLng,
            load: options.load,
            lowerCaseLng: options.lowerCaseLng,
            cleanCode: options.cleanCode,
            supportedLngs: options.supportedLngs.map { $0.contains("cimode") ? $0 : $0 + ["cimode"] },
            nonExplicitSupportedLngs: options.nonExplicitSupportedLngs
        )
        self.languageUtils = languageUtils

        var namespaces = options.ns ?? options.defaultNS
        for ns in options.defaultNS where !namespaces.contains(ns) { namespaces.append(ns) }
        let usesBackend = options.backend != nil && (options.resources.isEmpty || options.partialBundledLanguages)
        var state = State(
            language: options.lng.map(languageUtils.format),
            namespaces: namespaces,
            defaultNS: options.defaultNS,
            isInitialized: !usesBackend
        )
        for (name, format) in options.formats { state.formats[Self.formatName(name)] = format }
        state.postProcessors = options.postProcessors
        self.state = Protected(state)

        self.connector =
            usesBackend
            ? options.backend.map {
                BackendConnector(
                    backend: $0,
                    store: store,
                    options: options.backendOptions,
                    onEvent: { hub.emit($0) }
                )
            }
            : nil
        refreshResolvedLanguage()
    }

    public convenience init(configure: (inout Options) -> Void) {
        var options = Options()
        configure(&options)
        self.init(options)
    }

    // MARK: Events

    /// A stream of what happens to this instance: loading, language changes, missing keys, store changes. Every call
    /// returns an independent stream that sees events from the moment it is created.
    public var events: AsyncStream<I18nextEvent> { hub.stream() }

    // MARK: Language

    public var language: String? {
        state.withLock { $0.language }
    }

    /// Languages searched for the active language, in priority order.
    public var languages: [String] {
        languageUtils.hierarchy(for: language)
    }

    /// The first language of the active language's hierarchy that has translations: `pt` while `pt-BR` is active
    /// but only `pt` is loaded. `nil` for `cimode`, `dev` and when nothing is loaded for any of them.
    ///
    /// It is worked out when the language changes and when ``initialize()`` finishes, as in i18next, so resources
    /// added later don't change it until the next change.
    public var resolvedLanguage: String? {
        state.withLock { $0.resolvedLanguage }
    }

    func refreshResolvedLanguage() {
        var resolved: String?
        if let current = language, current != "cimode", current != "dev" {
            let hierarchy = languageUtils.hierarchy(for: current)
            resolved = hierarchy.first {
                $0 != "cimode" && $0 != "dev" && store.hasLanguageSomeTranslations(lng: $0)
            }
            if resolved == nil, !hierarchy.contains(current), store.hasLanguageSomeTranslations(lng: current) {
                resolved = current
            }
        }
        state.withLock { $0.resolvedLanguage = resolved }
    }

    /// Switches the language immediately, without touching the backend. Use ``changeLanguage(_:)``
    /// to load the new language's resources first.
    public func setLanguage(_ lng: String?) {
        let formatted = lng.map(languageUtils.format)
        state.withLock { state in
            state.languageChangeToken += 1
            state.language = formatted
        }
        refreshResolvedLanguage()
        hub.emit(.languageChanged(formatted))
    }

    // MARK: Namespaces

    /// The namespaces `t` searches when a call names none.
    public var defaultNamespaces: [String] {
        state.withLock { $0.defaultNS }
    }

    /// Replaces the default namespaces (i18next's `setDefaultNamespace`). Nothing is loaded.
    public func setDefaultNamespace(_ namespaces: [String]) {
        state.withLock { $0.defaultNS = namespaces }
    }

    public func setDefaultNamespace(_ namespace: String) {
        setDefaultNamespace([namespace])
    }

    /// Whether `ns` is ready for `lng` (the resolved or active language by default), as i18next's
    /// `hasLoadedNamespace`: it is stored, or its load has finished (even unsuccessfully) for `lng` and for the last
    /// fallback. An instance without a backend, or with bundled resources only, is always ready; one with a backend
    /// isn't until ``initialize()`` has run, nor for a namespace that was never requested.
    public func hasLoadedNamespace(_ ns: String, lng: String? = nil) -> Bool {
        guard state.withLock({ $0.isInitialized }) else { return false }
        let hierarchy = languages
        guard language != nil, let first = hierarchy.first, let last = hierarchy.last else { return false }

        let code = lng ?? resolvedLanguage ?? first
        if code.lowercased() == "cimode" { return true }
        if hasResourceBundle(lng: code, ns: ns) { return true }
        guard let connector else { return true }

        let loadLng: String? =
            lng == nil
            ? code
            : (languageUtils.isSupported(code)
                ? languageUtils.hierarchy(for: code, fallback: FallbackLanguages.none).first : nil)
        let hasFallback = options.fallbackLng != .none
        let language = loadLng.map { connector.isSettled(ResourceKey(language: $0, namespace: ns)) } ?? true
        let fallback = !hasFallback || connector.isSettled(ResourceKey(language: last, namespace: ns))
        return language && fallback
    }

    // MARK: Formats

    public func addFormat(_ name: String, _ format: @escaping Format) {
        state.withLock { $0.formats[Self.formatName(name)] = format }
    }

    /// Format names are case-insensitive and ignore surrounding whitespace.
    static func formatName(_ name: String) -> String {
        Interpolator.trimmed(name).lowercased()
    }

    // MARK: Post-processors

    /// Registers (or replaces) a post-processor. Use it through ``Options/postProcess`` or
    /// ``TranslationOptions/postProcess``.
    public func addPostProcessor(_ name: String, _ processor: @escaping PostProcessor) {
        state.withLock { $0.postProcessors[name] = processor }
    }

    // MARK: Translation

    public func t(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> String {
        translate([key], options)
    }

    /// Tries the keys in order and uses the first that resolves; if none does, the last key is returned.
    public func t(_ keys: [String], _ options: TranslationOptions = TranslationOptions()) -> String {
        translate(keys, options)
    }

    /// What the resource holds, with objects and arrays returned (their leaves translated), like `t` with
    /// `returnObjects: true`. A string resource comes back as a string, a missing key as the key.
    public func object(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> JSONValue {
        var options = options
        options.returnObjects = true
        return translateValue([key], options)
    }

    /// `t` with i18next's `returnDetails`: the result plus which key, language and namespace it came from.
    public func details(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> TranslationDetails {
        translateDetails([key], options)
    }

    public func exists(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> Bool {
        let resolved = resolve([key], options)
        guard let value = resolved.value else { return false }
        return value != .null || isValidLookup(value)
    }

    /// A translate function bound to a language (or a list of them), to namespaces and to a key prefix. What a call
    /// passes itself wins; the prefix is joined to the key with the instance's `keySeparator` (`.` when it is off).
    public func getFixedT(
        lng: String? = nil,
        ns: [String]? = nil,
        keyPrefix: String? = nil,
        lngs: [String]? = nil
    ) -> FixedT {
        FixedT(i18n: self, lng: lng, lngs: lngs, ns: ns, keyPrefix: keyPrefix)
    }

    public struct FixedT: Sendable {
        let i18n: I18next
        let lng: String?
        let lngs: [String]?
        let ns: [String]?
        let keyPrefix: String?

        public func callAsFunction(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> String {
            callAsFunction([key], options)
        }

        public func callAsFunction(_ keys: [String], _ options: TranslationOptions = TranslationOptions()) -> String {
            var options = options
            options.lng = options.lng ?? lng
            options.lngs = options.lngs ?? lngs
            options.ns = options.ns ?? ns

            // `""` on the call switches the prefix off; an empty one anywhere else counts as none.
            let call = options.keyPrefix
            let prefix = call == "" ? nil : (call.flatMap { $0.isEmpty ? nil : $0 } ?? keyPrefix)
            var resolved = keys
            if let prefix, !prefix.isEmpty {
                let separator = i18n.options.keySeparator.flatMap { $0.isEmpty ? nil : $0 } ?? "."
                resolved = keys.map { "\(prefix)\(separator)\($0)" }
            }
            return i18n.translate(resolved, options)
        }
    }

    // MARK: Resources (forwarded to the store)

    public func addResourceBundle(
        lng: String,
        ns: String,
        resources: JSONValue,
        deep: Bool = false,
        overwrite: Bool = false
    ) {
        store.addResourceBundle(lng: lng, ns: ns, resources: resources, deep: deep, overwrite: overwrite)
    }

    public func hasResourceBundle(lng: String, ns: String) -> Bool {
        store.hasResourceBundle(lng: lng, ns: ns)
    }
}
