# ``I18nextFormatters``

The formatters i18next ships (`number`, `currency`, `datetime`, `relativetime`, `list`), backed by Foundation.

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

`I18next` keeps formatting out of its core so that it needs nothing beyond `FoundationEssentials`. This module adds the
formatters on top, using the system's `FormatStyle`, `Measurement`, `DateFormatter` and `RelativeDateTimeFormatter`. It links the full
Foundation on Linux, which the core does not.

```swift
import I18nextFormatters

let i18n = I18next { options in
    options.lng = "pt-BR"
    options.formats = BuiltInFormats.all
    options.resources = ["pt-BR": ["translation": [
        "price": "Total: {{amount, currency(BRL)}}",
        "when": "Em {{date, datetime(dateStyle: long)}}",
        "ago": "{{n, relativetime(day)}}",
        "team": "{{names, list}}",
    ]]]
}

i18n.t("price", .init(variables: ["amount": 1234.5]))        // "Total: R$ 1.234,50"
i18n.t("ago", .init(variables: ["n": -3]))                   // "há 3 dias"
```

Or add them to an instance you already have with ``I18next/I18next/addBuiltInFormats()``.

### Options

A format takes its options, last one winning, from the template (`number(minimumFractionDigits: 2; style: percent)`),
from the variables of the call, and from a per-variable `formatParams` entry, which can also set the `locale`:

```swift
i18n.t("price", .init(variables: [
    "amount": 1234.5,
    "formatParams": ["amount": ["currency": "EUR", "locale": "de-DE"]],
]))
```

The options are `Intl`'s: `minimumFractionDigits`, `maximumFractionDigits`, `minimumIntegerDigits`,
`maximumSignificantDigits`, `useGrouping`, `signDisplay`, `notation`, `style`, `currency`, `currencyDisplay`, `unit`
and `unitDisplay` for numbers; `dateStyle`, `timeStyle`, `timeZone`, `timeZoneName`, `hour12` and the component options
for dates; `numeric`, `style` and `range` for relative times; `type` and `style` for lists.

### What differs from `Intl`

The behavior was checked against i18next 27.2.2 on thousands of values (6,421 scenarios, on Apple platforms), and these
are the known gaps:

- Numbers: `compact` notation uses the short names only. `style: unit` goes through Foundation's `Measurement`, which has
  no unit for `day`, `week`, `month`, `year`, `percent`, `mile-scandinavian`, `mile-per-gallon`, compounds such as
  `kilometer-per-day`, and does not translate `millisecond`, `microsecond` and `nanosecond` for every locale; those
  are left as written. The others (length, mass, volume, temperature, speed, information storage, `second` to
  `hour`, …) match `Intl`. Outside Apple platforms Foundation has no `Measurement.FormatStyle`, so `style: unit` leaves
  every value as written there.
- Dates: a JavaScript number is milliseconds since the epoch, as in i18next. Text is also read as an ISO 8601 date,
  which JSON has no type for. `UTC`, `GMT` and `Etc/UTC` are one zone named "UTC", as in `Intl`; other zone names
  (`timeZoneName`, `timeStyle: full`) are Foundation's, and matched `Intl` in every fixture on this macOS.
- Relative times are phrased from a table (`CLDRRelativeTimeData`) of what `Intl.RelativeTimeFormat` prints, so
  fractions ("in 2.5 days"), quarters and `numeric: auto` work on every platform. It covers 48 locales: Arabic,
  Bengali, Bulgarian, Catalan, Chinese (Simplified, Traditional, Hong Kong), Croatian, Czech, Danish, Dutch, English
  (AU, GB, IN), Finnish, French (CA), German, Greek, Hebrew, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean,
  Malay, Norwegian (`nb`, `no`), Persian, Polish, Portuguese (PT), Romanian, Russian, Serbian, Slovak, Slovenian,
  Spanish (419, MX, US), Swedish, Thai, Turkish, Ukrainian and Vietnamese. Another region of those languages reads its
  language's phrases (Argentine Spanish reads `es-419`'s), which `Intl` words slightly differently for some regions.
  For any other locale, Apple platforms use `RelativeDateTimeFormatter`, which takes whole numbers only and has no
  `quarter` unit; elsewhere (swift-corelibs-foundation has no such formatter) the value is left as it is.
- Lists: `unit` lists come from a table of patterns (`CLDRListPatternData`, all locales) read out of the ICU on macOS, so
  they work on every platform; their items must be strings.

A value a formatter can't handle is left as it was, as in i18next. Results can differ between platforms and OS
releases wherever their ICU data does.

## Topics

### Formatters

- ``BuiltInFormats``
