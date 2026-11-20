// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

extension I18next {
    struct Resolved {
        var value: JSONValue?
        var usedKey: String
        var exactUsedKey: String?
        var usedLng: String?
        var usedNS: String?
    }

    // MARK: translate

    func translate(_ keys: [String], _ callOptions: TranslationOptions) -> String {
        guard let lastKey = keys.last else { return "" }
        let opt = callOptions
        let (key, namespaces) = extractFromKey(lastKey, opt)
        let namespace = namespaces.last ?? ""
        let lng = opt.lng ?? language

        if lng?.lowercased() == "cimode" {
            let separator = nsSeparator(for: opt) ?? ":"
            return options.appendNamespaceToCIMode ? "\(namespace)\(separator)\(key)" : key
        }

        let resolved = resolve(keys, opt)
        let defaultValue = defaultValue(for: opt, lng: lng)

        // Objects are not returned (`returnObjects` is off), and a number or boolean reads as its text.
        var found: JSONValue? = resolved.value
        if let value = found, value.isContainer { found = nil }

        var result: String?
        var usedDefault = false
        if let value = found, isValidLookup(value) { result = value.interpolationString }

        if result == nil, opt.hasDefaultValue {
            usedDefault = true
            result = defaultValue
        }
        if result == nil || (result == "" && !options.returnEmptyString && !(usedDefault)) {
            result = key
        }

        guard let text = result else { return key }
        return extendTranslation(text, keys: keys, opt: opt, usedLng: resolved.usedLng)
    }

    /// i18next's default value rules: `defaultValue_zero`, then the category (and for ordinals the cardinal
    /// category), then `defaultValue`, then the `other` form.
    func defaultValue(for opt: TranslationOptions, lng: String?) -> String? {
        func present(_ text: String?) -> String? { text?.isEmpty == false ? text : nil }

        guard let count = opt.count else { return opt.defaultValue }
        let code = lng ?? "dev"
        let category = plurals.category(for: count, lng: code, ordinal: opt.ordinal)
        let cardinal = plurals.category(for: count, lng: code, ordinal: false)

        if count == 0, !opt.ordinal, let zero = present(opt.defaultValues[.zero]) { return zero }
        if let form = present(opt.ordinal ? opt.ordinalDefaultValues[category] : opt.defaultValues[category]) {
            return form
        }
        if opt.ordinal, let form = present(opt.defaultValues[cardinal]) { return form }
        if let plain = opt.defaultValue { return plain }
        return opt.ordinal ? opt.ordinalDefaultValues[.other] : opt.defaultValues[.other]
    }

    func isValidLookup(_ value: JSONValue?) -> Bool {
        switch value {
        case nil, .null?: return false
        case .string("")?: return options.returnEmptyString
        default: return true
        }
    }

    // MARK: keys and namespaces

    private func nsSeparator(for opt: TranslationOptions) -> String? {
        if let override = opt.nsSeparator { return override.value }
        return options.nsSeparator
    }

    private func keySeparator(for opt: TranslationOptions) -> String? {
        if let override = opt.keySeparator { return override.value }
        return options.keySeparator
    }

    /// Splits `ns:key`. A key that reads like a sentence is left alone unless separators were set on purpose.
    func extractFromKey(_ key: String, _ opt: TranslationOptions) -> (key: String, namespaces: [String]) {
        let nsSeparator = nsSeparator(for: opt)
        let keySeparator = keySeparator(for: opt)
        let namespaces = opt.ns ?? options.defaultNS

        let wouldCheckForNsInKey = nsSeparator.map { !$0.isEmpty && key.indexRange(of: $0) != nil } ?? false
        let seemsNaturalLanguage =
            !options.userDefinedKeySeparator && opt.keySeparator == nil && !options.userDefinedNsSeparator
            && opt.nsSeparator == nil
            && !Self.looksLikeObjectPath(key, nsSeparator: nsSeparator, keySeparator: keySeparator)

        guard wouldCheckForNsInKey, !seemsNaturalLanguage, let nsSeparator else { return (key, namespaces) }

        let interpolator = makeInterpolator(for: opt)
        if interpolator.nestingCount(in: key) > 0 { return (key, namespaces) }

        var parts = key.splitKeepingEmpty(on: nsSeparator)
        var resultNamespaces = namespaces
        let configured = options.ns ?? options.defaultNS
        if nsSeparator != keySeparator || (nsSeparator == keySeparator && configured.contains(parts[0])) {
            resultNamespaces = [parts.removeFirst()]
        }
        return (parts.joined(separator: keySeparator ?? nsSeparator), resultNamespaces)
    }

    /// i18next's heuristic: a key containing none of ` ,?!;` (other than the separators) is a path, not a sentence.
    static func looksLikeObjectPath(_ key: String, nsSeparator: String?, keySeparator: String?) -> Bool {
        let namespaceSeparator = nsSeparator ?? ""
        let keySeparator = keySeparator ?? ""
        let possible: [Character] = [" ", ",", "?", "!", ";"].filter {
            !namespaceSeparator.contains($0) && !keySeparator.contains($0)
        }
        if possible.isEmpty { return true }

        var matched = !key.contains(where: { possible.contains($0) })
        if !matched, !keySeparator.isEmpty, let range = key.indexRange(of: keySeparator),
            range.lowerBound > key.startIndex
        {
            matched = !key[..<range.lowerBound].contains(where: { possible.contains($0) })
        }
        return matched
    }

    // MARK: resolve

    func resolve(_ keys: [String], _ opt: TranslationOptions) -> Resolved {
        var resolved = Resolved(value: nil, usedKey: keys.last ?? "")

        for rawKey in keys {
            if isValidLookup(resolved.value) { break }
            let extracted = extractFromKey(rawKey, opt)
            let key = extracted.key
            resolved.usedKey = key

            var namespaces = extracted.namespaces
            for fallback in options.fallbackNS { namespaces.append(fallback) }

            let codes = opt.lngs ?? languageUtils.hierarchy(for: opt.lng ?? language, fallback: opt.fallbackLng)

            for namespace in namespaces {
                if isValidLookup(resolved.value) { break }
                resolved.usedNS = namespace

                for code in codes {
                    if isValidLookup(resolved.value) { break }
                    resolved.usedLng = code

                    var candidates = candidateKeys(for: key, code: code, opt)
                    // `while (possibleKey = finalKeys.pop())`: an empty key ends the search.
                    while let possible = candidates.popLast(), !possible.isEmpty {
                        if !isValidLookup(resolved.value) {
                            resolved.exactUsedKey = possible
                            resolved.value = store.getResource(
                                lng: code,
                                ns: namespace,
                                key: possible,
                                keySeparator: opt.keySeparator,
                                ignoreJSONStructure: opt.ignoreJSONStructure
                            )
                        }
                    }
                }
            }
        }
        return resolved
    }

    /// Keys from least to most specific; the search pops from the end.
    func candidateKeys(for key: String, code: String, _ opt: TranslationOptions) -> [String] {
        let separator = options.pluralSeparator
        let zeroSuffix = separator + "zero"
        let ordinalPrefix = separator + "ordinal" + separator
        let contextSeparator = options.contextSeparator.isEmpty ? "_" : options.contextSeparator

        var keys = [key]
        let plural = opt.count != nil
        let zero = plural && !opt.ordinal && opt.count == 0
        let contextual = opt.context?.isEmpty == false

        var pluralSuffix = ""
        if let count = opt.count {
            pluralSuffix = plurals.suffix(for: count, lng: code, ordinal: opt.ordinal)
        }
        /// The cardinal spelling of an ordinal suffix (`_ordinal_one` → `_one`), tried right before it.
        func cardinalForm(of suffix: String) -> String? {
            opt.ordinal && suffix.hasPrefix(ordinalPrefix) ? separator + suffix.dropFirst(ordinalPrefix.count) : nil
        }

        if plural {
            if let cardinal = cardinalForm(of: pluralSuffix) { keys.append(key + cardinal) }
            keys.append(key + pluralSuffix)
            if zero { keys.append(key + zeroSuffix) }
        }
        if contextual, let context = opt.context {
            let contextKey = "\(key)\(contextSeparator)\(context)"
            keys.append(contextKey)
            if plural {
                if let cardinal = cardinalForm(of: pluralSuffix) { keys.append(contextKey + cardinal) }
                keys.append(contextKey + pluralSuffix)
                if zero { keys.append(contextKey + zeroSuffix) }
            }
        }
        if plural {
            let otherSuffix = (opt.ordinal ? ordinalPrefix : separator) + "other"
            if pluralSuffix != otherSuffix {
                if contextual, let context = opt.context {
                    keys.insert("\(key)\(contextSeparator)\(context)\(otherSuffix)", at: 0)
                }
                keys.insert(key + otherSuffix, at: 0)
            }
        }
        return keys
    }

    // MARK: interpolation and nesting

    func makeInterpolator(for opt: TranslationOptions) -> Interpolator {
        var interpolation = options.interpolation
        if let escape = opt.escapeValue { interpolation.escapeValue = escape }
        return Interpolator(
            options: interpolation,
            keySeparator: options.keySeparator,
            ignoreJSONStructure: true
        )
    }

    func extendTranslation(_ text: String, keys: [String], opt: TranslationOptions, usedLng: String?) -> String {
        if opt.skipInterpolation { return text }

        let interpolator = makeInterpolator(for: opt)
        let escape = opt.escapeValue ?? options.interpolation.escapeValue
        let lng = opt.lng ?? language ?? usedLng
        let formats = state.withLock { $0.formats }
        let format: Interpolator.Format = { name, value, arguments in
            formats[name]?(value, lng, arguments)
        }

        let nestedBefore = options.interpolation.skipOnVariables ? interpolator.nestingCount(in: text) : 0
        var result = interpolator.interpolate(
            text,
            data: Interpolator.data(for: opt),
            escape: escape,
            format: format
        )

        // A value that brings its own `$t(...)` into the text switches nesting off for it.
        if options.interpolation.skipOnVariables, nestedBefore < interpolator.nestingCount(in: result) {
            return result
        }

        var inherited = opt
        if inherited.lng == nil { inherited.lng = language ?? usedLng }
        let currentKey = keys.last

        result = interpolator.nest(
            result,
            options: inherited,
            escape: escape,
            translate: { key, nested in
                // A key reached again from the key it was nested in ends the recursion (`a` → `b` → `a`).
                if opt.lastKey == key, opt.context == nil { return "" }
                guard opt.nestingDepth < 10 else { return "" }
                var next = nested
                next.nestingDepth = opt.nestingDepth + 1
                next.lastKey = currentKey
                return self.translate([key], next)
            },
            format: format
        )
        return result
    }
}
