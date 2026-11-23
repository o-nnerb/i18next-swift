// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

internal import SwiftAsyncStream

/// Loads bundles from a ``Backend`` into the ``ResourceStore``.
///
/// - Concurrent requests for the same bundle share one read.
/// - Bundles already in the store are not read again.
/// - A bundle whose read failed is not retried by later loads (so `pt-BR` isn't requested on every language
///   switch when only `pt` exists). `force` clears that.
final class BackendConnector: Sendable {
    enum Outcome: Sendable {
        case available
        case loaded(ResourceKey)
        case failed(LoadFailure)
    }

    private struct State {
        var inflight: [ResourceKey: Task<Outcome, Never>] = [:]
        var failed: Set<ResourceKey> = []
    }

    private let backend: any Backend
    private let store: ResourceStore
    private let options: BackendOptions
    private let readSlots: AsyncSemaphore
    private let state = Protected(State())

    init(backend: any Backend, store: ResourceStore, options: BackendOptions) {
        self.backend = backend
        self.store = store
        self.options = options
        self.readSlots = AsyncSemaphore(permits: max(1, options.maxParallelReads))
    }

    /// Every caller that asked for a bundle is told how it went (`onEvent`), also when another caller's read served it.
    func load(
        languages: [String],
        namespaces: [String],
        force: Bool = false,
        onEvent: @Sendable (I18nextEvent) -> Void
    ) async -> LoadReport {
        var seen: Set<ResourceKey> = []
        var keys: [ResourceKey] = []
        for language in languages {
            for namespace in namespaces {
                let key = ResourceKey(language: language, namespace: namespace)
                if seen.insert(key).inserted { keys.append(key) }
            }
        }

        let outcomes = await withTaskGroup(of: Outcome.self) { group in
            for key in keys {
                group.addTask { await self.ensureLoaded(key, force: force) }
            }
            var all: [Outcome] = []
            for await outcome in group { all.append(outcome) }
            return all
        }

        var report = LoadReport()
        for outcome in outcomes {
            switch outcome {
            case .available: break
            case .loaded(let key): report.loaded.append(key)
            case .failed(let failure): report.failures.append(failure)
            }
        }
        for key in report.loaded { onEvent(.loaded(key)) }
        for failure in report.failures { onEvent(.failedLoading(failure)) }
        report.loaded.sort { $0.description < $1.description }
        report.failures.sort { $0.key.description < $1.key.description }
        return report
    }

    /// A load for `key` has finished, successfully or not, and none is running.
    func isSettled(_ key: ResourceKey) -> Bool {
        let (running, failed) = state.withLock { ($0.inflight[key] != nil, $0.failed.contains(key)) }
        return !running && (failed || store.hasResourceBundle(lng: key.language, ns: key.namespace))
    }

    /// Asks the backend to create a key `t` could not find. Fire and forget, as in i18next.
    func create(_ missing: MissingKey) {
        let backend = backend
        Task {
            try? await backend.create(
                languages: missing.languages,
                namespace: missing.namespace,
                key: missing.key,
                fallbackValue: missing.fallbackValue,
                isUpdate: missing.isUpdate
            )
        }
    }

    private func ensureLoaded(_ key: ResourceKey, force: Bool) async -> Outcome {
        if !force {
            if store.hasResourceBundle(lng: key.language, ns: key.namespace) { return .available }
            if state.withLock({ $0.failed.contains(key) }) { return .available }
        }

        let task = state.withLock { state -> Task<Outcome, Never> in
            if let running = state.inflight[key] { return running }
            let task = Task { await self.readAndStore(key, force: force) }
            state.inflight[key] = task
            return task
        }
        return await task.value
    }

    /// Runs as its own task, so cancelling one waiter never cancels a read other callers share.
    private func readAndStore(_ key: ResourceKey, force: Bool) async -> Outcome {
        let outcome = await readWithRetry(key, force: force)
        state.withLock { state in
            state.inflight[key] = nil
            if case .failed = outcome { state.failed.insert(key) } else { state.failed.remove(key) }
        }
        return outcome
    }

    private func readWithRetry(_ key: ResourceKey, force: Bool) async -> Outcome {
        var delay = UInt64(max(0, options.retryDelayMilliseconds))
        var attempt = 0

        while true {
            do {
                let bundle = try await readSlots.withPermit {
                    try await self.backend.read(language: key.language, namespace: key.namespace)
                }
                if force {
                    store.setResourceBundle(lng: key.language, ns: key.namespace, resources: bundle)
                } else {
                    store.addResourceBundle(lng: key.language, ns: key.namespace, resources: bundle)
                }
                return .loaded(key)
            } catch {
                guard error is any RetryableBackendError, attempt < options.maxRetries else {
                    return .failed(LoadFailure(key: key, error: error))
                }
                attempt += 1
                try? await Task.sleep(nanoseconds: delay * 1_000_000)
                delay *= 2
            }
        }
    }
}
