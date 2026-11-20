// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Chooses the language when none is configured (`Options.lng` unset, or `changeLanguage(nil)`).
///
/// ``detect()`` returns candidates in priority order. The first one `supportedLngs` allows wins; if none is allowed,
/// the closest supported language is used, then the first fallback.
public protocol LanguageDetector: Sendable {
    func detect() async -> [String]

    /// Called with the language that was chosen, so a detector can remember it (i18next's `cacheUserLanguage`).
    func cacheUserLanguage(_ language: String) async
}

extension LanguageDetector {
    public func cacheUserLanguage(_ language: String) async {}
}

/// The languages the system is set to: the user's preferred languages on Apple platforms, the `LANGUAGE`,
/// `LC_ALL`, `LC_MESSAGES` and `LANG` environment variables elsewhere.
public struct SystemLanguageDetector: LanguageDetector {
    public init() {}

    public func detect() async -> [String] {
        #if canImport(Darwin)
        return Locale.preferredLanguages
        #else
        return Self.languages(fromEnvironment: ProcessInfo.processInfo.environment)
        #endif
    }

    /// `pt_BR.UTF-8:en_US` → `["pt-BR", "en-US"]`. `C` and `POSIX` carry no language.
    static func languages(fromEnvironment environment: [String: String]) -> [String] {
        var result: [String] = []
        for name in ["LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"] {
            guard let value = environment[name], !value.isEmpty else { continue }
            for entry in value.split(separator: ":") {
                var code = entry.split(separator: ".").first.map(String.init) ?? ""
                code = code.split(separator: "@").first.map(String.init) ?? ""
                guard !code.isEmpty, code != "C", code != "POSIX" else { continue }
                let tag = code.replacingUnderscores()
                if !result.contains(tag) { result.append(tag) }
            }
        }
        return result
    }
}

extension String {
    fileprivate func replacingUnderscores() -> String {
        String(map { $0 == "_" ? "-" : $0 })
    }
}
