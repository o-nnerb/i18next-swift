# Getting started

Create an instance, give it resources, and translate.

## Create an instance

Configure ``I18next`` through its ``I18next/Options``. Resources are nested JSON, keyed by language and namespace:

```swift
let i18n = I18next { options in
    options.lng = "pt-BR"
    options.fallbackLng = ["en"]
    options.resources = [
        "en": ["translation": [
            "hello": "Hello",
            "greeting": "Hi {{name}}!",
            "item_one": "{{count}} item",
            "item_other": "{{count}} items",
        ]],
        "pt": ["translation": ["hello": "Olá"]],
    ]
}
```

## Translate

``I18next/t(_:_:)`` looks the key up in the active language, then in its language part (`pt-BR`, then `pt`), then in
the fallbacks. A key that can't be found comes back as written, or as ``TranslationOptions/defaultValue`` if you
give one.

```swift
i18n.t("hello")                                              // "Olá"
i18n.t("greeting", .init(variables: ["name": "Ana"]))        // "Hi Ana!" (from `en`)
i18n.t("item", .init(count: 3))                              // "3 items"
i18n.t("missing", .init(defaultValue: "Not found"))          // "Not found"
```

### Namespaces

Use `ns:key`, or pass ``TranslationOptions/ns``:

```swift
i18n.t("common:ok")
i18n.t("ok", .init(ns: ["common"]))
```

### Context

``TranslationOptions/context`` selects a `key_context` variant and falls back to the plain key:

```swift
// "friend": "A friend", "friend_male": "A boyfriend"
i18n.t("friend", .init(context: "male"))      // "A boyfriend"
i18n.t("friend", .init(context: "other"))     // "A friend"
```

## Interpolation

Variables are HTML-escaped by default. Use `{{- name}}` in the template, or ``TranslationOptions/escapeValue``, to
insert a value as is.

Values you substitute are never scanned again: a variable containing `{{x}}` or `$t(y)` is inserted literally.

Nest other translations with `$t(key)`, optionally with options:

```json
{ "ref": "See $t(hello) and $t(greeting, {\"name\": \"Ann\"})" }
```

### Custom formats

`{{value, name(arg: x)}}` calls a formatter you register:

```swift
i18n.addFormat("uppercase") { value, _, _ in value.interpolationString.uppercased() }
```

## Changing the language

``I18next/setLanguage(_:)`` switches immediately. When resources come from a backend, use
``I18next/changeLanguage(_:)`` instead, which loads first and applies afterwards. See <doc:Loading-Resources>.
