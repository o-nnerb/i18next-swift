# i18next-swift

A from-scratch Swift port of [i18next](https://github.com/i18next/i18next). Swift 6.4, language mode 6, `defaultIsolation(nil)`.

| | |
|---|---|
| Platforms | macOS 12, iOS 15, tvOS 15, watchOS 9, visionOS 1, Linux, Windows |
| Foundation | `FoundationEssentials` where it exists; the system `Foundation` on Apple SDKs (only `JSONValue` and `FileSystemBackend` import it) |
| Dependencies | [swift-async-stream](https://github.com/o-nnerb/swift-async-stream) for `Lock` and `AsyncSemaphore` (internal import); `I18nextHTTP` also pulls [request-dl-nio](https://github.com/request-dl/request-dl-nio) |

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
    headers: ["X-Api-Key": key]
)
```

2xx is parsed as JSON; 404/410 are `notFound`; 408/425/429/5xx and network errors are `HTTPTransientError` (retried);
anything else is final.

The `NIOTransport` trait (on by default) is forwarded to RequestDL. Apple-only apps can drop SwiftNIO from the build:

```swift
.package(url: "https://github.com/o-nnerb/i18next-swift.git", from: "...", traits: [])
```

## Plural rules

`Sources/I18next/CLDRPluralData.swift` is generated from CLDR's `plurals.xml` and `ordinals.xml` (Unicode License v3):

```sh
Scripts/generate-plurals.py --tag release-49
```

The script also writes `Tests/I18nextTests/CLDRPluralSamples.swift`, CLDR's own published samples (~12k), and the
conformance tests run every rule against them. To update, pass a newer tag and run `swift test`.
Compact-notation operands (`c`, `e`) are always 0, as for any plain number.

## Status

Implemented: resource store, language hierarchy and `load` strategy, CLDR 49 plurals (cardinal for 227 locales,
ordinal for 110, generated), context, namespaces, interpolation with escaping, nesting, custom formats, `getFixedT`,
async backends.

Not yet: language detectors, events, `returnObjects`, `saveMissing`, built-in
`number`/`datetime`/`list` formatters (planned as `I18nextFormatters` on `FoundationInternationalization`).
