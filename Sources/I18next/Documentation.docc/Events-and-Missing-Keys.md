# Events and missing keys

React to what happens inside an instance, and capture the keys your translations are missing.

## Events

``I18next/events`` is a stream of ``I18nextEvent``. Every access gives an independent stream that sees events from
the moment it was created:

```swift
Task {
    for await event in i18n.events {
        switch event {
        case .languageChanged(let language): updateUI(language)
        case .failedLoading(let failure): log(failure)
        case .missingKey(let missing, _): report(missing)
        default: break
        }
    }
}
```

## Reporting missing keys

With ``I18next/Options/saveMissing`` on, a key `t` can't resolve is reported: to ``I18next/Options/missingKeyHandler``
if you set one, otherwise to the backend's `create` (see ``Backend``). It is also stored under the first language, so
it resolves from then on, as in i18next.

- ``I18next/Options/saveMissingTo`` picks the languages: the fallbacks, the current language, or the whole hierarchy.
- With a count, ``I18next/Options/saveMissingPlurals`` reports every plural form of the language
  (`key_zero` … `key_other`), using `defaultValue_one`-style defaults where you gave them.
- ``I18next/Options/updateMissing`` also reports keys whose text differs from the `defaultValue` you passed.
- ``I18next/Options/appendNamespaceToMissingKey`` makes a missing key come back as `ns:key`, and
  ``I18next/Options/parseMissingKeyHandler`` lets you decide the text.

A key that has no `defaultValue` is reported with its own name as the value. Set
``I18next/Options/missingKeyNoValueFallbackToKey`` (or ``TranslationOptions/missingKeyNoValueFallbackToKey`` for one
call; a call can turn it on but not off, as in i18next) to report it without a value, so a translation tool can tell
a key that still needs text from one that has it.
