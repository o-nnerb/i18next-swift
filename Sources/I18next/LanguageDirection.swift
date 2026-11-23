// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

/// The direction a language is written in.
public enum LanguageDirection: String, Sendable, Hashable {
    case ltr
    case rtl
}

extension I18next {
    /// The direction of `lng` (the resolved or active language by default), as i18next's `dir()` answers when the
    /// runtime can't tell: a language in i18next's list of right-to-left languages (or with an `Arab` script) is
    /// ``LanguageDirection/rtl``; one with a `Latn` script, or with no language at all, is ``LanguageDirection/ltr``.
    public func dir(_ lng: String? = nil) -> LanguageDirection {
        guard let code = lng ?? resolvedLanguage ?? languages.first ?? language else { return .ltr }
        let lowered = code.lowercased()
        // i18next requires the script to start at index 2 or later (`indexOf(...) > 1`).
        if let range = lowered.indexRange(of: "-latn"),
            lowered.distance(from: lowered.startIndex, to: range.lowerBound) >= 2
        {
            return .ltr
        }
        if Self.rightToLeftLanguages.contains(languageUtils.languagePart(code)) { return .rtl }
        if let range = lowered.indexRange(of: "-arab"),
            lowered.distance(from: lowered.startIndex, to: range.lowerBound) >= 2
        {
            return .rtl
        }
        return .ltr
    }

    /// Languages written right to left, from i18next 27.2.2.
    static let rightToLeftLanguages: Set<String> = [
        "ar", "shu", "sqr", "ssh", "xaa", "yhd", "yud", "aao", "abh", "abv", "acm", "acq", "acw", "acx", "acy",
        "adf", "ads", "aeb", "aec", "afb", "ajp", "apc", "apd", "arb", "arq", "ars", "ary", "arz", "auz", "avl",
        "ayh", "ayl", "ayn", "ayp", "bbz", "pga", "he", "iw", "ps", "pbt", "pbu", "pst", "prp", "prd", "ug", "ur",
        "ydd", "yds", "yih", "ji", "yi", "hbo", "men", "xmn", "fa", "jpr", "peo", "pes", "prs", "dv", "sam", "ckb",
    ]
}
