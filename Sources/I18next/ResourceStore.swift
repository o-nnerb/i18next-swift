// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// Thread-safe storage of translation resources, indexed by language and namespace.
public final class ResourceStore: Sendable {
    public typealias Resources = [String: [String: JSONValue]]

    public let keySeparator: String?
    /// When true, a flat key such as `"a.b"` is tried before walking nested objects.
    public let ignoreJSONStructure: Bool

    private let storage: Protected<Resources>
    /// Told about every change, after it was made.
    private let onChange: (@Sendable (I18nextEvent) -> Void)?

    public convenience init(
        data: Resources = [:],
        keySeparator: String? = ".",
        ignoreJSONStructure: Bool = true
    ) {
        self.init(data: data, keySeparator: keySeparator, ignoreJSONStructure: ignoreJSONStructure, onChange: nil)
    }

    init(
        data: Resources,
        keySeparator: String?,
        ignoreJSONStructure: Bool,
        onChange: (@Sendable (I18nextEvent) -> Void)?
    ) {
        self.storage = Protected(data)
        self.keySeparator = keySeparator
        self.ignoreJSONStructure = ignoreJSONStructure
        self.onChange = onChange
    }

    // MARK: Reading

    /// Looks `key` up in a bundle, following i18next's `ResourceStore.getResource`: the nested path first, then, when
    /// `ignoreJSONStructure` is on, a search that also matches keys containing the separator (`"a.b"` stored flat, or
    /// inside a nested object). `keySeparator` and `ignoreJSONStructure` override the store's for this call.
    public func getResource(
        lng: String,
        ns: String,
        key: String,
        keySeparator override: SeparatorSetting? = nil,
        ignoreJSONStructure ignoreOverride: Bool? = nil
    ) -> JSONValue? {
        guard let bundle = getResourceBundle(lng: lng, ns: ns) else { return nil }
        if key.isEmpty { return bundle }

        let separator = override.map(\.value) ?? self.keySeparator
        let path = separator.flatMap { $0.isEmpty ? nil : key.splitKeepingEmpty(on: $0) } ?? [key]
        let nested = bundle.value(at: path)
        if let nested, nested != .null { return nested }
        guard ignoreOverride ?? ignoreJSONStructure else { return nested }
        return Self.deepFind(bundle, key, separator: separator)
    }

    /// i18next's `deepFind`: tolerates keys that contain the separator at any depth.
    static func deepFind(_ object: JSONValue, _ path: String, separator: String?) -> JSONValue? {
        guard case .object(let root) = object else { return nil }
        if let direct = root[path], direct.isTruthy { return direct }
        guard let separator, !separator.isEmpty else { return root[path] }

        let tokens = path.splitKeepingEmpty(on: separator)
        var current: JSONValue? = object
        var index = 0
        while index < tokens.count {
            guard let container = current, container.isContainer else { return nil }
            var next: JSONValue?
            var candidate = ""
            var end = index
            while end < tokens.count {
                if end != index { candidate += separator }
                candidate += tokens[end]
                next = container[candidate]
                if let found = next {
                    if found.isScalar, end < tokens.count - 1 {
                        end += 1
                        continue
                    }
                    index += end - index + 1
                    break
                }
                end += 1
            }
            current = next
        }
        return current
    }

    public func getResourceBundle(lng: String, ns: String) -> JSONValue? {
        storage.withLock { $0[lng]?[ns] }
    }

    public func hasResourceBundle(lng: String, ns: String) -> Bool {
        getResourceBundle(lng: lng, ns: ns) != nil
    }

    /// Whether `lng` has at least one non-empty bundle.
    public func hasLanguageSomeTranslations(lng: String) -> Bool {
        storage.withLock { data in
            data[lng]?.values.contains { bundle in
                switch bundle {
                case .object(let fields): !fields.isEmpty
                case .array(let items): !items.isEmpty
                case .null, .bool(false), .string(""): false
                case .number(let number): number != 0 && !number.isNaN
                default: true
                }
            } ?? false
        }
    }

    public var languages: [String] {
        storage.withLock { Array($0.keys).sorted() }
    }

    public func namespaces(lng: String) -> [String] {
        storage.withLock { Array($0[lng]?.keys ?? [:].keys).sorted() }
    }

    // MARK: Writing

    /// Stores `value` at `key` (split by `keySeparator`). With `deep`, objects are merged into what exists.
    public func addResource(
        lng: String,
        ns: String,
        key: String,
        value: JSONValue,
        deep: Bool = false,
        overwrite: Bool = false
    ) {
        setResource(lng: lng, ns: ns, key: key, value: value, deep: deep, overwrite: overwrite)
        onChange?(.added(language: lng, namespace: ns))
    }

    private func setResource(lng: String, ns: String, key: String, value: JSONValue, deep: Bool, overwrite: Bool) {
        let path = splitKey(key)
        storage.withLock { resources in
            let bundle = resources[lng]?[ns] ?? .object([:])
            let updated: JSONValue
            if deep, let existing = bundle.value(at: path), case .object = existing {
                updated = bundle.setting(path, to: existing.deepExtended(with: value, overwrite: overwrite))
            } else {
                updated = bundle.setting(path, to: value)
            }
            resources[lng, default: [:]][ns] = updated
        }
    }

    public func addResources(lng: String, ns: String, resources: [String: JSONValue]) {
        for (key, value) in resources {
            setResource(lng: lng, ns: ns, key: key, value: value, deep: false, overwrite: false)
        }
        onChange?(.added(language: lng, namespace: ns))
    }

    public func addResourceBundle(
        lng: String,
        ns: String,
        resources: JSONValue,
        deep: Bool = false,
        overwrite: Bool = false
    ) {
        storage.withLock { all in
            var merged = resources
            if let existing = all[lng]?[ns] {
                merged =
                    deep
                    ? existing.deepExtended(with: resources, overwrite: overwrite)
                    : existing.shallowExtended(with: resources)
            }
            all[lng, default: [:]][ns] = merged
        }
        onChange?(.added(language: lng, namespace: ns))
    }

    /// Replaces the bundle outright (used when reloading from a backend).
    public func setResourceBundle(lng: String, ns: String, resources: JSONValue) {
        storage.withLock { $0[lng, default: [:]][ns] = resources }
        onChange?(.added(language: lng, namespace: ns))
    }

    public func removeResourceBundle(lng: String, ns: String) {
        storage.withLock { all in
            all[lng]?[ns] = nil
            if all[lng]?.isEmpty == true { all[lng] = nil }
        }
        onChange?(.removed(language: lng, namespace: ns))
    }

    // MARK: Helpers

    func splitKey(_ key: String) -> [String] {
        guard let separator = keySeparator, !separator.isEmpty else { return [key] }
        return key.splitKeepingEmpty(on: separator)
    }
}
