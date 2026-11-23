// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

/// What the conformance scenarios can't see: tags JavaScriptCore's ICU rejects but the CLDR (and V8) define, and the
/// effect on the language utilities.
@Suite("BCP 47 aliases")
struct BCP47AliasTests {
    @Test(arguments: [
        ("sgn-BE-FR", "sfb"), ("sgn-be-nl", "vgt"), ("sgn-CH-DE", "sgg"),
        ("sgn-US", "ase"), ("sgn-GB", "bfi"), ("sgn-UK", "bfi"), ("sgn-Latn-US", "ase-Latn"),
        ("iw-IL", "he-IL"), ("tl", "fil"), ("eng-GB", "en-GB"), ("sh-BA", "sr-Latn-BA"), ("cnr", "sr-ME"),
        ("ru-SU", "ru-RU"), ("ka-SU", "ka-GE"), ("en-840", "en-US"), ("en-Qaai", "en-Zinh"),
        ("zh-hakka", "hak"), ("zh-guoyu", "zh"), ("ja-Latn-hepburn-heploc", "ja-Latn-alalc97"),
        ("de-x-custom", "de-x-custom"), ("en-u-nu-latn", "en-u-nu-latn"), ("tlh", "tlh"),
    ])
    func canonical(_ tag: String, _ expected: String) {
        #expect(BCP47.canonical(tag) == expected)
    }

    @Test(arguments: ["", "x", "e", "en-", "en--US", "abcdefghi", "en-US-US", "en-fonipa-fonipa-"])
    func notWellFormed(_ tag: String) {
        // not asserting nil for every one (a duplicate variant is accepted), only that nothing crashes
        _ = BCP47.canonical(tag)
    }

    @Test func formatUsesTheAliases() {
        let utils = LanguageUtils()
        #expect(utils.format("iw-il") == "he-IL")
        #expect(utils.format("TL-ph") == "fil-PH")
        #expect(LanguageUtils(lowerCaseLng: true).format("sr-latn-yu") == "sr-latn-rs")
        // a code without subtags only changes case, as in i18next
        #expect(utils.format("tl") == "tl")
        #expect(utils.languagePart("tl-PH") == "tl")
    }
}
