// Copyright (c) 2026 Brenno Giovanini de Moura
// SPDX-License-Identifier: MIT

import I18next

/// The formatters i18next ships, backed by Foundation: `number`, `currency`, `datetime`, `relativetime` and `list`.
///
/// Use them in a template as `{{value, number(minimumFractionDigits: 2)}}`, `{{price, currency(EUR)}}`,
/// `{{when, datetime(dateStyle: long)}}`, `{{-3, relativetime(day)}}` or `{{names, list}}`. Options come from the
/// template, from the call (`.init(variables: ["style": "percent"])`) and from a per-variable
/// `formatParams` entry, the last winning. Values `Intl` rejects are left as they are.
///
/// ```swift
/// var options = I18next.Options()
/// options.formats = BuiltInFormats.all
/// ```
public enum BuiltInFormats {
    public static var all: [String: I18next.Format] {
        [
            "number": NumberFormats.number,
            "currency": NumberFormats.currency,
            "datetime": DateFormats.datetime,
            "relativetime": DateFormats.relativetime,
            "list": ListFormats.list,
        ]
    }
}

extension I18next {
    /// Registers `BuiltInFormats` on an existing instance.
    public func addBuiltInFormats() {
        for (name, format) in BuiltInFormats.all { addFormat(name, format) }
    }
}
