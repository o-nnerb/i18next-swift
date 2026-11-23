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

    /// The text for `keys`. See ``translateValue(_:_:)`` for objects and arrays.
    func translate(_ keys: [String], _ callOptions: TranslationOptions) -> String {
        translateCore(keys, callOptions).value.interpolationString
    }

    /// Like `translate`, but returns what the resource holds: a string, a number or boolean, and, with
    /// `returnObjects`, an object or array whose leaves are translated.
    func translateValue(_ keys: [String], _ callOptions: TranslationOptions) -> JSONValue {
        translateCore(keys, callOptions).value
    }

    func translateDetails(_ keys: [String], _ callOptions: TranslationOptions) -> TranslationDetails {
        let (value, resolved) = translateCore(keys, callOptions)
        var parameters = options.interpolation.defaultVariables
        for (name, variable) in Interpolator.data(for: callOptions, includingContext: false) {
            parameters[name] = variable
        }
        return TranslationDetails(
            result: value,
            usedKey: resolved.usedKey,
            exactUsedKey: resolved.exactUsedKey ?? resolved.usedKey,
            usedLng: resolved.usedLng,
            usedNS: resolved.usedNS,
            usedParams: parameters
        )
    }

    func translateCore(_ keys: [String], _ callOptions: TranslationOptions) -> (value: JSONValue, resolved: Resolved) {
        guard let lastKey = keys.last else { return (.string(""), Resolved(value: nil, usedKey: "")) }
        let opt = callOptions
        let (key, namespaces) = extractFromKey(lastKey, opt)
        let namespace = namespaces.last ?? ""
        let lng = opt.lng ?? language

        if lng?.lowercased() == "cimode" {
            let separator = nsSeparator(for: opt) ?? ":"
            let text = options.appendNamespaceToCIMode ? "\(namespace)\(separator)\(key)" : key
            let resolved = Resolved(value: nil, usedKey: key, exactUsedKey: key, usedLng: lng, usedNS: namespace)
            return (.string(text), resolved)
        }

        var resolved = resolve(keys, opt)
        let found = resolved.value
        let defaultValue = defaultValue(for: opt, lng: lng)
        // Either switch turns it on; a call can't turn off what the instance enabled.
        let returnObjects = (opt.returnObjects ?? false) || options.returnObjects
        let joinArrays = opt.joinArraysDisabled ? nil : (opt.joinArrays ?? options.joinArrays)
        let separator = keySeparator(for: opt)

        // An object or array: returned only with `returnObjects`, with every leaf translated in its own right.
        var holder = found
        if found?.isTruthy != true, opt.hasDefaultValue { holder = defaultValue.map(JSONValue.string) }
        let isObjectHit = holder?.isContainer == true && !(joinArrays != nil && holder?.isArray == true)

        if isObjectHit, returnObjects, let holder {
            guard let separator else { return (holder, resolved) }
            let prefixKey = holder.isArray ? (resolved.exactUsedKey ?? key) : (resolved.usedKey)
            var leaves = holder.containerEntries
            for index in leaves.indices {
                let name = leaves[index].name
                let deepKey = "\(prefixKey)\(separator)\(name)"
                var next = opt
                next.joinArraysDisabled = true
                next.ns = namespaces
                if opt.hasDefaultValue, found?.isTruthy != true { next.defaultValue = nil }
                let translated = translateValue([deepKey], next)
                leaves[index].value = translated == .string(deepKey) ? leaves[index].value : translated
            }
            return (holder.rebuilt(from: leaves), resolved)
        }

        if let joinArrays, case .array(let items)? = found {
            var joined = items.map(\.interpolationString).joined(separator: joinArrays)
            if !joined.isEmpty {
                joined = extendTranslation(joined, keys: keys, opt: opt, resolved: resolved)
            }
            return (.string(joined), resolved)
        }

        // Objects that are not returned count as missing.
        var result: JSONValue? = found
        if isObjectHit { result = nil }

        var usedDefault = false
        var usedKey = false
        if !isValidLookup(result), opt.hasDefaultValue {
            usedDefault = true
            result = defaultValue.map(JSONValue.string)
        }
        if !isValidLookup(result), !(usedDefault && result == .string("")) {
            usedKey = true
            result = .string(key)
        }

        guard let value = result else { return (.string(key), resolved) }
        guard case .string(let text) = value else { return (value, resolved) }
        resolved.value = found

        // A key that was not found (or whose text differs from the default given) is reported before interpolation.
        let updateMissing = opt.hasDefaultValue && defaultValue != text && options.updateMissing
        if !isObjectHit, usedKey || usedDefault || updateMissing {
            reportMissing(
                key: key,
                namespace: namespace,
                opt: opt,
                lng: lng,
                text: text,
                defaultValue: defaultValue,
                isUpdate: updateMissing
            )
        }

        var output = extendTranslation(text, keys: keys, opt: opt, resolved: resolved)
        let namespaceSeparator = nsSeparator(for: opt) ?? ":"
        if usedKey, output == key, options.appendNamespaceToMissingKey {
            output = "\(namespace)\(namespaceSeparator)\(key)"
        }
        if usedKey || usedDefault, let parse = options.parseMissingKeyHandler {
            let reported = options.appendNamespaceToMissingKey ? "\(namespace)\(namespaceSeparator)\(key)" : key
            output = parse(reported, usedDefault ? output : nil, opt)
        }
        return (.string(output), resolved)
    }

    // MARK: missing keys

    /// i18next's `saveMissing`: hands the key to `missingKeyHandler` (or the backend) once per language, and per plural
    /// form when `saveMissingPlurals` is on, then emits `missingKey`.
    private func reportMissing(
        key: String,
        namespace: String,
        opt: TranslationOptions,
        lng: String?,
        text: String,
        defaultValue: String?,
        isUpdate: Bool
    ) {
        guard options.saveMissing else { return }

        let current = opt.lng ?? language
        let fallbackLngs = languageUtils.fallbackCodes(options.fallbackLng, for: current)
        let languages: [String]
        switch options.saveMissingTo {
        case .fallback where !fallbackLngs.isEmpty: languages = fallbackLngs
        case .all: languages = languageUtils.hierarchy(for: current)
        default: languages = current.map { [$0] } ?? []
        }

        func send(_ targets: [String], _ missingKey: String, _ specific: String?) {
            let fallbackValue = (opt.hasDefaultValue && specific != text) ? specific : text
            let missing = MissingKey(
                languages: targets,
                namespace: namespace,
                key: missingKey,
                fallbackValue: fallbackValue,
                isUpdate: isUpdate
            )
            if let handler = options.missingKeyHandler {
                handler(missing)
            } else {
                saveMissing(missing)
            }
            hub.emit(.missingKey(missing, value: text))
        }

        guard options.saveMissingPlurals, let count = opt.count else {
            send(languages, key, defaultValue)
            return
        }

        let zeroNeeded = count == 0 && !opt.ordinal
        for language in languages {
            var categories = plurals.categories(for: language, ordinal: opt.ordinal)
            if zeroNeeded, opt.defaultValues[.zero]?.isEmpty == false, !categories.contains(.zero) {
                categories.append(.zero)
            }
            for category in categories {
                let form = opt.ordinal ? opt.ordinalDefaultValues[category] : opt.defaultValues[category]
                let suffix =
                    options.pluralSeparator + (opt.ordinal ? "ordinal" + options.pluralSeparator : "")
                    + category.rawValue
                let specific = (form?.isEmpty == false ? form : nil) ?? defaultValue
                send([language], key + suffix, specific)
            }
        }
    }

    /// Without a `missingKeyHandler`: lets the backend create the key and keeps it in the store, as i18next does.
    /// A namespace that hasn't loaded yet is not saved to: the key may exist, so reporting it would be a false alarm.
    func saveMissing(_ missing: MissingKey) {
        guard hasLoadedNamespace(missing.namespace), !missing.key.isEmpty else { return }
        connector?.create(missing)
        if let first = missing.languages.first, let value = missing.fallbackValue {
            store.addResource(lng: first, ns: missing.namespace, key: missing.key, value: .string(value))
        }
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
        let namespaces = opt.ns ?? defaultNamespaces

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
        let configured = options.ns ?? defaultNamespaces
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

    /// Interpolates and nests the text, then runs the post-processors (which also see texts that skip interpolation).
    func extendTranslation(_ text: String, keys: [String], opt: TranslationOptions, resolved: Resolved) -> String {
        let output = opt.skipInterpolation ? text : interpolate(text, keys: keys, opt: opt, usedLng: resolved.usedLng)
        return postProcess(output, keys: keys, opt: opt, resolved: resolved)
    }

    private func postProcess(_ text: String, keys: [String], opt: TranslationOptions, resolved: Resolved) -> String {
        guard opt.applyPostProcessor else { return text }
        let names = opt.postProcess ?? options.postProcess
        guard !names.isEmpty else { return text }

        let processors = state.withLock { $0.postProcessors }
        let context = PostProcessContext(
            keys: keys,
            language: opt.lng ?? language ?? resolved.usedLng,
            options: opt,
            usedKey: resolved.usedKey,
            usedLng: resolved.usedLng,
            usedNS: resolved.usedNS,
            translator: self
        )
        var result = text
        for name in names {
            guard let processor = processors[name] else { continue }
            result = processor(result, context) ?? result
        }
        return result
    }

    private func interpolate(_ text: String, keys: [String], opt: TranslationOptions, usedLng: String?) -> String {
        let interpolator = makeInterpolator(for: opt)
        let escape = opt.escapeValue ?? options.interpolation.escapeValue
        let lng = opt.lng ?? language ?? usedLng
        let formats = state.withLock { $0.formats }
        let callData = Interpolator.data(for: opt)
        let format: Interpolator.Format = { name, value, arguments, variable in
            guard let handler = formats[name], value != .null else { return nil }

            var merged = arguments
            for (key, option) in callData { merged[key] = option }
            if let call = opt.lng { merged["lng"] = .string(call) }
            var parameters: [String: JSONValue] = [:]
            if case .object(let all)? = callData["formatParams"], case .object(let own)? = all[variable] {
                parameters = own
                for (key, option) in own { merged[key] = option }
            }

            let language =
                parameters["locale"]?.stringValue ?? parameters["lng"]?.stringValue ?? merged["locale"]?.stringValue
                ?? merged["lng"]?.stringValue ?? lng
            return try? handler(value, FormatContext(language: language, options: merged, variable: variable))
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
        inherited.applyPostProcessor = false
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
