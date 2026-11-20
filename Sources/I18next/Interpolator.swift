// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

public struct InterpolationOptions: Sendable {
    /// HTML-escape interpolated values. Override per call with `TranslationOptions.escapeValue`.
    public var escapeValue = true
    public var prefix = "{{"
    public var suffix = "}}"
    /// `{{- name}}` inserts `name` without escaping.
    public var unescapePrefix = "-"
    /// `{{name-}}`: an alternative to `unescapePrefix`. When set, the prefix is ignored.
    public var unescapeSuffix = ""
    public var formatSeparator = ","
    public var nestingPrefix = "$t("
    public var nestingSuffix = ")"
    public var nestingOptionsSeparator = ","
    public var maxReplaces = 1000
    /// A variable that isn't provided leaves `{{name}}` in place (i18next's default). When false it becomes empty.
    public var skipOnVariables = true
    /// Variables available to every translation; the ones passed to `t` win.
    public var defaultVariables: [String: JSONValue] = [:]

    public init() {}
}

/// `{{variable}}` and `$t(key)` expansion, following i18next's `Interpolator`.
///
/// Interpolation is a single pass: a substituted value is never scanned again. Nesting then runs over the result.
struct Interpolator: Sendable {
    let options: InterpolationOptions
    let keySeparator: String?
    let ignoreJSONStructure: Bool

    private let unescapePrefix: String
    private let unescapeSuffix: String

    init(options: InterpolationOptions, keySeparator: String?, ignoreJSONStructure: Bool = true) {
        var normalized = options
        if normalized.prefix.isEmpty { normalized.prefix = "{{" }
        if normalized.suffix.isEmpty { normalized.suffix = "}}" }
        if normalized.formatSeparator.isEmpty { normalized.formatSeparator = "," }
        if normalized.nestingPrefix.isEmpty { normalized.nestingPrefix = "$t(" }
        if normalized.nestingSuffix.isEmpty { normalized.nestingSuffix = ")" }
        if normalized.nestingOptionsSeparator.isEmpty { normalized.nestingOptionsSeparator = "," }
        if normalized.maxReplaces <= 0 { normalized.maxReplaces = 1000 }
        self.options = normalized
        self.keySeparator = keySeparator
        self.ignoreJSONStructure = ignoreJSONStructure

        let prefix =
            options.unescapeSuffix.isEmpty ? (options.unescapePrefix.isEmpty ? "-" : options.unescapePrefix) : ""
        self.unescapePrefix = prefix
        self.unescapeSuffix = prefix.isEmpty ? options.unescapeSuffix : ""
    }

    /// Applies the formatter `name` to `value`. `arguments` are the ones written in the template
    /// (`number(minimumFractionDigits: 2)`), `variable` is the name being formatted. nil leaves the value as it is.
    typealias Format = (
        _ name: String, _ value: JSONValue, _ arguments: [String: JSONValue], _ variable: String
    ) -> JSONValue?

    // MARK: Variables

    func interpolate(_ source: String, data: [String: JSONValue], escape: Bool, format: Format) -> String {
        guard source.indexRange(of: options.prefix) != nil else { return source }

        var output = ""
        var rest = source[...]
        var replacements = 0

        while replacements < options.maxReplaces, let open = rest.indexRange(of: options.prefix) {
            output += rest[..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]

            // `(.+?)` needs at least one character, which may itself start the suffix.
            guard afterOpen.first != nil,
                let close = afterOpen.dropFirst().indexRange(of: options.suffix)
            else {
                output += rest[open.lowerBound...]
                return output
            }

            let expression = afterOpen[..<close.lowerBound]
            if expression.contains(where: \.isNewline) {
                // `.` doesn't match a line break, so the search resumes one character further on.
                output.append(rest[open.lowerBound])
                rest = rest[rest.index(after: open.lowerBound)...]
                continue
            }

            let whole = rest[open.lowerBound..<close.upperBound]
            rest = rest[close.upperBound...]

            if let replacement = replacement(for: String(expression), data: data, escape: escape, format: format) {
                output += replacement
                replacements += 1
            } else {
                output += whole
            }
        }
        output += rest
        return output
    }

    /// nil leaves the `{{…}}` text as it is.
    private func replacement(
        for expression: String,
        data: [String: JSONValue],
        escape: Bool,
        format: Format
    ) -> String? {
        var name = expression
        var unescaped = false
        if !unescapeSuffix.isEmpty {
            if name.count > unescapeSuffix.count, name.hasSuffix(unescapeSuffix) {
                name = String(name.dropLast(unescapeSuffix.count))
                unescaped = true
            }
        } else if name.count > unescapePrefix.count, name.hasPrefix(unescapePrefix) {
            name = String(name.dropFirst(unescapePrefix.count))
            unescaped = true
        }
        name = Self.trimmed(name)

        var value: JSONValue?
        if name.indexRange(of: options.formatSeparator) == nil {
            value = lookup(name, in: data)
        } else {
            var segments = name.splitKeepingEmpty(on: options.formatSeparator)
            let variable = Self.trimmed(segments.removeFirst())
            value = lookup(variable, in: data)
            if var current = value {
                for specification in Self.formatSpecifications(
                    in: segments.joined(separator: options.formatSeparator),
                    separator: options.formatSeparator
                ) {
                    let (formatName, arguments) = Self.parseFormat(specification)
                    if let formatted = format(formatName, current, arguments, variable) { current = formatted }
                }
                value = current
            }
        }

        let text: String
        if let value {
            text = value.interpolationString
        } else if options.skipOnVariables {
            return nil
        } else {
            text = ""
        }
        return escape && !unescaped ? Self.escapeHTML(text) : text
    }

    /// i18next's `deepFindWithDefaults`: the nested path first, then keys that contain the separator.
    func lookup(_ key: String, in data: [String: JSONValue]) -> JSONValue? {
        let defaults = options.defaultVariables
        let path = key.splitKeepingEmpty(on: ".")

        var found = JSONValue.object(data).value(at: path)
        if found == nil { found = JSONValue.object(defaults).value(at: path) }

        if found == nil || found == .null, ignoreJSONStructure {
            found = ResourceStore.deepFind(.object(data), key, separator: keySeparator)
            if found == nil { found = ResourceStore.deepFind(.object(defaults), key, separator: keySeparator) }
        }
        return found
    }

    // MARK: Nesting

    /// Number of `$t(...)` expressions in `text`.
    func nestingCount(in text: String) -> Int {
        var count = 0
        var cursor = text.startIndex
        while let match = nextNesting(in: text, from: cursor) {
            count += 1
            cursor = match.whole.upperBound
        }
        return count
    }

    /// Expands `$t(key, {options})`. `translate` receives the key and the options inherited from the call that
    /// contains the expression, overlaid with the ones written in it.
    func nest(
        _ source: String,
        options call: TranslationOptions,
        escape: Bool,
        translate: (String, TranslationOptions) -> String,
        format: Format
    ) -> String {
        guard source.indexRange(of: options.nestingPrefix) != nil else { return source }

        var output = ""
        var cursor = source.startIndex
        var lastEnd: String.Index?

        while let match = nextNesting(in: source, from: cursor) {
            var cloned = call
            cloned.defaultValue = nil

            var content = String(source[match.content])
            var formatters: [String] = []
            if let keyEnd = formatterStart(in: content) {
                formatters = content[keyEnd...].splitKeepingEmpty(on: options.formatSeparator)
                    .map(Self.trimmed).filter { !$0.isEmpty }
                content = String(content[..<keyEnd])
            }

            let key = keyAndOptions(Self.trimmed(content), cloned: &cloned, escape: escape, format: format)
            var value = translate(key, cloned)
            if !formatters.isEmpty {
                let variable = Self.trimmed(key)
                value = formatters.reduce(Self.trimmed(value)) { current, specification in
                    let (formatName, arguments) = Self.parseFormat(specification)
                    return format(formatName, .string(current), arguments, variable)?.interpolationString ?? current
                }
            }

            output += source[(lastEnd ?? source.startIndex)..<match.whole.lowerBound]
            output += value
            lastEnd = match.whole.upperBound
            cursor = match.whole.upperBound
        }
        guard let lastEnd else { return source }
        return output + source[lastEnd...]
    }

    /// Splits `key, {"a": 1}` into the key and its options (written as JSON, single quotes tolerated), merging the
    /// options into `cloned`. When they don't parse, the whole text stays in the key, as in i18next.
    private func keyAndOptions(
        _ text: String,
        cloned: inout TranslationOptions,
        escape: Bool,
        format: Format
    ) -> String {
        let separator = options.nestingOptionsSeparator
        guard text.indexRange(of: separator) != nil else { return text }

        let pieces = splitAtOptionsStart(text)
        var optionsText = "{" + (pieces.count > 1 ? pieces[1] : "undefined")
        let key = pieces[0]

        optionsText = interpolate(optionsText, data: Self.data(for: cloned), escape: escape, format: format)

        let singles = optionsText.filter { $0 == "'" }.count
        let doubles = optionsText.filter { $0 == "\"" }.count
        if (singles % 2 == 0 && doubles == 0) || doubles % 2 != 0 {
            optionsText = String(optionsText.map { $0 == "'" ? "\"" : $0 })
        }

        guard case .object(let parsed)? = try? JSONValue(json: optionsText) else {
            return key + separator + optionsText
        }
        cloned.apply(parsed)
        if let defaultValue = cloned.defaultValue, defaultValue.indexRange(of: options.prefix) != nil {
            cloned.defaultValue = nil
        }
        return key
    }

    /// Splits at every `separator`, optional spaces, then `{`: i18next's `key.split(/,[ ]*{/)`.
    private func splitAtOptionsStart(_ text: String) -> [String] {
        let separator = options.nestingOptionsSeparator
        var pieces: [String] = []
        var current = ""
        var rest = text[...]

        while let range = rest.indexRange(of: separator) {
            var after = rest[range.upperBound...]
            while after.first == " " { after = after.dropFirst() }
            if after.first == "{" {
                current += rest[..<range.lowerBound]
                pieces.append(current)
                current = ""
                rest = after.dropFirst()
            } else {
                current += rest[..<range.upperBound]
                rest = rest[range.upperBound...]
            }
        }
        pieces.append(current + rest)
        return pieces
    }

    /// Where formatters start after the key: after the closing `}` of an options object, else at the first
    /// format separator.
    private func formatterStart(in content: String) -> String.Index? {
        if let open = content.firstIndex(of: "{"), let close = content.lastIndex(of: "}"), open < close {
            return content.index(after: close)
        }
        return content.indexRange(of: options.formatSeparator)?.lowerBound
    }

    private struct NestingMatch {
        let whole: Range<String.Index>
        let content: Range<String.Index>
    }

    /// The next `$t(…)`: content is any text, quoted strings and one level of parentheses, up to the first suffix.
    private func nextNesting(in text: String, from start: String.Index) -> NestingMatch? {
        var search = start
        while let prefix = text[search...].indexRange(of: options.nestingPrefix) {
            if let match = matchNesting(in: text, prefix: prefix) { return match }
            search = text.index(after: prefix.lowerBound)
        }
        return nil
    }

    private func matchNesting(in text: String, prefix: Range<String.Index>) -> NestingMatch? {
        let contentStart = prefix.upperBound
        var index = contentStart

        while index < text.endIndex {
            if text[index...].hasPrefix(options.nestingSuffix) {
                let end = text.index(index, offsetBy: options.nestingSuffix.count)
                return NestingMatch(whole: prefix.lowerBound..<end, content: contentStart..<index)
            }
            let character = text[index]
            switch character {
            case "\"", "'":
                guard let closing = text[text.index(after: index)...].firstIndex(of: character) else { return nil }
                index = text.index(after: closing)
            case "(":
                guard let after = skipParenthesisGroup(in: text, openingAt: index) else { return nil }
                index = after
            default:
                index = text.index(after: index)
            }
        }
        return nil
    }

    /// `( … )` holding no other parentheses, with quoted strings allowed inside.
    private func skipParenthesisGroup(in text: String, openingAt open: String.Index) -> String.Index? {
        var index = text.index(after: open)
        while index < text.endIndex {
            let character = text[index]
            switch character {
            case ")":
                return text.index(after: index)
            case "(":
                return nil
            case "\"", "'":
                guard let closing = text[text.index(after: index)...].firstIndex(of: character) else { return nil }
                index = text.index(after: closing)
            default:
                index = text.index(after: index)
            }
        }
        return nil
    }

    // MARK: Helpers

    /// The data a template sees: the variables, plus what i18next exposes from the call options themselves.
    static func data(for call: TranslationOptions, includingContext: Bool = true) -> [String: JSONValue] {
        var data = call.variables
        if let count = call.count { data["count"] = .number(count) }
        if includingContext, let context = call.context { data["context"] = .string(context) }
        return data
    }

    /// Splits a chain of formats (`number, uppercase`), keeping a format whose parentheses contain the separator
    /// (`number(a: 1, b: 2)`) in one piece.
    static func formatSpecifications(in text: String, separator: String) -> [String] {
        let raw = text.splitKeepingEmpty(on: separator)
        var specifications: [String] = []
        var index = 0
        while index < raw.count {
            var current = raw[index]
            while current.contains("("), !current.contains(")"), index + 1 < raw.count {
                index += 1
                current += separator + raw[index]
            }
            let trimmedSpecification = trimmed(current)
            if !trimmedSpecification.isEmpty { specifications.append(trimmedSpecification) }
            index += 1
        }
        return specifications
    }

    /// `number(minimumFractionDigits: 2; maximumFractionDigits: 3)` → ("number", [...]). Names are case-insensitive.
    /// Values are typed like i18next does: `true`/`false` become booleans and numbers become numbers; `currency(EUR)`
    /// and `relativetime(hour)` are shorthands for `currency: EUR` and `range: hour`.
    static func parseFormat(_ specification: String) -> (String, [String: JSONValue]) {
        guard let open = specification.firstIndex(of: "(") else {
            return (trimmed(specification).lowercased(), [:])
        }
        let name = trimmed(specification[..<open]).lowercased()
        var inner = specification[specification.index(after: open)...]
        if inner.last != nil { inner = inner.dropLast() }  // the closing parenthesis

        let text = String(inner)
        if name == "currency", !text.contains(":") { return (name, ["currency": .string(trimmed(text))]) }
        if name == "relativetime", !text.contains(":") { return (name, ["range": .string(trimmed(text))]) }

        var arguments: [String: JSONValue] = [:]
        for pair in text.split(separator: ";") {
            guard let colon = pair.firstIndex(of: ":") else { continue }
            let key = trimmed(pair[..<colon])
            var raw = trimmed(pair[pair.index(after: colon)...])
            while raw.hasPrefix("'") { raw.removeFirst() }
            while raw.hasSuffix("'") { raw.removeLast() }

            if raw == "true" {
                arguments[key] = .bool(true)
            } else if raw == "false" {
                arguments[key] = .bool(false)
            } else if !raw.isEmpty, Double(raw) != nil {
                arguments[key] = .number(Double(leadingInteger(raw)))  // `parseInt`: "1.5" is 1
            } else if arguments[key] == nil {
                arguments[key] = .string(raw)
            }
        }
        return (name, arguments)
    }

    /// JavaScript's `parseInt(text, 10)` for text that is a number: the integer digits it starts with.
    private static func leadingInteger(_ text: String) -> Int {
        var digits = ""
        for (offset, character) in text.enumerated() {
            if character.isASCII, character.isNumber || (offset == 0 && (character == "-" || character == "+")) {
                digits.append(character)
            } else {
                break
            }
        }
        return Int(digits) ?? 0
    }

    static func trimmed(_ text: some StringProtocol) -> String {
        var slice = Substring(text)
        while let first = slice.first, first.isWhitespace { slice = slice.dropFirst() }
        while let last = slice.last, last.isWhitespace { slice = slice.dropLast() }
        return String(slice)
    }

    /// `& < > " '`. (i18next 27 no longer escapes `/`.)
    static func escapeHTML(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }
}
