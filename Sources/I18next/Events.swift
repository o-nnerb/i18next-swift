// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// A key that `t` could not resolve, handed to `Options.missingKeyHandler` or saved through the backend.
public struct MissingKey: Sendable, Equatable {
    public let languages: [String]
    public let namespace: String
    public let key: String
    /// What would be stored for the key: the default value, or the key itself.
    public let fallbackValue: String?
    /// The key exists, but its text differs from the `defaultValue` given (`Options.updateMissing`).
    public let isUpdate: Bool
}

/// What `I18next.events` reports.
public enum I18nextEvent: Sendable {
    /// `initialize()` finished.
    case initialized
    case languageChanging(String?)
    case languageChanged(String?)
    /// A bundle was read from the backend.
    case loaded(ResourceKey)
    case failedLoading(LoadFailure)
    /// `t` did not find a key and `saveMissing` is on. `value` is what `t` returned.
    case missingKey(MissingKey, value: String)
    /// Resources were added to, or replaced in, the store.
    case added(language: String, namespace: String)
    case removed(language: String, namespace: String)
}

/// Fans events out to every `AsyncStream` handed out by `I18next.events`.
final class EventHub: Sendable {
    private struct State {
        var nextID = 0
        var continuations: [Int: AsyncStream<I18nextEvent>.Continuation] = [:]
    }

    private let state = Protected(State())

    func stream() -> AsyncStream<I18nextEvent> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let id = state.withLock { state -> Int in
                state.nextID += 1
                state.continuations[state.nextID] = continuation
                return state.nextID
            }
            continuation.onTermination = { [state] _ in
                state.withLock { $0.continuations[id] = nil }
            }
        }
    }

    func emit(_ event: I18nextEvent) {
        let targets = state.withLock { Array($0.continuations.values) }
        for continuation in targets { continuation.yield(event) }
    }
}
