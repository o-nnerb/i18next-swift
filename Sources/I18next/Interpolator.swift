public struct InterpolationOptions: Sendable {
    /// HTML-escape interpolated values. Override per call with `TranslationOptions.escapeValue`.
    public var escapeValue = true
    public var prefix = "{{"
    public var suffix = "}}"
    /// `{{- name}}` inserts `name` without escaping.
    public var unescapePrefix = "-"
    public var formatSeparator = ","
    public var nestingPrefix = "$t("
    public var nestingSuffix = ")"
    public var nestingOptionsSeparator = ","
    public var maxReplaces = 1000

    public init() {}
}

/// Single-pass `{{variable}}` / `$t(key)` expander.
///
/// Substituted values are never scanned again, so a variable that contains `{{x}}` or `$t(y)` is inserted literally.
struct Interpolator: Sendable {
    var options: InterpolationOptions

    typealias Format = (_ name: String, _ value: JSONValue, _ arguments: [String: String]) -> String?
    typealias Nest = (_ key: String, _ options: [String: JSONValue]) -> String

    func interpolate(
        _ source: String,
        variables: [String: JSONValue],
        escape: Bool,
        format: Format,
        nest: Nest
    ) -> String {
        var output = ""
        var rest = source[...]
        var replacements = 0

        while replacements < options.maxReplaces {
            let variable = rest.indexRange(of: options.prefix)
            let nesting = rest.indexRange(of: options.nestingPrefix)

            let isNesting: Bool
            let token: Range<Substring.Index>
            switch (variable, nesting) {
            case (nil, nil):
                output += rest
                return output
            case let (variable?, nil):
                (isNesting, token) = (false, variable)
            case let (nil, nesting?):
                (isNesting, token) = (true, nesting)
            case let (variable?, nesting?):
                (isNesting, token) =
                    variable.lowerBound <= nesting.lowerBound
                    ? (false, variable) : (true, nesting)
            }

            output += rest[..<token.lowerBound]
            let after = rest[token.upperBound...]

            if isNesting {
                guard let close = closingNestingRange(in: after) else {
                    output += rest[token.lowerBound...]
                    return output
                }
                output += expandNesting(after[..<close.lowerBound], nest: nest)
                rest = after[close.upperBound...]
            } else {
                guard let close = after.indexRange(of: options.suffix) else {
                    output += rest[token.lowerBound...]
                    return output
                }
                output += expandVariable(
                    after[..<close.lowerBound],
                    variables: variables,
                    escape: escape,
                    format: format
                )
                rest = after[close.upperBound...]
            }
            replacements += 1
        }

        output += rest
        return output
    }

    // MARK: Variables

    private func expandVariable(
        _ expression: Substring,
        variables: [String: JSONValue],
        escape: Bool,
        format: Format
    ) -> String {
        var expression = Self.trimmed(expression)
        var shouldEscape = escape
        if expression.hasPrefix(options.unescapePrefix) {
            expression = Self.trimmed(expression.dropFirst(options.unescapePrefix.count))
            shouldEscape = false
        }

        var segments =
            expression
            .splitKeepingEmpty(on: options.formatSeparator)
            .map { Self.trimmed($0) }
        let name = segments.removeFirst()

        var value = Self.lookup(name, in: variables) ?? .null
        var text = value.interpolationString

        for spec in segments where !spec.isEmpty {
            let (formatName, arguments) = Self.parseFormat(spec)
            if let formatted = format(formatName, value, arguments) {
                text = formatted
                value = .string(formatted)
            }
        }

        return shouldEscape ? Self.escapeHTML(text) : text
    }

    private static func lookup(_ name: String, in variables: [String: JSONValue]) -> JSONValue? {
        if let direct = variables[name] { return direct }
        guard name.contains(".") else { return nil }
        let path = name.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        return JSONValue.object(variables).value(at: path)
    }

    /// `number(minimumFractionDigits: 2; maximumFractionDigits: 3)` → ("number", [...])
    private static func parseFormat(_ spec: String) -> (String, [String: String]) {
        guard let open = spec.firstIndex(of: "("), spec.hasSuffix(")") else { return (spec, [:]) }
        let name = trimmed(spec[..<open])
        let inner = spec[spec.index(after: open)..<spec.index(before: spec.endIndex)]

        var arguments: [String: String] = [:]
        for pair in inner.split(separator: ";") {
            guard let colon = pair.firstIndex(of: ":") else { continue }
            arguments[trimmed(pair[..<colon])] = trimmed(pair[pair.index(after: colon)...])
        }
        return (name, arguments)
    }

    // MARK: Nesting

    private func expandNesting(_ content: Substring, nest: Nest) -> String {
        var key = content
        var overrides: [String: JSONValue] = [:]

        if let comma = firstUnquoted(options.nestingOptionsSeparator, in: content) {
            key = content[..<comma.lowerBound]
            // i18next accepts single-quoted JSON here.
            let raw = String(Self.trimmed(content[comma.upperBound...]).map { $0 == "'" ? "\"" : $0 })
            if case .object(let parsed)? = try? JSONValue(json: raw) { overrides = parsed }
        }
        return nest(Self.trimmed(key), overrides)
    }

    /// Finds the `nestingSuffix` that closes an already-opened `$t(`, honoring inner `$t(` and `"` strings.
    private func closingNestingRange(in text: Substring) -> Range<Substring.Index>? {
        var depth = 1
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let tail = text[index...]
            if text[index] == "\"" {
                inQuotes.toggle()
            } else if !inQuotes {
                if tail.hasPrefix(options.nestingPrefix) {
                    depth += 1
                    index = text.index(index, offsetBy: options.nestingPrefix.count)
                    continue
                }
                if tail.hasPrefix(options.nestingSuffix) {
                    depth -= 1
                    let end = text.index(index, offsetBy: options.nestingSuffix.count)
                    if depth == 0 { return index..<end }
                    index = end
                    continue
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private func firstUnquoted(_ separator: String, in text: Substring) -> Range<Substring.Index>? {
        var inQuotes = false
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "\"" {
                inQuotes.toggle()
            } else if !inQuotes, text[index...].hasPrefix(separator) {
                return index..<text.index(index, offsetBy: separator.count)
            }
            index = text.index(after: index)
        }
        return nil
    }

    // MARK: Text helpers

    static func trimmed(_ text: some StringProtocol) -> String {
        var slice = Substring(text)
        while let first = slice.first, first.isWhitespace { slice = slice.dropFirst() }
        while let last = slice.last, last.isWhitespace { slice = slice.dropLast() }
        return String(slice)
    }

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
            case "/": result += "&#x2F;"
            default: result.append(character)
            }
        }
        return result
    }
}
