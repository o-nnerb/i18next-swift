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

    var nestingDepth = 0
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
        ignoreJSONStructure: Bool? = nil
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
