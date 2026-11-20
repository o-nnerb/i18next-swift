// Scenarios for the built-in formatters, taken from the i18next documentation and test suite
// (test/runtime/i18next.translation.formatting.test.js, MIT, Copyright (c) 2011-present i18next).
// Inputs only: the harness records what i18next 27.2.2 answers, using this machine's ICU (Intl).

function formatSuite(name, locales, templates, variables) {
    locales.forEach(function (lng) {
        var resources = {};
        resources[lng] = { translation: {} };
        var tests = [];
        templates.forEach(function (template, index) {
            resources[lng].translation['k' + index] = template;
            variables.forEach(function (vars) { tests.push(['k' + index, vars]); });
        });
        suite(name + '[' + lng + ']', 'i18next.translation.formatting.test.js', { lng: lng, fallbackLng: false, resources: resources }, tests);
    });
}

var __someLocales = ['en-US', 'pt-BR', 'de-DE', 'fr-FR', 'ja-JP', 'es-ES', 'ar-EG', 'hi-IN', 'ru-RU'];

// MARK: number

formatSuite('format/number', __someLocales, [
    '{{v, number}}',
    '{{v, number(minimumFractionDigits: 2)}}',
    '{{v, number(maximumFractionDigits: 0)}}',
    '{{v, number(minimumFractionDigits: 1; maximumFractionDigits: 1)}}',
    '{{v, number(minimumIntegerDigits: 6)}}',
    '{{v, number(maximumSignificantDigits: 3)}}',
    '{{v, number(minimumSignificantDigits: 8)}}',
    '{{v, number(useGrouping: false)}}',
    '{{v, number(signDisplay: always)}}',
    '{{v, number(signDisplay: never)}}',
    '{{v, number(signDisplay: exceptZero)}}'
], [{ v: 1234567.891 }, { v: -42.5 }, { v: 0 }, { v: 0.000123 }, { v: 1000 }]);

formatSuite('format/number[percent]', __someLocales, [
    '{{v, number(style: percent)}}',
    '{{v, number(style: percent; minimumFractionDigits: 1)}}',
    '{{v, number(style: percent; maximumFractionDigits: 2)}}'
], [{ v: 0.256 }, { v: 1 }, { v: -0.5 }, { v: 12.3456 }]);

formatSuite('format/number[strings and bad input]', ['en-US', 'de-DE'], [
    '{{v, number}}', '{{v, number(minimumFractionDigits: 200)}}', '{{v, number(style: weird)}}'
], [{ v: '1234.5' }, { v: 'abc' }, { v: true }, { v: 12 }]);

formatSuite('format/number[compact]', ['en-US', 'de-DE', 'ja-JP'], [
    '{{v, number(notation: compact)}}'
], [{ v: 1234 }, { v: 1234567 }, { v: 12 }]);

// MARK: currency

formatSuite('format/currency', __someLocales, [
    '{{v, currency(USD)}}',
    '{{v, currency(EUR)}}',
    '{{v, currency(JPY)}}',
    '{{v, currency(currency: BRL)}}',
    '{{v, currency(currency: EUR; currencyDisplay: code)}}',
    '{{v, currency(currency: EUR; currencyDisplay: name)}}',
    '{{v, currency(currency: USD; currencyDisplay: narrowSymbol)}}',
    '{{v, currency(currency: USD; minimumFractionDigits: 0; maximumFractionDigits: 0)}}',
    '{{v, currency(currency: USD; signDisplay: always)}}',
    '{{v, currency}}'
], [{ v: 1234567.891 }, { v: -42.5 }, { v: 0 }, { v: 5 }]);

formatSuite('format/currency[formatParams]', ['en-US'], [
    '{{amount, currency}}', '{{amount, currency}} / {{other, currency(USD)}}'
], [{ amount: 1234.5, other: 2, formatParams: { amount: { currency: 'EUR', locale: 'de-DE' }, other: { locale: 'fr-FR' } } },
    { amount: 1234.5, formatParams: { amount: { currency: 'JPY' } } },
    { amount: 1234.5, currency: 'GBP' }]);

// MARK: datetime (1_700_000_000_000 ms is 2023-11-14T22:13:20Z; fixed zone so the result doesn't depend on this machine)

var __when = 1700000000000;
var __zone = 'timeZone: UTC';

formatSuite('format/datetime', ['en-US', 'pt-BR', 'de-DE', 'fr-FR', 'ja-JP', 'es-ES'], [
    '{{d, datetime(' + __zone + ')}}',
    '{{d, datetime(dateStyle: full; ' + __zone + ')}}',
    '{{d, datetime(dateStyle: long; ' + __zone + ')}}',
    '{{d, datetime(dateStyle: medium; ' + __zone + ')}}',
    '{{d, datetime(dateStyle: short; ' + __zone + ')}}',
    '{{d, datetime(timeStyle: short; ' + __zone + ')}}',
    '{{d, datetime(timeStyle: medium; ' + __zone + ')}}',
    '{{d, datetime(dateStyle: medium; timeStyle: short; ' + __zone + ')}}',
    '{{d, datetime(year: numeric; month: long; day: numeric; ' + __zone + ')}}',
    '{{d, datetime(year: 2-digit; month: 2-digit; day: 2-digit; ' + __zone + ')}}',
    '{{d, datetime(weekday: long; ' + __zone + ')}}',
    '{{d, datetime(weekday: short; month: short; day: numeric; ' + __zone + ')}}',
    '{{d, datetime(month: long; year: numeric; ' + __zone + ')}}',
    '{{d, datetime(hour: numeric; minute: numeric; ' + __zone + ')}}',
    '{{d, datetime(hour: 2-digit; minute: 2-digit; second: 2-digit; hour12: false; ' + __zone + ')}}',
    '{{d, datetime(hour: numeric; minute: numeric; hour12: true; ' + __zone + ')}}',
    '{{d, datetime(hour: numeric; minute: numeric; timeZoneName: short; ' + __zone + ')}}',
    '{{d, datetime(dateStyle: full; timeZone: America/Sao_Paulo)}}',
    '{{d, datetime(dateStyle: short; timeStyle: short; timeZone: Asia/Tokyo)}}'
], [{ d: __when }]);

// Every datetime template pins `timeZone`, so the expected values don't depend on the machine that generated them.
formatSuite('format/datetime[bad input]', ['en-US'], [
    '{{d, datetime(' + __zone + ')}}', '{{d, datetime(dateStyle: long; year: numeric; ' + __zone + ')}}',
    '{{d, datetime(dateStyle: nope; ' + __zone + ')}}'
], [{ d: __when }, { d: 'not a date' }, { d: true }, { d: false }, { d: '1700000000000' }]);

// MARK: relativetime

formatSuite('format/relativetime', ['en-US', 'pt-BR', 'de-DE', 'fr-FR', 'ja-JP', 'es-ES'], [
    '{{n, relativetime}}',
    '{{n, relativetime(hour)}}',
    '{{n, relativetime(minute)}}',
    '{{n, relativetime(second)}}',
    '{{n, relativetime(week)}}',
    '{{n, relativetime(month)}}',
    '{{n, relativetime(year)}}',
    '{{n, relativetime(quarter)}}',
    '{{n, relativetime(range: day; numeric: auto)}}',
    '{{n, relativetime(range: year; numeric: auto)}}',
    '{{n, relativetime(range: day; style: short)}}',
    '{{n, relativetime(range: day; style: narrow)}}',
    '{{n, relativetime(range: weeks)}}'
], [{ n: -1 }, { n: 1 }, { n: 0 }, { n: -3 }, { n: 3 }, { n: 2.5 }]);

// MARK: list

formatSuite('format/list', ['en-US', 'pt-BR', 'de-DE', 'fr-FR', 'ja-JP', 'es-ES'], [
    '{{l, list}}',
    '{{l, list(type: disjunction)}}',
    '{{l, list(style: short)}}',
    '{{l, list(style: narrow)}}',
    '{{l, list(type: disjunction; style: short)}}',
    '{{l, list(type: unit)}}'
], [{ l: ['a', 'b', 'c'] }, { l: ['a', 'b'] }, { l: ['a'] }, { l: [] }, { l: [1, 2, 3] }, { l: 'abc' }]);

// MARK: format chains and unknown formats

formatSuite('format/chain', ['en-US'], [
    '{{v, number, nosuchformat}}', '{{v, NUMBER}}', '{{ v , Number }}', '{{v, number(minimumFractionDigits: 1, maximumFractionDigits: 1)}}',
    '{{v, number(minimumFractionDigits: 1.9)}}'
], [{ v: 1234.5678 }]);
