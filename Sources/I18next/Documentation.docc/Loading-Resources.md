# Loading resources

Read translations from a file, a server or anything else through a ``Backend``.

## Overview

Set ``I18next/Options/backend`` and call ``I18next/initialize()``. It loads the active language, its fallbacks and
``I18next/Options/preload`` for every configured namespace:

```swift
let i18n = I18next { options in
    options.lng = "pt-BR"
    options.fallbackLng = ["en"]
    options.ns = ["translation", "common"]
    options.backend = FileSystemBackend(directory: localesPath)   // {{lng}}/{{ns}}.json
}

await i18n.initialize()                 // loads pt-BR, pt and en, for both namespaces
i18n.t("common:ok")                     // synchronous from here on
```

For HTTP, add the `I18nextHTTP` product and use `HTTPBackend`.

## How loading behaves

- **Failures don't throw.** They come back in the ``LoadReport``, and translation keeps falling through the
  language chain. A missing `pt-BR` file is normal when only `pt` exists.
- **One read per bundle.** Concurrent requests for the same language and namespace share a single read, and bundles
  already in the ``ResourceStore`` are not read again.
- **Failed bundles aren't requested again** until ``I18next/reloadResources(languages:namespaces:)``.
- **Transient errors are retried.** An error that conforms to ``RetryableBackendError`` is retried with exponential
  back-off, up to ``BackendOptions/maxRetries``.
- **Reads are capped** by ``BackendOptions/maxParallelReads``.
- **Bundled resources win.** If you pass ``I18next/Options/resources``, the backend is ignored unless
  ``I18next/Options/partialBundledLanguages`` is true.

The languages `dev` and `cimode` are never requested from a backend.

## Changing language

``I18next/changeLanguage(_:)`` loads the new language, then makes it active. If another change starts first, or the
task is cancelled, the language is left alone: the most recently *requested* change wins, whatever order the loads
finish in.

```swift
await i18n.changeLanguage("en")
```

``I18next/setLanguage(_:)`` skips the backend and switches at once.

## Writing a backend

Return one bundle per call and throw when it can't be read:

```swift
struct BundleBackend: Backend {
    func read(language: String, namespace: String) async throws -> JSONValue {
        guard let url = Bundle.module.url(forResource: namespace, withExtension: "json", subdirectory: language)
        else { throw BackendError.notFound(language: language, namespace: namespace) }
        return try JSONValue(data: Data(contentsOf: url))
    }
}
```

If you build paths from `language` or `namespace`, reject values containing `/` or `..` first, as
``FileSystemBackend`` does.
