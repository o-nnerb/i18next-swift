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

// Every scenario of a suite carries the suite's whole resource set, so long template lists are cut into suites of six.
function formatSuiteChunked(name, locales, templates, variables) {
    for (var start = 0, part = 1; start < templates.length; start += 6, part += 1) {
        formatSuite(name + '/' + part, locales, templates.slice(start, start + 6), variables);
    }
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

// style: unit. `unit` is one of ECMA-402's sanctioned units (or `<unit>-per-<unit>`); `unitDisplay` is long, short or narrow.
formatSuiteChunked('format/number[unit]', __someLocales, [
    '{{v, number(style: unit; unit: kilometer)}}',
    '{{v, number(style: unit; unit: kilometer; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: kilometer; unitDisplay: narrow)}}',
    '{{v, number(style: unit; unit: kilometer-per-hour)}}',
    '{{v, number(style: unit; unit: kilometer-per-hour; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: meter-per-second; unitDisplay: narrow)}}',
    '{{v, number(style: unit; unit: celsius; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: fahrenheit)}}',
    '{{v, number(style: unit; unit: liter; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: megabyte)}}',
    '{{v, number(style: unit; unit: gigabyte; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: byte; unitDisplay: narrow)}}',
    '{{v, number(style: unit; unit: kilogram; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: mile)}}',
    '{{v, number(style: unit; unit: foot; unitDisplay: narrow)}}',
    '{{v, number(style: unit; unit: degree)}}',
    '{{v, number(style: unit; unit: hour; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: minute)}}',
    '{{v, number(style: unit; unit: second; unitDisplay: narrow)}}',
    '{{v, number(style: unit; unit: kilometer; minimumFractionDigits: 2)}}',
    '{{v, number(style: unit; unit: kilometer; maximumFractionDigits: 0; unitDisplay: long)}}',
    '{{v, number(style: unit; unit: kilometer; signDisplay: always)}}',
    '{{v, number(style: unit; unit: kilometer; useGrouping: false)}}'
], [{ v: 1 }, { v: 2.5 }, { v: -16 }, { v: 1234.5 }, { v: 0 }]);

formatSuiteChunked('format/number[unit, other units]', __someLocales, [
    'acre', 'hectare', 'gram', 'mile-per-hour', 'gallon', 'yard', 'inch', 'terabit',
    'petabyte', 'ounce', 'pound', 'milliliter', 'centimeter', 'kilobit', 'meter', 'millimeter', 'kilobyte', 'megabit',
    'gigabit', 'terabyte', 'fluid-ounce', 'stone', 'bit'
].map(function (unit) { return '{{v, number(style: unit; unit: ' + unit + '; unitDisplay: long)}} {{v, number(style: unit; unit: ' + unit + ')}}'; }), [{ v: 1 }, { v: 2.5 }]);

// What Foundation can't format (documented in the tests): a sample is enough to keep the difference visible.
formatSuiteChunked('format/number[unit, unsupported]', ['en-US', 'de-DE'], [
    'day', 'week', 'month', 'year', 'percent', 'mile-per-gallon', 'kilometer-per-day', 'mile-scandinavian', 'millisecond',
    'microsecond', 'nanosecond'
].map(function (unit) { return '{{v, number(style: unit; unit: ' + unit + '; unitDisplay: long)}}'; }), [{ v: 2.5 }]);

formatSuiteChunked('format/number[unit, bad input]', ['en-US', 'de-DE'], [
    '{{v, number(style: unit)}}',
    '{{v, number(style: unit; unit: parsec)}}',
    '{{v, number(style: unit; unit: kilometer; unitDisplay: huge)}}',
    '{{v, number(style: unit; unit: kilometer-per-)}}',
    '{{v, number(unit: kilometer)}}',
    '{{v, number(style: unit; unit: Kilometer)}}'
], [{ v: 3 }, { v: 'abc' }]);

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

// Time zone names: 1_689_000_000_000 ms is 2023-07-10T14:00:00Z, so the zones with daylight saving are in summer time.
var __summer = 1689000000000;
var __zoneNames = ['short', 'long', 'shortOffset', 'longOffset', 'shortGeneric', 'longGeneric'];
var __zones = ['UTC', 'America/Sao_Paulo', 'America/New_York', 'Asia/Tokyo', 'Europe/Berlin', 'Asia/Kolkata', 'Australia/Sydney'];
var __zoneTemplates = [];
__zoneNames.forEach(function (name) {
    __zones.forEach(function (zone) {
        __zoneTemplates.push('{{d, datetime(hour: numeric; minute: numeric; timeZoneName: ' + name + '; timeZone: ' + zone + ')}}');
    });
});
formatSuiteChunked('format/datetime[timeZoneName]', ['en-US', 'pt-BR', 'de-DE', 'fr-FR', 'ja-JP', 'es-ES'], __zoneTemplates, [{ d: __when }, { d: __summer }]);

formatSuiteChunked('format/datetime[timeStyle with zone]', ['en-US', 'pt-BR', 'de-DE', 'ja-JP'], [
    '{{d, datetime(timeStyle: long; timeZone: UTC)}}',
    '{{d, datetime(timeStyle: full; timeZone: UTC)}}',
    '{{d, datetime(dateStyle: full; timeStyle: full; timeZone: UTC)}}',
    '{{d, datetime(timeStyle: long; timeZone: America/Sao_Paulo)}}',
    '{{d, datetime(timeStyle: full; timeZone: America/New_York)}}',
    '{{d, datetime(dateStyle: long; timeStyle: long; timeZone: Europe/Berlin)}}',
    '{{d, datetime(dateStyle: medium; timeStyle: full; timeZone: Asia/Tokyo)}}',
    '{{d, datetime(year: numeric; month: short; day: numeric; hour: numeric; minute: numeric; timeZoneName: short; timeZone: America/New_York)}}',
    '{{d, datetime(weekday: long; hour: numeric; timeZoneName: long; timeZone: Asia/Kolkata)}}',
    '{{d, datetime(timeZoneName: short; timeZone: UTC)}}',
    '{{d, datetime(timeZoneName: long; timeZone: Europe/Berlin)}}',
    '{{d, datetime(timeZoneName: nope; timeZone: UTC)}}'
], [{ d: __when }, { d: __summer }]);

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

var __moreLocales = ['en-GB', 'zh-CN', 'zh-Hant-TW', 'ko-KR', 'it-IT', 'pt-PT', 'es-MX', 'nl-NL', 'tr-TR', 'pl-PL', 'he-IL', 'id-ID', 'sv-SE', 'th-TH', 'vi-VN', 'uk-UA'];

formatSuiteChunked('format/list[unit]', __someLocales.concat(__moreLocales), [
    '{{l, list(type: unit)}}',
    '{{l, list(type: unit; style: long)}}',
    '{{l, list(type: unit; style: short)}}',
    '{{l, list(type: unit; style: narrow)}}',
    '{{l, list(type: conjunction; style: narrow)}}',
    '{{l, list(type: disjunction; style: narrow)}}'
], [{ l: ['a', 'b', 'c'] }, { l: ['a', 'b'] }, { l: ['a'] }, { l: [] }, { l: ['5 km', '3 m', '2 cm', '1 mm'] }]);

formatSuite('format/list[other locales]', ['ar-EG', 'hi-IN', 'ru-RU'], [
    '{{l, list}}', '{{l, list(type: disjunction)}}', '{{l, list(style: short)}}', '{{l, list(style: narrow)}}'
], [{ l: ['a', 'b', 'c'] }, { l: ['a', 'b'] }]);

// MARK: format chains and unknown formats

formatSuite('format/chain', ['en-US'], [
    '{{v, number, nosuchformat}}', '{{v, NUMBER}}', '{{ v , Number }}', '{{v, number(minimumFractionDigits: 1, maximumFractionDigits: 1)}}',
    '{{v, number(minimumFractionDigits: 1.9)}}'
], [{ v: 1234.5678 }]);
