# Language detection

Pick the language from the device when you haven't chosen one.

## Overview

Set ``I18next/Options/languageDetector`` and leave ``I18next/Options/lng`` unset. ``I18next/initialize()`` asks the
detector for candidates, in priority order, and takes the first that ``I18next/Options/supportedLngs`` allows. If none
is, it narrows a candidate to its supported language part (`pt-BR` → `pt`), and finally uses the first fallback.

```swift
let i18n = I18next { options in
    options.fallbackLng = ["en"]
    options.supportedLngs = ["en", "pt", "fr"]
    options.languageDetector = SystemLanguageDetector()
    options.backend = FileSystemBackend(directory: localesPath)
}
await i18n.initialize()
```

``SystemLanguageDetector`` reads the user's preferred languages on Apple platforms, and `LANGUAGE`, `LC_ALL`,
`LC_MESSAGES` and `LANG` elsewhere. Write your own by conforming to ``LanguageDetector``; its
``LanguageDetector/cacheUserLanguage(_:)`` is called with the language that was chosen, so you can remember it.

``I18next/changeLanguage(_:)`` with `nil` detects again.

With ``I18next/Options/nonExplicitSupportedLngs``, a regional variant such as `de-AT` is accepted when `de` is
supported.
