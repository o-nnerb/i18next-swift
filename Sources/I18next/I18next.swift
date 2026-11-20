public final class I18next: Sendable {
    /// Custom `{{value, name(arg: x)}}` formatter. Receives the raw value, the active language and the parsed arguments.
    public typealias Format = @Sendable (_ value: JSONValue, _ lng: String?, _ arguments: [String: String]) -> String

    public struct Options: Sendable {
        public var lng: String?
        public var fallbackLng: FallbackLanguages = ["dev"]
        public var load: LoadStrategy = .all
        /// Languages to load in addition to the active one (and its fallbacks).
        public var preload: [String] = []
        public var defaultNS: [String] = ["translation"]
        /// Namespaces loaded from the backend. `defaultNS` is always included.
        public var ns: [String]?
        public var fallbackNS: [String] = []
        public var resources: ResourceStore.Resources = [:]
        public var keySeparator: String? = "."
        public var nsSeparator: String? = ":"
        public var contextSeparator = "_"
        public var pluralSeparator = "_"
        /// When false, an empty string value is treated as missing.
        public var returnEmptyString = true
        public var interpolation = InterpolationOptions()

        /// Where missing bundles are loaded from. Without one, only `resources` are available.
        public var backend: (any Backend)?
        public var backendOptions = BackendOptions()
        /// With `resources` set, the backend is ignored unless this is true (bundled resources are the whole truth).
        public var partialBundledLanguages = false

        public init() {}
    }

    struct State: Sendable {
        var language: String?
        var namespaces: [String]
        var formats: [String: Format] = [:]
        /// Bumped by every language change so an older, slower change can't override a newer one.
        var languageChangeToken = 0
    }

    public let options: Options
    public let store: ResourceStore
    let plurals: PluralResolver
    let state: Protected<State>
    let connector: BackendConnector?

    public init(_ options: Options = Options()) {
        self.options = options
        let store = ResourceStore(data: options.resources, keySeparator: options.keySeparator)
        self.store = store
        self.plurals = PluralResolver(separator: options.pluralSeparator)

        var namespaces = options.ns ?? options.defaultNS
        for ns in options.defaultNS where !namespaces.contains(ns) { namespaces.append(ns) }
        self.state = Protected(State(language: options.lng.map(LanguageUtils.format), namespaces: namespaces))

        let usesBackend = options.resources.isEmpty || options.partialBundledLanguages
        self.connector =
            usesBackend
            ? options.backend.map { BackendConnector(backend: $0, store: store, options: options.backendOptions) }
            : nil
    }

    public convenience init(configure: (inout Options) -> Void) {
        var options = Options()
        configure(&options)
        self.init(options)
    }

    // MARK: Language

    public var language: String? {
        state.withLock { $0.language }
    }

    /// Languages searched for the active language, in priority order.
    public var languages: [String] {
        LanguageUtils.hierarchy(for: language, fallback: options.fallbackLng, load: options.load)
    }

    /// Switches the language immediately, without touching the backend. Use ``changeLanguage(_:)``
    /// to load the new language's resources first.
    public func setLanguage(_ lng: String?) {
        let formatted = lng.map(LanguageUtils.format)
        state.withLock { state in
            state.languageChangeToken += 1
            state.language = formatted
        }
    }

    // MARK: Formats

    public func addFormat(_ name: String, _ format: @escaping Format) {
        state.withLock { $0.formats[name] = format }
    }

    // MARK: Translation

    public func t(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> String {
        translate(key, options)
    }

    public func exists(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> Bool {
        let (cleanKey, namespace) = extract(key)
        return resolve(cleanKey, namespace: namespace, options) != nil
    }

    /// A translate function bound to a language and/or namespaces.
    public func getFixedT(lng: String? = nil, ns: [String]? = nil) -> FixedT {
        FixedT(i18n: self, lng: lng, ns: ns)
    }

    public struct FixedT: Sendable {
        let i18n: I18next
        let lng: String?
        let ns: [String]?

        public func callAsFunction(_ key: String, _ options: TranslationOptions = TranslationOptions()) -> String {
            var options = options
            options.lng = options.lng ?? lng
            options.ns = options.ns ?? ns
            return i18n.translate(key, options)
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
