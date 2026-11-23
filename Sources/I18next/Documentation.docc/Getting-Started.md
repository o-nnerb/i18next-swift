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

`t` looks the key up in the active language, then in its language part (`pt-BR`, then `pt`), then in
the fallbacks. A key that can't be found comes back as written, or as ``TranslationOptions/defaultValue`` if you
give one. An empty string counts as missing (``I18next/Options/returnEmptyString``), and
``I18next/Options/fallbackLng`` is off until you set it, as in i18next 27.

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

Variables are HTML-escaped by default (`& < > " '`). Use `{{- name}}` in the template, or
``TranslationOptions/escapeValue``, to insert a value as is. A variable you don't pass leaves `{{name}}` in place
(``InterpolationOptions/skipOnVariables``).

Values you substitute are never scanned again: a variable containing `{{x}}` or `$t(y)` is inserted literally.

Nest other translations with `$t(key)`, optionally with options:

```json
{ "ref": "See $t(hello) and $t(greeting, {\"name\": \"Ann\"})" }
```

### Variables you didn't pass

A variable without a value stays as `{{name}}` (``InterpolationOptions/skipOnVariables``). To decide what goes there,
give ``I18next/Options/missingInterpolationHandler`` (or ``TranslationOptions/missingInterpolationHandler`` for one
call). It receives an ``I18next/MissingInterpolation`` and returns the text, which is escaped like any value; `nil`
means empty.

```swift
options.missingInterpolationHandler = { missing in "[\(missing.expression)]" }
// "Hello {{name}}" → "Hello [name]"
```

``InterpolationOptions/useRawValueToEscape`` limits escaping to string values: an array or object is inserted as its
text, untouched.

### Custom formats

`{{value, name(arg: x)}}` calls a formatter you register. It gets the value and a context with the language and every
option that applies (the template's arguments, the call's variables, and `formatParams`):

```swift
i18n.addFormat("uppercase") { value, _ in .string(value.interpolationString.uppercased()) }
```

The `I18nextFormatters` product provides the ones i18next ships: `number`, `currency`, `datetime`, `relativetime` and
`list`.

## Arrays and objects

`t` returns text. Use ``I18next/object(_:_:)`` for a resource that holds an array or an object: it returns the
structure with every leaf translated. ``TranslationOptions/joinArrays`` makes `t` join an array into one string, and
``I18next/details(_:_:)`` reports which key, language and namespace a result came from.

```swift
// "steps": ["Open {{app}}", "Sign in"]
i18n.object("steps", .init(variables: ["app": "Mail"]))   // ["Open Mail", "Sign in"]
i18n.t("steps", .init(variables: ["app": "Mail"], joinArrays: " → "))
```

``I18next/Options/returnedObjectHandler`` takes over when `t` reaches an object or array and `returnObjects` is off:
it gets the key, the value and the call's options, and whatever it returns is the result. By default `null` in the
resources counts as missing; ``I18next/Options/returnNull`` keeps it (`t` then gives an empty string and
``I18next/object(_:_:)`` gives `null`).

## Post-processing

A post-processor transforms a finished translation: after interpolation and nesting, once per `t` call. Register it by
name and list the names to apply, on the instance or per call (a call's list replaces the instance's; `[]` applies
none). Returning `nil` keeps the text, and a name that isn't registered is skipped.

```swift
let i18n = I18next { options in
    options.lng = "en"
    options.resources = ["en": ["translation": ["hello": "Hello"]]]
    options.postProcessors["uppercase"] = { value, _ in value.uppercased() }
    options.postProcessors["tag"] = { value, context in "\(value) (\(context.language ?? "?"))" }
}
i18n.t("hello", .init(postProcess: ["uppercase", "tag"]))   // "HELLO (en)"
i18n.addPostProcessor("bang") { value, _ in value + "!" }   // also possible after creation
```

The processor receives an ``I18next/PostProcessContext``: the keys, the language, the call's options (your variables
are in ``TranslationOptions/variables``) and where the text was found. A text with nested `$t(...)` is processed as a
whole, and an object returned by ``I18next/object(_:_:)`` is processed leaf by leaf. Unlike i18next, `usedKey`, `usedLng`
and `usedNS` are always provided, so there is no `postProcessPassResolved` switch.

## Scoping a translate function

``I18next/getFixedT(lng:ns:keyPrefix:lngs:)`` binds a language, namespaces and a key prefix, so a screen can write
short keys. A call can still override each of them; `keyPrefix: ""` switches the prefix off for one call.

```swift
// "settings": { "title": "Settings", "language": "Language" }
let t = i18n.getFixedT(keyPrefix: "settings")
t("title")                          // "Settings"
t(["missing", "language"])          // "Language"
```

## Language and direction

``I18next/resolvedLanguage`` is the first language in the hierarchy that has translations, which is the one to mark in a
language picker: with `pt-BR` active and only `pt` loaded it is `pt`. ``I18next/dir(_:)`` tells whether to lay out right
to left:

```swift
i18n.dir("ar-EG")   // .rtl
i18n.dir()          // the resolved language's direction
```

## Namespaces

``I18next/setDefaultNamespace(_:)-(String)`` changes the namespaces `t` searches without a `ns:` prefix.
``I18next/hasLoadedNamespace(_:lng:)`` says whether a namespace is ready: always for an instance without a backend,
and for one with a backend once ``I18next/initialize()`` has run and the namespace's load has finished, successfully or
not. A namespace that was never requested is not ready. `saveMissing` skips keys of namespaces that aren't ready,
since they may exist.

## Changing the language

``I18next/setLanguage(_:)`` switches immediately. When resources come from a backend, use
``I18next/changeLanguage(_:)`` instead, which loads first and applies afterwards. See <doc:Loading-Resources>.
