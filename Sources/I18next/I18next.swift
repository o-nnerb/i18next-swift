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
        var state = State(language: options.lng.map(languageUtils.format), namespaces: namespaces)
        for (name, format) in options.formats { state.formats[Self.formatName(name)] = format }
        state.postProcessors = options.postProcessors
        self.state = Protected(state)

        let usesBackend = options.resources.isEmpty || options.partialBundledLanguages
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

    /// Switches the language immediately, without touching the backend. Use ``changeLanguage(_:)``
    /// to load the new language's resources first.
    public func setLanguage(_ lng: String?) {
        let formatted = lng.map(languageUtils.format)
        state.withLock { state in
            state.languageChangeToken += 1
            state.language = formatted
        }
        hub.emit(.languageChanged(formatted))
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
            return i18n.translate([key], options)
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
