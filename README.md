# i18next-swift

A from-scratch Swift port of [i18next](https://github.com/i18next/i18next). Swift 6.4, language mode 6, `defaultIsolation(nil)`.

| | |
|---|---|
| Platforms | macOS 12, iOS 15, tvOS 15, watchOS 9, visionOS 1, Linux, Windows |
| Foundation | `FoundationEssentials` where it exists; the system `Foundation` on Apple SDKs (only `JSONValue` and `FileSystemBackend` import it) |
| Dependencies | [swift-async-stream](https://github.com/o-nnerb/swift-async-stream) for `Lock` and `AsyncSemaphore` (internal import); `I18nextHTTP` also pulls [request-dl-nio](https://github.com/request-dl/request-dl-nio); `I18nextFormatters` uses Foundation (the full one on Linux) |

Reads the i18next v4 JSON format (`key_one` / `key_other`, `key_ordinal_one`, `key_context`, `ns:key`, `{{var}}`, `$t(key)`).

```swift
let i18n = I18next { o in
    o.lng = "pt-BR"
    o.fallbackLng = ["en"]
    o.ns = ["translation", "common"]
    o.backend = FileSystemBackend(directory: localesPath)   // {{lng}}/{{ns}}.json
}
await i18n.initialize()                      // loads pt-BR, pt, en for both namespaces

i18n.t("item", .init(count: 3))              // synchronous
await i18n.changeLanguage("en")              // loads first, applies after; the latest request wins
```

## Backends

Implement `Backend.read(language:namespace:)`. Failures never throw out of `initialize()` / `changeLanguage(_:)`;
they come back in the `LoadReport`, and translation keeps falling through the language chain.

- Concurrent requests for one bundle share a single read; bundles already in the store aren't re-read.
- Failed bundles (`pt-BR` when only `pt` exists) aren't requested again until `reloadResources()`.
- Errors conforming to `RetryableBackendError` are retried with exponential back-off (`maxRetries`, `retryDelayMilliseconds`).
- `maxParallelReads` caps simultaneous reads.
- `resources` passed in the options disable the backend unless `partialBundledLanguages` is true, as in i18next.

Included: `InMemoryBackend`, `FileSystemBackend`, and `HTTPBackend` (separate `I18nextHTTP` product).

### HTTP

`HTTPBackend` uses [RequestDL](https://github.com/request-dl/request-dl-nio), with the transport fixed per platform:
`URLSession` on Apple platforms, SwiftNIO (`.nio`) everywhere else.

```swift
o.backend = try HTTPBackend(
    baseURL: "https://cdn.example.com/app",
    loadPath: "locales/{{lng}}/{{ns}}.json",      // query values may use the placeholders too
    addPath: "locales/add/{{lng}}/{{ns}}",        // where `saveMissing` posts keys; nil turns it off
    headers: ["X-Api-Key": key]
)
```

2xx is parsed as JSON; 404/410 are `notFound`; 408/425/429/5xx and network errors are `HTTPTransientError` (retried);
anything else is final.

With `saveMissing`, each missing key is sent to `addPath` as a JSON `POST` once per language, with the body
`{"<key>": "<default value>"}` (an empty string when there is no default), as i18next-http-backend does. Every language
is attempted, and a failure is not retried.

## Formatters

`import I18nextFormatters` adds i18next's `number`, `currency`, `datetime`, `relativetime` and `list` formatters on top of
Foundation (`Intl`'s options, mapped onto `FormatStyle`, `DateFormatter` and `RelativeDateTimeFormatter`):

```swift
options.formats = BuiltInFormats.all   // or: i18n.addBuiltInFormats()
// "Total: {{amount, currency(EUR)}}"  →  "Total: €1,234.50"
```

They are checked against i18next on 1,814 values on Apple platforms; the documented gaps are quarters and fractional
relative times, `unit` lists and number styles, and time zone display names.

## Conformance

`Tests/I18nextTests/ConformanceFixtures.swift` holds 1,615 scenarios, most taken from the i18next test suite (lookup, plurals,
context, namespaces, separators, interpolation, nesting, language hierarchy, store lookup, post-processors), each with the answer
**i18next 27.2.2 itself gives**. `Scripts/conformance/generate.swift` computes them by running the real i18next inside
JavaScriptCore, so no Node is needed (macOS only):

```sh
swift Scripts/conformance/generate.swift path/to/i18next.js 27.2.2 Tests/I18nextTests/ConformanceFixtures.swift
```

`cases.js` holds only inputs; add a scenario there and regenerate. A known difference is listed, with its reason, in
`ConformanceTests.swift`, and the run fails if one of them starts matching.

## Plural rules

`Sources/I18next/CLDRPluralData.swift` is generated from CLDR's `plurals.xml` and `ordinals.xml` (Unicode License v3):

```sh
Scripts/generate-plurals.py --tag release-49
```

The script also writes `Tests/I18nextTests/CLDRPluralSamples.swift`, CLDR's own published samples (~12k), and the
conformance tests run every rule against them. To update, pass a newer tag and run `swift test`.
Compact-notation operands (`c`, `e`) are always 0, as for any plain number.

## Status

Implemented: resource store, language hierarchy (`load`, `supportedLngs`, script parts, per-language fallbacks),
CLDR 49 plurals (cardinal for 227 locales, ordinal for 110, generated), context, namespaces, interpolation with
escaping, nesting, `returnObjects`, `joinArrays`, `returnDetails`, custom formats, `postProcess`, `getFixedT` (with
`keyPrefix`), `resolvedLanguage`, `dir`, `hasLoadedNamespace`, async backends, language detection, events,
`saveMissing` with `missingKeyHandler` / backend `create`, `missingInterpolationHandler`, `returnNull`,
`returnedObjectHandler`, `missingKeyNoValueFallbackToKey`, `useRawValueToEscape`, and conformance with i18next 27.2.2 (1,615 scenarios).

Also: the `I18nextFormatters` product (`number`, `currency`, `datetime`, `relativetime`, `list`).

Not yet: `i18nFormat`, `overloadTranslationOptionHandler`, `cloneInstance`, `hydrate`, `getDataByLanguage`, and
ICU-driven BCP 47 aliases beyond a small table (`sgn-BE-FR` → `sfb`). `alwaysFormat` has no equivalent: i18next's own
formatter returns the value untouched when no format is named.
