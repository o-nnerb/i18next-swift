// The stdlib's `firstRange(of:)`, `split(separator: String)` and `replacing(_:with:)` (`_StringProcessing`)
// require macOS 13 / iOS 16. These are the subset the library needs, available on the package minimums.

extension Collection where Element == Character {
    /// Range of the first occurrence of `needle`, or nil. An empty needle never matches.
    package func indexRange(of needle: String) -> Range<Index>? {
        let target = Array(needle)
        guard !target.isEmpty else { return nil }

        var start = startIndex
        while start != endIndex {
            var cursor = start
            var matched = 0
            while matched < target.count, cursor != endIndex, self[cursor] == target[matched] {
                formIndex(after: &cursor)
                matched += 1
            }
            if matched == target.count { return start..<cursor }
            formIndex(after: &start)
        }
        return nil
    }
}

extension StringProtocol {
    /// Splits on every occurrence of `separator`, keeping empty pieces.
    package func splitKeepingEmpty(on separator: String) -> [String] {
        let text = Substring(self)
        guard !separator.isEmpty else { return [String(text)] }

        var pieces: [String] = []
        var rest = text
        while let range = rest.indexRange(of: separator) {
            pieces.append(String(rest[..<range.lowerBound]))
            rest = rest[range.upperBound...]
        }
        pieces.append(String(rest))
        return pieces
    }
}
