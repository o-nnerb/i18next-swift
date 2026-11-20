/// Thread-safe storage of translation resources, indexed by language and namespace.
public final class ResourceStore: Sendable {
    public typealias Resources = [String: [String: JSONValue]]

    public let keySeparator: String?
    /// When true, a flat key such as `"a.b"` is tried before walking nested objects.
    public let ignoreJSONStructure: Bool

    private let storage: Protected<Resources>

    public init(
        data: Resources = [:],
        keySeparator: String? = ".",
        ignoreJSONStructure: Bool = true
    ) {
        self.storage = Protected(data)
        self.keySeparator = keySeparator
        self.ignoreJSONStructure = ignoreJSONStructure
    }

    // MARK: Reading

    public func getResource(lng: String, ns: String, key: String) -> JSONValue? {
        guard let bundle = getResourceBundle(lng: lng, ns: ns) else { return nil }
        if key.isEmpty { return bundle }
        if ignoreJSONStructure, let flat = bundle[key] { return flat }
        return bundle.value(at: splitKey(key))
    }

    public func getResourceBundle(lng: String, ns: String) -> JSONValue? {
        storage.withLock { $0[lng]?[ns] }
    }

    public func hasResourceBundle(lng: String, ns: String) -> Bool {
        getResourceBundle(lng: lng, ns: ns) != nil
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
            addResource(lng: lng, ns: ns, key: key, value: value)
        }
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
    }

    /// Replaces the bundle outright (used when reloading from a backend).
    public func setResourceBundle(lng: String, ns: String, resources: JSONValue) {
        storage.withLock { $0[lng, default: [:]][ns] = resources }
    }

    public func removeResourceBundle(lng: String, ns: String) {
        storage.withLock { all in
            all[lng]?[ns] = nil
            if all[lng]?.isEmpty == true { all[lng] = nil }
        }
    }

    // MARK: Helpers

    func splitKey(_ key: String) -> [String] {
        guard let separator = keySeparator, !separator.isEmpty else { return [key] }
        return key.splitKeepingEmpty(on: separator)
    }
}
