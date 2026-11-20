extension I18next {
    struct Resolved {
        let value: JSONValue
        let lng: String
        let ns: String
    }

    func translate(_ rawKey: String, _ callOptions: TranslationOptions) -> String {
        let (key, namespace) = extract(rawKey)
        let lng = requestedLanguage(callOptions)

        if let found = resolve(key, namespace: namespace, callOptions),
            case .string(let template) = found.value
        {
            return render(template, callOptions, lng: lng)
        }
        if let defaultValue = callOptions.defaultValue {
            return render(defaultValue, callOptions, lng: lng)
        }
        return key
    }

    // MARK: Lookup

    func resolve(_ key: String, namespace: String?, _ callOptions: TranslationOptions) -> Resolved? {
        let codes = LanguageUtils.hierarchy(
            for: requestedLanguage(callOptions),
            fallback: options.fallbackLng,
            load: options.load
        )

        var namespaces = namespace.map { [$0] } ?? callOptions.ns ?? options.defaultNS
        for fallback in options.fallbackNS where !namespaces.contains(fallback) {
            namespaces.append(fallback)
        }

        for code in codes {
            let candidates = candidateKeys(key, lng: code, callOptions)
            for ns in namespaces {
                // Most specific candidate first.
                for candidate in candidates.reversed() {
                    guard let value = store.getResource(lng: code, ns: ns, key: candidate) else { continue }
                    if case .null = value { continue }
                    if case .string("") = value, !options.returnEmptyString { continue }
                    return Resolved(value: value, lng: code, ns: ns)
                }
            }
        }
        return nil
    }

    /// Keys ordered from least to most specific, mirroring i18next:
    /// `key`, `key_<plural>`, `key_zero`, `key_<context>`, `key_<context>_<plural>`, `key_<context>_zero`.
    func candidateKeys(_ key: String, lng: String, _ callOptions: TranslationOptions) -> [String] {
        var pluralSuffix: String?
        var zeroSuffix: String?
        if let count = callOptions.count {
            pluralSuffix = plurals.suffix(for: count, lng: lng, ordinal: callOptions.ordinal)
            if count == 0, !callOptions.ordinal { zeroSuffix = options.pluralSeparator + "zero" }
        }

        func variants(of base: String) -> [String] {
            var keys = [base]
            if let pluralSuffix { keys.append(base + pluralSuffix) }
            if let zeroSuffix { keys.append(base + zeroSuffix) }
            return keys
        }

        var keys = variants(of: key)
        if let context = callOptions.context, !context.isEmpty {
            keys += variants(of: key + options.contextSeparator + context)
        }
        return keys
    }

    /// Splits `ns:key`. Prefixes containing whitespace are treated as plain text, not a namespace.
    func extract(_ rawKey: String) -> (key: String, namespace: String?) {
        guard let separator = options.nsSeparator, !separator.isEmpty,
            let range = rawKey.indexRange(of: separator)
        else {
            return (rawKey, nil)
        }
        let prefix = String(rawKey[..<range.lowerBound])
        if prefix.contains(where: \.isWhitespace) { return (rawKey, nil) }
        if separator == options.keySeparator, !options.defaultNS.contains(prefix) { return (rawKey, nil) }
        return (String(rawKey[range.upperBound...]), prefix)
    }

    func requestedLanguage(_ callOptions: TranslationOptions) -> String? {
        callOptions.lng.map(LanguageUtils.format) ?? language
    }

    // MARK: Rendering

    func render(_ template: String, _ callOptions: TranslationOptions, lng: String?) -> String {
        if callOptions.skipInterpolation { return template }

        var variables = callOptions.variables
        if let count = callOptions.count { variables["count"] = .number(count) }
        if let context = callOptions.context { variables["context"] = .string(context) }

        let formats = state.withLock { $0.formats }
        let escape = callOptions.escapeValue ?? options.interpolation.escapeValue

        return Interpolator(options: options.interpolation).interpolate(
            template,
            variables: variables,
            escape: escape,
            format: { name, value, arguments in
                formats[name]?(value, lng, arguments)
            },
            nest: { key, overrides in
                guard callOptions.nestingDepth < 10 else { return "" }
                var nested = callOptions
                nested.nestingDepth += 1
                nested.defaultValue = nil
                nested.apply(overrides)
                return self.translate(key, nested)
            }
        )
    }
}
