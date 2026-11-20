# Plurals

How a count selects a plural form.

## Overview

Pass ``TranslationOptions/count`` and provide one key per category, using the i18next v4 suffixes:

```json
{
  "item_one": "{{count}} item",
  "item_other": "{{count}} items",
  "item_zero": "no items"
}
```

``PluralResolver`` picks the category from the CLDR rules of the language being resolved, so a Russian count of 3
selects `_few` and an Arabic count of 0 selects `_zero`. An exact `_zero` key wins when the count is 0, and the plain
key is the last resort.

Ordinals use ``TranslationOptions/ordinal`` and `key_ordinal_one`, `key_ordinal_two`, and so on.

## Where the rules come from

The rules are generated from the Unicode CLDR (release 49) by `Scripts/generate-plurals.py`: 227 cardinal and 110
ordinal locales. The tests run every rule against the samples CLDR publishes next to it.

A language is looked up by its exact tag (`pt-PT`), then by its language part (`pt`). An unknown language gets the
English cardinal rules and no ordinal rules, which is what `Intl.PluralRules` does.

## Limits

A `Double` has no trailing zeros, so `1.0` counts as `1`, as it does in JavaScript. Compact-notation operands (`c`,
`e`) are always 0, as for any plain number.
