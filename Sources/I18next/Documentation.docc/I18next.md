# ``I18next``

A Swift port of [i18next](https://github.com/i18next/i18next): translation lookup with fallbacks, plurals,
context, interpolation and async resource loading.

@Metadata {

    @PageColor(blue)

    @Available(macOS, introduced: "12.0")
    @Available(iOS, introduced: "15.0")
    @Available(tvOS, introduced: "15.0")
    @Available(watchOS, introduced: "9.0")
    @Available(visionOS, introduced: "1.0")
    @Available("Swift", introduced: "6.4")

    @SupportedLanguage(swift)
}

## Overview

``I18next`` reads the i18next v4 JSON format, so the same translation files can serve a web app and a Swift app:
`key_one` / `key_other` plurals, `key_ordinal_one`, `key_context`, `ns:key` namespaces, `{{variable}}`
interpolation and `$t(key)` nesting.

The core depends only on `FoundationEssentials` (the system `Foundation` on Apple SDKs, which don't ship the
smaller module) and on [swift-async-stream](https://github.com/o-nnerb/swift-async-stream) for locking, so it runs on
every platform Swift does, including Linux and Windows.

```swift
let i18n = I18next { options in
    options.lng = "pt-BR"
    options.fallbackLng = ["en"]
    options.resources = [
        "en": ["translation": ["item_one": "{{count}} item", "item_other": "{{count}} items"]],
    ]
}

i18n.t("item", .init(count: 3))   // "3 items"
```

Translating is synchronous; only loading resources from a ``Backend`` is asynchronous.

## Topics

### Essentials

- <doc:Getting-Started>
- ``I18next``
- ``TranslationOptions``
- ``JSONValue``

### Languages and fallbacks

- <doc:Language-Detection>
- ``FallbackLanguages``
- ``LoadStrategy``
- ``LanguageUtils``
- ``LanguageDetector``
- ``SystemLanguageDetector``
- ``SeparatorSetting``
- ``TranslationDetails``

### Events and missing keys

- <doc:Events-and-Missing-Keys>
- ``I18nextEvent``
- ``MissingKey``

### Loading resources

- <doc:Loading-Resources>
- ``Backend``
- ``BackendOptions``
- ``BackendError``
- ``RetryableBackendError``
- ``LoadReport``
- ``LoadFailure``
- ``ResourceKey``
- ``InMemoryBackend``
- ``FileSystemBackend``
- ``ResourceStore``

### Plurals

- <doc:Plurals>
- ``PluralResolver``
- ``PluralCategory``

### Interpolation and post-processing

- ``InterpolationOptions``
- ``I18next/Format``
- ``I18next/FormatContext``
- ``I18next/PostProcessor``
- ``I18next/PostProcessContext``
