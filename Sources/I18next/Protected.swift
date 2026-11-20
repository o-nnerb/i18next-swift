internal import SwiftAsyncStream

/// Mutable state guarded by a `Lock`. Stands in for `Synchronization.Mutex`, which needs macOS 15 / iOS 18.
///
/// Never call out to user code, resume continuations or await while holding the lock.
final class Protected<Value>: @unchecked Sendable {
    private let lock = Lock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<Result, Failure: Error>(
        _ body: (inout Value) throws(Failure) -> Result
    ) throws(Failure) -> Result {
        try lock.withLock { () throws(Failure) -> Result in
            try body(&value)
        }
    }
}
