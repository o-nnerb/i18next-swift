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
formatters on top, using the system's `FormatStyle`, `DateFormatter` and `RelativeDateTimeFormatter`. It links the full
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
`maximumSignificantDigits`, `useGrouping`, `signDisplay`, `notation`, `style`, `currency`, `currencyDisplay` for
numbers; `dateStyle`, `timeStyle`, `timeZone`, `hour12` and the component options for dates; `numeric`, `style` and
`range` for relative times; `type` and `style` for lists.

### What differs from `Intl`

The behavior was checked against i18next 27.2.2 on thousands of values, and these are the known gaps:

- Numbers: `unit` style is not supported; `compact` notation uses the short names only.
- Dates: a JavaScript number is milliseconds since the epoch, as in i18next. Text is also read as an ISO 8601 date,
  which JSON has no type for. Time zone *names* can differ (`GMT` where `Intl` says `UTC`).
- Relative times need whole numbers and have no `quarter` unit.
- Lists have no `unit` type, and their items must be strings.

A value a formatter can't handle is left as it was, as in i18next. Results can differ between platforms and OS
releases wherever their ICU data does.

## Topics

### Formatters

- ``BuiltInFormats``
