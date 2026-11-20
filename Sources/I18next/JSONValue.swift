// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

// Apple SDKs ship only the umbrella `Foundation` (built from the same swift-foundation sources);
// every other platform exposes `FoundationEssentials` directly. This is the only file that needs either.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A JSON document node. Translation resources and interpolation variables are expressed with it.
public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    public init(json: String) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

// MARK: - Accessors

extension JSONValue {
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }

    /// Walks `path` through objects (by key) and arrays (by index).
    func value(at path: some Collection<String>) -> JSONValue? {
        guard let head = path.first else { return self }
        let tail = path.dropFirst()
        switch self {
        case .object(let object):
            return object[head]?.value(at: tail)
        case .array(let array):
            guard let index = Int(head), array.indices.contains(index) else { return nil }
            return array[index].value(at: tail)
        default:
            return nil
        }
    }

    /// Returns a copy with `value` stored at `path`, creating intermediate objects as needed.
    func setting(_ path: some Collection<String>, to value: JSONValue) -> JSONValue {
        guard let head = path.first else { return value }
        var object = objectValue ?? [:]
        object[head] = (object[head] ?? .null).setting(path.dropFirst(), to: value)
        return .object(object)
    }

    /// Recursive merge. Existing leaves are replaced only when `overwrite` is true.
    func deepExtended(with other: JSONValue, overwrite: Bool) -> JSONValue {
        guard case .object(var target) = self, case .object(let source) = other else {
            return overwrite ? other : self
        }
        for (key, value) in source {
            if let existing = target[key] {
                target[key] = existing.deepExtended(with: value, overwrite: overwrite)
            } else {
                target[key] = value
            }
        }
        return .object(target)
    }

    /// Top-level merge where `other` wins.
    func shallowExtended(with other: JSONValue) -> JSONValue {
        guard case .object(var target) = self, case .object(let source) = other else { return other }
        target.merge(source) { _, new in new }
        return .object(target)
    }

    /// String used when the value is substituted into a translation.
    var interpolationString: String {
        switch self {
        case .null:
            return ""
        case .bool(let value):
            return value ? "true" : "false"
        case .string(let value):
            return value
        case .number(let value):
            if value.isFinite, value == value.rounded(), abs(value) < 1e15 {
                return String(Int64(value))
            }
            return "\(value)"
        case .array, .object:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            guard let data = try? encoder.encode(self) else { return "" }
            return String(decoding: data, as: UTF8.self)
        }
    }
}
