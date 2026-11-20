// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Per-call options for `I18next.t(_:_:)`.
public struct TranslationOptions: Sendable {
    /// Overrides the active language for this call.
    public var lng: String?
    /// Namespaces to search; defaults to `Options.defaultNS`.
    public var ns: [String]?
    /// Drives plural resolution and is exposed to the template as `{{count}}`.
    public var count: Double?
    public var ordinal = false
    public var context: String?
    /// Returned (and interpolated) when the key cannot be resolved.
    public var defaultValue: String?
    public var variables: [String: JSONValue] = [:]
    /// Overrides `InterpolationOptions.escapeValue`.
    public var escapeValue: Bool?
    public var skipInterpolation = false

    var nestingDepth = 0

    public init(
        lng: String? = nil,
        ns: [String]? = nil,
        count: Double? = nil,
        ordinal: Bool = false,
        context: String? = nil,
        defaultValue: String? = nil,
        variables: [String: JSONValue] = [:],
        escapeValue: Bool? = nil,
        skipInterpolation: Bool = false
    ) {
        self.lng = lng
        self.ns = ns
        self.count = count
        self.ordinal = ordinal
        self.context = context
        self.defaultValue = defaultValue
        self.variables = variables
        self.escapeValue = escapeValue
        self.skipInterpolation = skipInterpolation
    }

    /// Applies the options object of a nested `$t(key, {...})` call.
    mutating func apply(_ overrides: [String: JSONValue]) {
        for (key, value) in overrides {
            switch (key, value) {
            case ("lng", .string(let text)): lng = text
            case ("count", .number(let number)): count = number
            case ("context", .string(let text)): context = text
            case ("ns", .string(let text)): ns = [text]
            case ("defaultValue", .string(let text)): defaultValue = text
            default: variables[key] = value
            }
        }
    }
}
