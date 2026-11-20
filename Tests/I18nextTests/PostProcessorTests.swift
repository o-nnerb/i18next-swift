// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import Testing

@testable import I18next

private func makeI18n(configure: (inout I18next.Options) -> Void = { _ in }) -> I18next {
    I18next { options in
        options.lng = "pt-BR"
        options.fallbackLng = ["en"]
        options.resources = [
            "en": ["translation": ["hello": "Hello", "greeting": "Hi {{name}}", "ref": "see $t(hello)"]],
            "pt": ["translation": ["hello": "Olá"]],
            "pt-BR": ["common": ["ok": "Certo"]],
        ]
        configure(&options)
    }
}

@Suite("Post-processors")
struct PostProcessorTests {
    @Test func registeredThroughOptionsAndRunInOrder() {
        let i18n = makeI18n { options in
            options.postProcessors = [
                "upper": { value, _ in value.uppercased() },
                "wrap": { value, _ in "[\(value)]" },
            ]
        }
        #expect(i18n.t("hello", .init(postProcess: ["upper", "wrap"])) == "[OLÁ]")
        #expect(i18n.t("hello", .init(postProcess: ["wrap", "upper"])) == "[OLÁ]")
        #expect(i18n.t("greeting", .init(variables: ["name": "Ana"], postProcess: ["upper"])) == "HI ANA")
    }

    @Test func registeredAfterCreation() {
        let i18n = makeI18n()
        i18n.addPostProcessor("bang") { value, _ in value + "!" }
        #expect(i18n.t("hello", .init(postProcess: ["bang"])) == "Olá!")
    }

    @Test func instanceListAppliesUntilTheCallOverridesIt() {
        let i18n = makeI18n { options in
            options.postProcess = ["wrap"]
            options.postProcessors["wrap"] = { value, _ in "[\(value)]" }
            options.postProcessors["bang"] = { value, _ in value + "!" }
        }
        #expect(i18n.t("hello") == "[Olá]")
        #expect(i18n.t("hello", .init(postProcess: [])) == "Olá")
        #expect(i18n.t("hello", .init(postProcess: ["bang"])) == "Olá!")
    }

    @Test func unknownNamesAreSkippedAndNilKeepsTheText() {
        let i18n = makeI18n { options in
            options.postProcessors["ignore"] = { _, _ in nil }
            options.postProcessors["bang"] = { value, _ in value + "!" }
        }
        #expect(i18n.t("hello", .init(postProcess: ["missing", "bang"])) == "Olá!")
        #expect(i18n.t("hello", .init(postProcess: ["bang", "ignore", "bang"])) == "Olá!!")
    }

    @Test func missingKeysAndDefaultsAreProcessedToo() {
        let i18n = makeI18n { options in
            options.postProcessors["upper"] = { value, _ in value.uppercased() }
        }
        #expect(i18n.t("nope", .init(postProcess: ["upper"])) == "NOPE")
        #expect(
            i18n.t("nope", .init(defaultValue: "fallback {{x}}", variables: ["x": "v"], postProcess: ["upper"]))
                == "FALLBACK V"
        )
        #expect(i18n.t("greeting", .init(skipInterpolation: true, postProcess: ["upper"])) == "HI {{NAME}}")
    }

    @Test func nestedTranslationsAreProcessedOnceWithTheText() {
        let i18n = makeI18n { options in
            options.postProcessors["wrap"] = { value, _ in "[\(value)]" }
        }
        #expect(i18n.t("ref", .init(lng: "en", postProcess: ["wrap"])) == "[see Hello]")
    }

    @Test func contextDescribesTheTranslation() {
        let seen = Protected<[I18next.PostProcessContext]>([])
        let i18n = makeI18n { options in
            options.postProcessors["spy"] = { _, context in
                seen.withLock { $0.append(context) }
                return nil
            }
        }
        _ = i18n.t(["nope", "common:ok"], .init(variables: ["n": 1], postProcess: ["spy"]))
        _ = i18n.t("hello", .init(lng: "en", postProcess: ["spy"]))

        let contexts = seen.withLock { $0 }
        #expect(contexts.count == 2)
        #expect(contexts[0].keys == ["nope", "common:ok"])
        #expect(contexts[0].language == "pt-BR")
        #expect(contexts[0].usedKey == "ok")
        #expect(contexts[0].usedNS == "common")
        #expect(contexts[0].usedLng == "pt-BR")
        #expect(contexts[0].options.variables["n"] == 1)
        #expect(contexts[0].translator === i18n)
        #expect(contexts[1].language == "en")
        #expect(contexts[1].usedLng == "en")
    }

    @Test func objectsAreProcessedLeafByLeaf() {
        let i18n = makeI18n { options in
            options.resources["en"]?["translation"] = [
                "group": ["title": "Title", "steps": ["one", "two"]]
            ]
            options.postProcessors["wrap"] = { value, _ in "[\(value)]" }
        }
        let result = i18n.object("group", .init(lng: "en", postProcess: ["wrap"]))
        #expect(result == ["title": "[Title]", "steps": ["[one]", "[two]"]])
        // A joined array is one text.
        #expect(i18n.t("group.steps", .init(lng: "en", joinArrays: "+", postProcess: ["wrap"])) == "[one+two]")
    }

    @Test func cimodeIsLeftAlone() {
        let i18n = makeI18n { options in
            options.postProcessors["upper"] = { value, _ in value.uppercased() }
        }
        #expect(i18n.t("hello", .init(lng: "cimode", postProcess: ["upper"])) == "hello")
    }

    @Test func fixedTranslateFunctionsPassTheOptionsThrough() {
        let i18n = makeI18n { options in
            options.postProcessors["upper"] = { value, _ in value.uppercased() }
        }
        let t = i18n.getFixedT(lng: "en")
        #expect(t("hello", .init(postProcess: ["upper"])) == "HELLO")
    }

    @Test func gettingStartedExample() {
        let i18n = I18next { options in
            options.lng = "en"
            options.resources = ["en": ["translation": ["hello": "Hello"]]]
            options.postProcessors["uppercase"] = { value, _ in value.uppercased() }
            options.postProcessors["tag"] = { value, context in "\(value) (\(context.language ?? "?"))" }
        }
        #expect(i18n.t("hello", .init(postProcess: ["uppercase", "tag"])) == "HELLO (en)")
    }
}
