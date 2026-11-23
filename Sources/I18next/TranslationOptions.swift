// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Per-call options for `I18next.t(_:_:)`.
public struct TranslationOptions: Sendable {
    /// Overrides the active language for this call.
    public var lng: String?
    /// Languages to try, in order, instead of the resolved hierarchy (no fallbacks are added).
    public var lngs: [String]?
    /// Overrides `Options.fallbackLng` for this call; `.none` is `fallbackLng: false`.
    public var fallbackLng: FallbackLanguages?
    /// Namespaces to search; defaults to `Options.defaultNS`.
    public var ns: [String]?
    /// Drives plural resolution and is exposed to the template as `{{count}}`.
    public var count: Double?
    public var ordinal = false
    public var context: String?
    /// Returned (and interpolated) when the key cannot be resolved.
    public var defaultValue: String?
    /// Default values per plural category (i18next's `defaultValue_one`, `defaultValue_other`, …).
    public var defaultValues: [PluralCategory: String] = [:]
    /// Default values per ordinal category (`defaultValue_ordinal_one`, …).
    public var ordinalDefaultValues: [PluralCategory: String] = [:]
    public var variables: [String: JSONValue] = [:]
    /// Overrides `InterpolationOptions.escapeValue`.
    public var escapeValue: Bool?
    public var skipInterpolation = false
    public var keySeparator: SeparatorSetting?
    public var nsSeparator: SeparatorSetting?
    public var ignoreJSONStructure: Bool?
    /// Overrides ``I18next/Options/returnObjects``; see ``I18next/object(_:_:)``.
    public var returnObjects: Bool?
    /// Joins an array resource into one string with this separator (`""` joins with nothing).
    public var joinArrays: String?
    /// Post-processors for this call, replacing ``I18next/Options/postProcess``. `[]` applies none.
    public var postProcess: [String]?
    /// Prefixes the key (`prefix.key`) in a function from ``I18next/getFixedT(lng:ns:keyPrefix:lngs:)``, replacing the
    /// one it was created with; `""` switches it off for the call. `I18next.t` itself ignores it, as in i18next.
    public var keyPrefix: String?
    /// Overrides ``I18next/Options/missingInterpolationHandler`` for this call.
    public var missingInterpolationHandler: I18next.MissingInterpolationHandler?
    /// Turns on ``I18next/Options/missingKeyNoValueFallbackToKey`` for this call; `false` doesn't turn it off.
    public var missingKeyNoValueFallbackToKey: Bool?

    var nestingDepth = 0
    /// Cleared for nested `$t(...)` translations: the text they are part of is post-processed once, as a whole.
    var applyPostProcessor = true
    /// Set while translating the entries of an array, which must not be joined again.
    var joinArraysDisabled = false
    /// Set on the options of a nested `$t(...)` call: the key whose template contained it.
    var lastKey: String?

    public init(
        lng: String? = nil,
        lngs: [String]? = nil,
        fallbackLng: FallbackLanguages? = nil,
        ns: [String]? = nil,
        count: Double? = nil,
        ordinal: Bool = false,
        context: String? = nil,
        defaultValue: String? = nil,
        defaultValues: [PluralCategory: String] = [:],
        ordinalDefaultValues: [PluralCategory: String] = [:],
        variables: [String: JSONValue] = [:],
        escapeValue: Bool? = nil,
        skipInterpolation: Bool = false,
        keySeparator: SeparatorSetting? = nil,
        nsSeparator: SeparatorSetting? = nil,
        ignoreJSONStructure: Bool? = nil,
        returnObjects: Bool? = nil,
        joinArrays: String? = nil,
        postProcess: [String]? = nil,
        keyPrefix: String? = nil,
        missingInterpolationHandler: I18next.MissingInterpolationHandler? = nil,
        missingKeyNoValueFallbackToKey: Bool? = nil
    ) {
        self.lng = lng
        self.lngs = lngs
        self.fallbackLng = fallbackLng
        self.ns = ns
        self.count = count
        self.ordinal = ordinal
        self.context = context
        self.defaultValue = defaultValue
        self.defaultValues = defaultValues
        self.ordinalDefaultValues = ordinalDefaultValues
        self.variables = variables
        self.escapeValue = escapeValue
        self.skipInterpolation = skipInterpolation
        self.keySeparator = keySeparator
        self.nsSeparator = nsSeparator
        self.ignoreJSONStructure = ignoreJSONStructure
        self.returnObjects = returnObjects
        self.joinArrays = joinArrays
        self.postProcess = postProcess
        self.keyPrefix = keyPrefix
        self.missingInterpolationHandler = missingInterpolationHandler
        self.missingKeyNoValueFallbackToKey = missingKeyNoValueFallbackToKey
    }

    var hasDefaultValue: Bool {
        defaultValue != nil || !defaultValues.isEmpty || !ordinalDefaultValues.isEmpty
    }

    /// Applies the options object of a nested `$t(key, {...})` call.
    mutating func apply(_ overrides: [String: JSONValue]) {
        for (key, value) in overrides {
            switch (key, value) {
            case ("lng", .string(let text)): lng = text
            case ("count", .number(let number)): count = number
            case ("context", _): context = value.interpolationString
            case ("ns", .string(let text)): ns = [text]
            case ("defaultValue", .string(let text)): defaultValue = text
            case ("ordinal", .bool(let flag)): ordinal = flag
            case ("returnObjects", .bool(let flag)): returnObjects = flag
            case ("joinArrays", .string(let text)): joinArrays = text
            case ("keySeparator", .string(let text)): keySeparator = .custom(text)
            case ("keySeparator", .bool(false)): keySeparator = .disabled
            case ("nsSeparator", .string(let text)): nsSeparator = .custom(text)
            case ("nsSeparator", .bool(false)): nsSeparator = .disabled
            default: variables[key] = value
            }
        }
    }
}

/// A separator setting that can be switched off: i18next's `keySeparator: false` / `nsSeparator: false`.
public enum SeparatorSetting: Sendable, Hashable, ExpressibleByStringLiteral {
    case disabled
    case custom(String)

    public init(stringLiteral value: String) { self = .custom(value) }

    var value: String? {
        if case .custom(let text) = self { return text }
        return nil
    }
}

/// What `I18next.details(_:_:)` reports about a lookup (i18next's `returnDetails`).
public struct TranslationDetails: Sendable {
    public let result: JSONValue
    public let usedKey: String
    public let exactUsedKey: String
    public let usedLng: String?
    public let usedNS: String?
    /// The variables the translation could use: `defaultVariables`, the call's variables and `count`.
    public let usedParams: [String: JSONValue]
}
