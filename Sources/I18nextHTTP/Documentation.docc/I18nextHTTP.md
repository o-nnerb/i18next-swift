# ``I18nextHTTP``

Load i18next translation bundles over HTTP, with [RequestDL](https://github.com/request-dl/request-dl-nio).

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

``HTTPBackend`` is a `Backend` for `I18next`. The transport is fixed per platform: `URLSession` on Apple
platforms, SwiftNIO everywhere else.

```swift
let i18n = I18next { options in
    options.lng = "pt-BR"
    options.fallbackLng = ["en"]
    options.backend = try! HTTPBackend(
        baseURL: "https://cdn.example.com/app",
        loadPath: "locales/{{lng}}/{{ns}}.json",
        headers: ["X-Api-Key": key]
    )
}
await i18n.initialize()
```

`{{lng}}` and `{{ns}}` are substituted in the path and in query values, so `i18n/{{ns}}.json?lng={{lng}}` works too.

### Saving missing keys

With `saveMissing` on and no `missingKeyHandler`, keys `t` could not find reach the backend's `create`, which posts
them to ``HTTPBackend/addPath`` (`locales/add/{{lng}}/{{ns}}` by default, the same as i18next-http-backend; `nil` turns
it off):

```http
POST /locales/add/pt/translation
Content-Type: application/json

{"new.key": "Default text"}
```

The body holds the key and its default value (an empty string when there is none). There is one request per language;
all of them are attempted, and ``HTTPTransientError`` or ``HTTPBackendError/unexpectedStatus(_:)`` reports the first
failure. The connector sends each key once, without retrying.

### Status codes

| Response | Result |
|---|---|
| 2xx | The body is parsed as JSON |
| 404, 410 | `BackendError/notFound(language:namespace:)` |
| 408, 425, 429, 5xx, network errors | ``HTTPTransientError``, which the connector retries |
| anything else | ``HTTPBackendError/unexpectedStatus(_:)``, final |

A 2xx body that isn't JSON is ``HTTPBackendError/invalidResponse(language:namespace:underlying:)``, also final.

## Topics

### Backend

- ``HTTPBackend``

### Errors

- ``HTTPTransientError``
- ``HTTPBackendError``
