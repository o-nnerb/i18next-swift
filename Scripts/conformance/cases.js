// Scenarios taken from the i18next test suite (test/runtime/**, MIT, Copyright (c) 2011-present i18next).
// The harness runs each one against the real i18next and records the answer, so nothing here states an expected
// value: only inputs. Keep the `source` of every suite pointing at the upstream file it came from.

// MARK: translator.translate.test.js

suite('translate/basic', 'translator.translate.test.js', {
    lng: 'en', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation',
    resources: {
        en: { translation: { test: 'test_en', deep: { test: 'deep_en' } } },
        de: { translation: { test: 'test_de' } }
    }
}, [
    ['translation:test'],
    ['translation:test', { lngs: ['en-US', 'en'] }],
    ['translation:test', { lngs: ['de'] }],
    ['translation:test', { lng: 'de' }],
    ['translation:test', { lng: 'fr' }],
    ['translation:test', { lng: 'en-US' }],
    ['translation.test', { lng: 'en-US', nsSeparator: '.' }],
    ['translation.deep.test', { lng: 'en-US', nsSeparator: '.' }],
    ['deep.test', { lng: 'en-US', nsSeparator: '.' }],
    ['deep'],
    ['missing'],
    ['translation:missing'],
    ['other:test']
]);

// MARK: translator.translate.context.test.js

suite('translate/context', 'translator.translate.context.test.js', {
    lng: 'en', fallbackLng: 'en', contextSeparator: '_',
    resources: {
        en: { translation: { test: 'test_en', test_male: 'test_male_en', test_female: 'test_female_en', test_1: 'test_one_en' } },
        de: { translation: { test: 'test_de', test_male: 'test_male_de', test_female: 'test_female_de', test_1: 'test_one_de' } }
    }
}, [
    ['translation:test', { context: 'unknown' }],
    ['translation:test', { context: 'male' }],
    ['translation:test', { context: 'female' }],
    ['translation:test', { context: 'male', lngs: ['en-US', 'en'] }],
    ['translation:test', { context: 'male', lngs: ['de'] }],
    ['translation:test', { context: 'female', lngs: ['de'] }],
    ['translation:test', { context: 'male', lng: 'de' }],
    ['translation:test', { context: 'female', lng: 'de' }],
    ['translation:test', { context: 'male', lng: 'fr' }],
    ['translation:test', { context: 'female', lng: 'fr' }],
    ['translation:test', { context: 'male', lng: 'en-US' }],
    ['translation:test', { context: '1', lng: 'en-US' }],
    ['translation:test', { context: '1', lng: 'de' }],
    ['translation:test', { context: 1, lng: 'en-US' }],
    ['translation:test', { context: 1, lng: 'de' }],
    ['translation:test', { context: '' }]
]);

// MARK: translator.translate.plural.test.js

suite('translate/plural', 'translator.translate.plural.test.js', {
    lng: 'en', fallbackLng: 'en', pluralSeparator: '_',
    resources: {
        en: {
            translation: {
                test_one: 'test_en', test_other: 'tests_en',
                pos_test_ordinal_one: 'pos_test_en_one', pos_test_ordinal_two: 'pos_test_en_two',
                pos_test_ordinal_few: 'pos_test_en_few', pos_test_ordinal_other: 'pos_test_en_other',
                oTest_ordinal_one: 'Every {{count}}st month', oTest_one: 'Every month',
                oTest_month_ordinal_one: 'Every {{count}}st month (ctx)', oTest_month_one: 'Every month (ctx)'
            },
            translationWithZero: { test_zero: 'test_zero', test_one: 'test_en', test_other: 'tests_en' }
        },
        de: { translation: { test_one: 'test_de', test_other: 'tests_de' } },
        ja: { translation: { test: 'test_ja', test_other: 'tests_ja' } },
        ar: {
            translation: {
                test: 'test_ar', test_few: 'tests_ar_few', test_many: 'tests_ar_many', test_one: 'tests_ar_one',
                test_two: 'tests_ar_two', test_zero: 'tests_ar_zero', test_other: 'tests_ar_other'
            }
        },
        it: { translation: { test: 'test_it', test_other: 'tests_it_other', test_many: 'tests_it_many' } }
    }
}, [
    ['translation:test', { count: 1 }],
    ['translation:test', { count: 2 }],
    ['translation:test', { count: 0 }],
    ['translation:pos_test', { count: 0, ordinal: true }],
    ['translation:pos_test', { count: 1, ordinal: true }],
    ['translation:pos_test', { count: 2, ordinal: true }],
    ['translation:pos_test', { count: 3, ordinal: true }],
    ['translation:pos_test', { count: 4, ordinal: true }],
    ['translationWithZero:test', { count: 0 }],
    ['translation:test', { count: 1, lngs: ['en-US', 'en'] }],
    ['translation:test', { count: 2, lngs: ['en-US', 'en'] }],
    ['translation:test', { count: 1, lngs: ['de'] }],
    ['translation:test', { count: 2, lngs: ['de'] }],
    ['translation:test', { count: 1, lng: 'de' }],
    ['translation:test', { count: 2, lng: 'de' }],
    ['translation:test', { count: 1, lng: 'fr' }],
    ['translation:test', { count: 2, lng: 'fr' }],
    ['translation:test', { count: 1, lng: 'en-US' }],
    ['translation:test', { count: 2, lng: 'en-US' }],
    ['translation:test', { count: 1, lng: 'ja' }],
    ['translation:test', { count: 2, lng: 'ja' }],
    ['translation:test', { count: 10, lng: 'ja' }],
    ['translation:test', { count: 0, lng: 'ar' }],
    ['translation:test', { count: 1, lng: 'ar' }],
    ['translation:test', { count: 2, lng: 'ar' }],
    ['translation:test', { count: 3, lng: 'ar' }],
    ['translation:test', { count: 15, lng: 'ar' }],
    ['translation:test', { count: 101, lng: 'ar' }],
    ['translation:test', { count: 0, lng: 'ar', ordinal: true }],
    ['translation:test', { count: 1, lng: 'ar', ordinal: true }],
    ['translation:test', { count: 2, lng: 'ar', ordinal: true }],
    ['translation:test', { count: 3, lng: 'ar', ordinal: true }],
    ['translation:test', { count: 15, lng: 'ar', ordinal: true }],
    ['translation:test', { count: 0, lng: 'it' }],
    ['translation:test', { count: 1, lng: 'it' }],
    ['translation:test', { count: 2, lng: 'it' }],
    ['translation:test', { count: 11, lng: 'it' }],
    ['translation:test', { count: 0, lng: 'it', ordinal: true }],
    ['translation:test', { count: 1, lng: 'it', ordinal: true }],
    ['translation:test', { count: 2, lng: 'it', ordinal: true }],
    ['translation:test', { count: 11, lng: 'it', ordinal: true }],
    ['translation:oTest', { count: 1, lng: 'en', ordinal: true }],
    ['translation:oTest', { count: 1, lng: 'en' }],
    ['translation:oTest', { count: 1, lng: 'en', ordinal: true, context: 'month' }],
    ['translation:oTest', { count: 1, lng: 'en', context: 'month' }],
    ['translation:test', { count: 1.5 }],
    ['translation:test', { count: '1' }],
    ['translation:test', { count: -1 }]
]);

// MARK: translator.translate.defaultValue.test.js

suite('translate/defaultValue', 'translator.translate.defaultValue.test.js', {
    lng: 'en', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation', pluralSeparator: '_',
    resources: { en: { translation: {} } }
}, [
    ['translation:test', { defaultValue: 'test_en' }],
    ['translation:test', { defaultValue: 'test_en', count: 1 }],
    ['translation:test', { defaultValue_other: 'test_en_plural', defaultValue_one: 'test_en', count: 10 }],
    ['translation:test', { defaultValue_other: 'test_en_plural', defaultValue_one: 'test_en', count: 1 }],
    ['translation:testMe', { defaultValue_other: 'test_en_plural', defaultValue_one: 'test_en', defaultValue_zero: 'test_en_zero', count: 0 }],
    ['translation:testMe', { defaultValue: 'Hello {{name}}', name: 'Ann' }],
    ['translation:testMe', { defaultValue: 'Hello {{name}}', replace: { name: 'Ann' } }]
]);

// MARK: translator.translate.separator.test.js

suite('translate/separator', 'translator.translate.separator.test.js', {
    lng: 'en', fallbackLng: 'en', keySeparator: '::', nsSeparator: ':::',
    resources: {
        en: {
            translation: { test: 'test_en', deep: { test: 'testDeep_en' }, 'test::single': 'single_en', 'test.single': 'single_en' },
            translation2: { test: 'test2_en' }
        }
    }
}, [
    ['translation:::test'],
    ['translation2:::test'],
    ['translation:::deep::test'],
    ['translation:test', { nsSeparator: ':', keySeparator: '.' }],
    ['translation2:test', { nsSeparator: ':', keySeparator: '.' }],
    ['translation:deep.test', { nsSeparator: ':', keySeparator: '.' }],
    ['translation:::test::single', { keySeparator: false }],
    ['translation:::test.single', { keySeparator: false }]
]);

// MARK: translator.translate.noSeparator.test.js

suite('translate/noSeparator', 'translator.translate.noSeparator.test.js', {
    lng: 'en', fallbackLng: 'en', ns: ['translation'], defaultNS: 'translation', nsSeparator: false, keySeparator: false,
    resources: {
        en: { translation: { 'test: with a sentence. or more text': 'test_en' } },
        de: { translation: { 'test: with a sentence. or more text': 'test_de' } }
    }
}, [
    ['test: with a sentence. or more text'],
    ['test: with a sentence. or more text', { lngs: ['en-US', 'en'] }],
    ['test: with a sentence. or more text', { lngs: ['de'] }],
    ['test: with a sentence. or more text', { lng: 'de' }],
    ['test: with a sentence. or more text', { lng: 'fr' }],
    ['test: with a sentence. or more text', { lng: 'en-US' }]
]);

// MARK: translator.translate.escape.test.js

suite('translate/escape', 'translator.translate.escape.test.js', {
    lng: 'en', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation', interpolation: { escapeValue: true },
    resources: { en: { translation: { test: 'text {{var}}' } } }
}, [
    ['translation:test', { var: 'a&b' }],
    ['translation:test', { var: 'a&b', interpolation: { escapeValue: false } }],
    ['translation:test', { var: ['a', 'b'] }],
    ['translation:test', { var: '<b>"x" \'y\' /</b>' }],
    ['translation:test', { var: 12 }],
    ['translation:test', { var: true }],
    ['translation:test', { var: null }]
]);

// MARK: translator.fallbackLng.test.js

suite('translate/fallbackLng', 'translator.fallbackLng.test.js', {
    lng: 'de', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation',
    resources: {
        en: { translation: { test: 'test_en', notInDE: 'test_notInDE_en', roles: { constructor: 'roles_constructor_en' } } },
        fr: { translation: { test: 'test_fr', notInDE: 'test_notInDE_fr' } },
        de: { translation: { test: 'test_de', roles: { admin: 'roles_admin_de' } } }
    }
}, [
    ['translation:notInDE', {}],
    ['translation:notInDE', { fallbackLng: 'fr' }],
    ['translation:roles.constructor', {}],
    ['translation:roles.toString', {}],
    ['translation:roles.__proto__', {}],
    ['translation:toString', {}]
]);

// MARK: translator.naturalLng.test.js

suite('translate/naturalLng', 'translator.naturalLng.test.js', {
    lng: 'en', fallbackLng: 'en',
    resources: {
        en: {
            translation: {
                'test: with a sentence. or more text': 'test_en',
                errorCodes: { UNAUTHORIZED: 'Unauthorized', 'BAD REQUEST': 'Bad request' },
                UNAUTHORIZED: 'Unauthorized 2', 'BAD REQUEST': 'Bad request 2'
            },
            test: { anotherKey: 'from other ns', 'key with space': 'key with space from other ns' }
        },
        de: { translation: { 'test: with a sentence. or more text': 'test_de' } }
    }
}, [
    ['test: with a sentence. or more text'],
    ['test: with a sentence. or more text', { lngs: ['en-US', 'en'] }],
    ['test: with a sentence. or more text', { lngs: ['de'] }],
    ['test: with a sentence. or more text', { lng: 'de' }],
    ['test: with a sentence. or more text', { lng: 'fr' }],
    ['test: with a sentence. or more text', { lng: 'en-US' }],
    ['test:anotherKey', { lng: 'en' }],
    ['errorCodes.UNAUTHORIZED', { lng: 'en' }],
    ['errorCodes.BAD REQUEST', { lng: 'en' }],
    ['translation:errorCodes.UNAUTHORIZED', { lng: 'en' }],
    ['translation:errorCodes.BAD REQUEST', { lng: 'en' }],
    ['translation:UNAUTHORIZED', { lng: 'en' }],
    ['translation:BAD REQUEST', { lng: 'en', keySeparator: '.' }],
    ['test:key with space', { lng: 'en', nsSeparator: ':' }]
]);

// MARK: translator.exists.test.js

suite('translate/exists', 'translator.exists.test.js', {
    lng: 'en', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation',
    resources: {
        en: { translation: { test: 'test_en', deep: { test: 'deep_en' } } },
        de: { translation: { test: 'test_de' } }
    }
}, [
    ['translation:test'],
    ['translation:test', { lngs: ['en-US', 'en'] }],
    ['translation:test', { lngs: ['de'] }],
    ['translation:test', { lng: 'de' }],
    ['translation:test', { lng: 'fr' }],
    ['translation:test', { lng: 'en-US' }],
    ['translation.test', { lng: 'en-US', nsSeparator: '.' }],
    ['translation.deep.test', { lng: 'en-US', nsSeparator: '.' }],
    ['deep.test', { lng: 'en-US', nsSeparator: '.' }],
    ['missing'],
    ['']
], { kind: 'exists' });

// MARK: interpolation.test.js
// The upstream tests call the Interpolator directly; here each template lives in a resource and is read with `t`.

function interpolationSuite(name, source, init, cases) {
    var resources = { en: { translation: {} } };
    var tests = cases.map(function (c, index) {
        resources.en.translation['k' + index] = c[0];
        return ['k' + index, c[1]];
    });
    suite(name, source, Object.assign({ lng: 'en', fallbackLng: 'en', resources: resources }, init), tests);
}

interpolationSuite('interpolation/basic', 'interpolation.test.js', { interpolation: { escapeValue: false } }, [
    ['test', { test: '123' }],
    ['test {{test}}', { test: '123' }],
    ['test {{test}} a {{bit.more}}', { test: '123', bit: { more: '456' } }],
    ['test {{ test }}', { test: '123' }],
    ['test {{ test }}', { test: null }],
    ['test {{ test }}', {}],
    ['test {{test.deep}}', { test: { deep: '123' } }],
    ['test {{test.constructor}}', { test: { deep: '123' } }],
    ['test {{test.toString}}', { test: {} }],
    ['{{a}}{{b}}{{a}}', { a: 'x', b: 'y' }],
    ['{{a}} and {{missing}} and {{a}}', { a: 'x' }],
    ['{{- a}}', { a: '<b>' }],
    ['{{a, nonexistent}}', { a: 'x' }],
    ['{{a}} {{', { a: 'x' }],
    ['}} {{a}}', { a: 'x' }],
    ['{{ }}', {}],
    ['{{}}', {}],
    ['{{count}} items', { count: 3 }],
    ['{{n}}', { n: 1.5 }],
    ['{{n}}', { n: 1e21 }],
    ['{{n}}', { n: 0 }],
    ['{{b}}', { b: false }],
    ['{{o}}', { o: { a: 1 } }],
    ['{{arr}}', { arr: [1, [2, 3], null] }]
]);

interpolationSuite('interpolation/escaped', 'translator.translate.escape.test.js', { interpolation: { escapeValue: true } }, [
    ['{{a}}', { a: '<>&"\'/`=' }],
    ['{{- a}}', { a: '<>&"\'/' }],
    ['{{a}}', { a: ['<', '>'] }],
    ['{{a.b}}', { a: { b: '<b>' } }]
]);

interpolationSuite('interpolation/defaultVariables', 'interpolation.test.js', {
    interpolation: { escapeValue: false, defaultVariables: { test: '123', bit: { more: '456' } } }
}, [
    ['test', {}],
    ['test {{test}}', {}],
    ['test {{test}} a {{bit.more}}', {}],
    ['test {{ test }}', { test: '124' }],
    ['test {{ test }}', { test: null }]
]);

[false, '::', '.'].forEach(function (keySeparator) {
    interpolationSuite('interpolation/keySeparator[' + keySeparator + ']', 'interpolation.test.js', {
        keySeparator: keySeparator, interpolation: { escapeValue: false }
    }, [
        ['{{stats.unread}}|{{stats.muted}}|{{stats.label}}|{{stats.total}}|{{flat.key}}',
            { stats: { unread: 0, muted: false, label: '', total: 3 }, 'flat.key': 'flat' }],
        ['{{a.zero}}|{{a.nil}}', { a: { zero: 0, nil: null }, 'a.zero': 'flat zero', 'a.nil': 'flat nil' }]
    ]);
});

suite('interpolation/customDelimiters', 'interpolation.test.js', {
    lng: 'en', interpolation: { prefix: '(*(', suffix: ')*)', escapeValue: false },
    resources: { en: { translation: { a: 'x (*(v)*) y {{v}}', b: '(*( v )*)' } } }
}, [['a', { v: '1' }], ['b', { v: '2' }]]);

suite('interpolation/maxReplaces', 'interpolation.test.js', {
    lng: 'en', interpolation: { maxReplaces: 2, escapeValue: false },
    resources: { en: { translation: { a: '{{v}}{{v}}{{v}}{{v}}' } } }
}, [['a', { v: 'x' }]]);

// MARK: i18next.interpolation.nesting.test.js

suite('nesting', 'i18next.interpolation.nesting.test.js', {
    lng: 'en',
    resources: {
        en: {
            translation: {
                test1: 'test $t(nest1) {{a}}',
                nest1: 'nest value',
                test2: 'test $t(nest2, { "b": "{{a}}" })',
                nest2: 'nest {{b}}',
                test3: 'test $t(nest3, { "b": "{{a}}", "c": "{{b}}" })',
                nest3: 'nest {{b}} {{c}}',
                test102: '$t(test102, is, {"key": "success"})',
                'test102, is': 'this test is {{key}}',
                test103: '$t(test103, is, {"key": "success", "key2": "full"})',
                'test103, is': 'this test is {{key2}} {{key}}',
                keyA1: '{{text}} interpolated',
                keyB1: 'Text to interpolate => $t(keyA1, { "text": "foo" })',
                keyA1rec: '{{text}} interpolated | $t(keyB1rec)',
                keyB1rec: 'Text to interpolate => $t(keyA1rec, { "text": "foo" })',
                test_foo: "foo $t(test, { 'context': 'bar' })",
                test_bar: "bar $t(test, { 'context': 'baz' })",
                test_baz: 'baz',
                foo: '$t(bar, {"firstName": "{{firstName}}", "lastName": "{{lastName}}" })',
                fooSingle: "$t(bar, {'firstName': '{{firstName}}', 'lastName': '{{lastName}}' })",
                fooMultiline: '$t(bar, {\n  "firstName": "Marc",\n  "lastName": "Weber"\n})',
                bar: '{{firstName}} {{lastName}}',
                item_one: 'item', item_other: 'items', thing_one: 'thing', thing_other: 'things',
                phrase: 'A: $t(thing, { "count": 1 }) B: $t(item)',
                phrase2: 'A: $t(thing, { "count": 2 }) B: $t(item)',
                nestingWithBracketsFirst: '$t(nestingWithBracketsSecond, {"name": "foo (bar)"})',
                nestingWithBracketsSecond: 'Hello {{name}}!',
                replacementPattern: 'Band: $t(replacementPatternValue)',
                replacementPatternValue: 'Rock $& Roll',
                replacementPatternOption: 'Hi $t(replacementPatternInner, { "n": "{{n}}" })',
                replacementPatternInner: 'name={{n}}',
                missingNest: 'x $t(doesNotExist) y',
                nsNest: 'x $t(other:key) y',
                countNest: '$t(item, { "count": {{n}} })'
            },
            other: { key: 'from other' }
        }
    }
}, [
    ['test1', { a: 'foo' }],
    ['test2', { a: 'foo' }],
    ['test3', { a: 'foo', b: 'bar' }],
    ['test102'],
    ['test103'],
    ['$t(test1)', { a: 'foo' }],
    ['$t(translation:test1)', { a: 'foo' }],
    ['something $t(test1)', { a: 'foo' }],
    ['something $t(translation:test1)', { a: 'foo' }],
    ['keyB1'],
    ['keyB1rec'],
    ['test', { context: 'foo' }],
    ['foo', { firstName: 'Cool', lastName: "O'Dood", interpolation: { escapeValue: false } }],
    ['foo', { firstName: "C'ool", lastName: "O'Dood", interpolation: { escapeValue: false } }],
    ['fooSingle', { firstName: 'Cool', lastName: 'Dood', interpolation: { escapeValue: false } }],
    ['fooMultiline'],
    ['bar', { firstName: 'Cool', lastName: "O'Dood", interpolation: { escapeValue: false } }],
    ['phrase'],
    ['phrase2'],
    ['nestingWithBracketsFirst'],
    ['replacementPattern'],
    ['replacementPatternOption', { n: 'X$&Y', interpolation: { escapeValue: false } }],
    ['missingNest'],
    ['nsNest'],
    ['countNest', { n: 5 }]
]);

// MARK: languageUtils.test.js

var __hierarchyTable = [
    ['en'], ['de'], ['de', 'fr'], ['de', ['fr', 'en']], ['de', ['fr', 'de']], ['de-CH'], ['nb-NO'],
    ['zh-Hant-MO'], ['de-x-custom1'], ['de-DE-x-custom1'], ['de-CH', 'de-ch'], ['zh-Hant-MO', ['zh-hant-mo', 'en']],
    ['de', false], ['de-CH', false], ['pt_BR'], ['en-US'], ['sr-Latn-RS']
];

function hierarchyCases(fallbackLng) {
    return __hierarchyTable.map(function (row) { return [row[0], { fallbackLng: row.length > 1 ? row[1] : fallbackLng }]; });
}

suite('languageUtils/hierarchy', 'languageUtils.test.js', { fallbackLng: 'en' },
    __hierarchyTable.map(function (row) { return [row[0], row.length > 1 ? { fallbackLng: row[1] } : {}]; }),
    { kind: 'resolveHierarchy' });

suite('languageUtils/hierarchy[perLanguage]', 'languageUtils.test.js', {
    fallbackLng: {
        de: ['de-CH', 'en'], 'de-CH': ['fr', 'it', 'en'], 'zh-Hans': ['zh-Hant', 'zh', 'en'],
        'zh-Hant': ['zh-Hans', 'zh', 'en'], ja: ['ja'], nb: ['no'], nn: ['no'], default: ['en']
    }
}, [['en'], ['de'], ['de-CH'], ['nb-NO'], ['nn'], ['zh-Hant-MO'], ['fr'], ['ja'], ['de-ch'], ['xx-Yyyy-ZZ']],
    { kind: 'resolveHierarchy' });

suite('languageUtils/hierarchy[languageOnly]', 'languageUtils.test.js', { fallbackLng: 'en', load: 'languageOnly' },
    [['en'], ['de'], ['de-CH'], ['nb-NO'], ['zh-Hant-MO'], ['de', 'fr']].map(function (r) { return r.length > 1 ? [r[0], { fallbackLng: r[1] }] : [r[0]]; }),
    { kind: 'resolveHierarchy' });

suite('languageUtils/hierarchy[currentOnly]', 'languageUtils.test.js', { fallbackLng: 'en', load: 'currentOnly' },
    [['en'], ['de'], ['de-CH'], ['nb-NO'], ['zh-Hant-MO']], { kind: 'resolveHierarchy' });

suite('languageUtils/hierarchy[lowerCaseLng]', 'languageUtils.test.js', { fallbackLng: 'en', lowerCaseLng: true },
    [['EN'], ['DE-CH'], ['nb-NO'], ['zh-Hant-MO']], { kind: 'resolveHierarchy' });

suite('languageUtils/hierarchy[cleanCode]', 'languageUtils.test.js', { fallbackLng: 'en', cleanCode: true },
    [['EN'], ['DE'], ['DE-CH'], ['NB-NO'], ['ZH-HANT-MO']], { kind: 'resolveHierarchy' });

suite('languageUtils/formatCode', 'languageUtils.test.js', {},
    ['en', 'EN', 'en-us', 'en-US', 'de-CH', 'pt-br', 'pt_BR', 'zh-hant', 'zh-Hant', 'zh-hant-tw', 'zh-hans-cn', 'sgn-be-fr',
        'de-x-custom1', 'de-DE-x-custom1', 'en-latn-us', 'sr-latn', 'es-419', 'ca-ES-valencia', 'x', ''].map(function (c) { return [c]; }),
    { kind: 'formatCode' });

suite('languageUtils/languagePart', 'languageUtils.test.js', {},
    ['en', 'en-US', 'zh-Hant-TW', 'pt-br', 'de-x-custom1', 'cimode', 'dev', ''].map(function (c) { return [c]; }),
    { kind: 'languagePart' });

// MARK: pluralResolver.test.js (answers come from the system ICU's Intl.PluralRules, which may be a different
// CLDR release than the one this port generates from)

var __pluralCounts = [0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 20, 21, 22, 100, 101, 102, 111, 1000, 1000000, 0.5, 1.5, 2.5];
var __pluralLanguages = ['en', 'de', 'fr', 'es', 'it', 'pt', 'pt-PT', 'ru', 'uk', 'pl', 'cs', 'ar', 'he', 'ja', 'zh', 'ko',
    'tr', 'cy', 'ga', 'lt', 'lv', 'sl', 'hr', 'ro', 'da', 'is', 'sv', 'nl', 'hi', 'fa'];

suite('plural/suffix[cardinal]', 'pluralResolver.test.js', { fallbackLng: 'en' },
    [].concat.apply([], __pluralLanguages.map(function (lng) {
        return __pluralCounts.map(function (count) { return [lng, { count: count }]; });
    })), { kind: 'pluralSuffix' });

suite('plural/suffix[ordinal]', 'pluralResolver.test.js', { fallbackLng: 'en' },
    [].concat.apply([], ['en', 'sv', 'fr', 'it', 'es', 'ru', 'ja'].map(function (lng) {
        return [1, 2, 3, 4, 8, 11, 12, 13, 21, 22, 23, 80, 101].map(function (count) { return [lng, { count: count, ordinal: true }]; });
    })), { kind: 'pluralSuffix' });

// MARK: resourceStore.test.js and Translator.getResource

var __store = {
    en: {
        translation: {
            test: 'test', nested: { key: 'deep' }, 'flat.key': 'flat', empty: '', zero: 0, nothing: null,
            'a.key': 'first', 'a.key.deep': 'second', 'a.key.deep.deeper': 'third', 'a.key.deeper': 'fourth',
            mix: { 'dotted.key': 'mixed' }, both: { x: 'nested' }, 'both.x': 'flat'
        }
    }
};

suite('store/getResource', 'resourceStore.test.js', { resources: __store, lng: 'en' }, [
    [['en', 'translation', 'test']],
    [['en', 'translation', 'nested.key']],
    [['en', 'translation', 'nested']],
    [['en', 'translation', 'flat.key']],
    [['en', 'translation', 'empty']],
    [['en', 'translation', 'zero']],
    [['en', 'translation', 'nothing']],
    [['en', 'translation', 'a.key']],
    [['en', 'translation', 'a.key.deep']],
    [['en', 'translation', 'a.key.deep.deeper']],
    [['en', 'translation', 'a.key.deeper']],
    [['en', 'translation', 'mix.dotted.key']],
    [['en', 'translation', 'both.x']],
    [['en', 'translation', 'missing']],
    [['en', 'translation', 'nested.missing']],
    [['en', 'other', 'test']],
    [['de', 'translation', 'test']],
    [['en', 'translation', 'toString']],
    [['en', 'translation', 'nested.constructor']],
    [['en', 'translation', 'nested.key'], { keySeparator: false }],
    [['en', 'translation', 'flat.key'], { keySeparator: false }],
    [['en', 'translation', 'nested::key'], { keySeparator: '::' }],
    [['en', 'translation', 'nested.key'], { ignoreJSONStructure: false }],
    [['en', 'translation', 'flat.key'], { ignoreJSONStructure: false }]
], { kind: 'getResource' });

suite('translate/getResource', 'translator.getResource.test.js', { resources: __store, lng: 'en', fallbackLng: 'en' }, [
    ['both.x'], ['flat.key'], ['a.key'], ['a.key.deep'], ['a.key.deep.deeper'], ['mix.dotted.key'], ['empty'], ['zero'], ['nothing']
]);

// MARK: translator.translate.array.test.js (the array-of-keys part; `returnObjects` and `joinArrays` come with their feature)

suite('translate/arrayOfKeys', 'translator.translate.array.test.js', {
    lng: 'en', fallbackLng: 'en',
    resources: {
        en: {
            translation: { a: 'A', b: 'B {{v}}', item_one: 'one item', item_other: 'many items', deep: { x: 'deep x' } },
            other: { c: 'C' }
        },
        de: { translation: { a: 'A de' } }
    }
}, [
    [['a', 'b']],
    [['missing', 'b'], { v: 1 }],
    [['missing', 'alsoMissing']],
    [['missing', 'a'], { lng: 'de' }],
    [['other:c', 'a']],
    [['a', 'other:c']],
    [['missing', 'other:c']],
    [['item', 'a'], { count: 3 }],
    [['missing', 'item'], { count: 1 }],
    [['deep.x', 'a']],
    [['missing', 'deep.x']],
    [[]],
    [['missing'], { defaultValue: 'fallback' }],
    [['missing', 'alsoMissing'], { defaultValue: 'fallback' }]
]);

// MARK: translator.translate.returnObject.test.js

var __objectResources = {
    en: {
        common: {
            test: ['common_test_en_1', 'common_test_en_2'],
            something: { range: '[{{min}}..{{max}}]' },
            somethingElse: { range: '[{{min}}..{{max}}]', hello: 'hello {{what}}', foo: 'bar' },
            requirements: ['lorem ipsum', 'lorem ipsum', 'hello {{what}}'],
            boolean: { value: true },
            number: { value: 42 },
            nested: { deep: { list: ['a', { b: 'B {{x}}' }], n: 1 }, s: 's' },
            array: ['common_array_en_1', 'common_array_en_2']
        },
        special: { test: ['special_test_en_1', 'special_test_en_2'] },
        withContext: { string: 'hello world', string_lined: ['hello', 'world'] }
    },
    de: { common: { test: ['common_test_de_1', 'common_test_de_2'] }, special: { test: ['special_test_de_1', 'special_test_de_2'] } }
};

suite('returnObjects[on]', 'translator.translate.returnObject.test.js', {
    lng: 'en', fallbackLng: 'en', returnObjects: true, ns: ['common', 'special', 'withContext'], defaultNS: 'common',
    resources: __objectResources
}, [
    ['common:test'],
    ['special:test'],
    ['common:somethingElse', { min: '1', max: '1000', what: 'world' }],
    ['common:requirements', { what: 'world' }],
    ['common:something'],
    ['common:something', { min: '1', max: '1000' }],
    ['common:something.range', { min: '1', max: '1000' }],
    ['common:boolean'],
    ['common:number'],
    ['withContext:string'],
    ['withContext:string', { context: 'lined' }],
    ['common:nested', { x: 'X' }],
    ['common:nested.deep'],
    ['common:test', { lng: 'de' }],
    ['common:missing'],
    ['common:missing', { defaultValue: 'dv' }],
    ['common:test', { returnObjects: false }]
]);

suite('returnObjects[off]', 'translator.translate.returnObject.test.js', {
    lng: 'en', fallbackLng: 'en', returnObjects: false, ns: ['common', 'special'], defaultNS: 'common',
    resources: __objectResources
}, [
    ['common:array'],
    ['common:array', { returnObjects: true }],
    ['common:array', { defaultValue: 'dv' }],
    ['common:something'],
    ['common:test.0']
]);

// MARK: translator.translate.array.test.js (joinArrays and arrays under returnObjects)

suite('joinArrays', 'translator.translate.array.test.js', {
    lng: 'en', fallbackLng: 'en', returnObjects: true, ns: 'translation', defaultNS: 'translation', keySeparator: '.',
    resources: {
        en: {
            translation: {
                test: ['test_en_1', 'test_en_2', '{{myVar}}'],
                flagList: [['basic1', 'Basic1'], ['simple1', 'Simple1']],
                search: { flagList: [['basic', 'Basic'], ['simple', 'Simple']] },
                keyArray_one: ['hello world {{count}}', 'hey {{count}}'],
                keyArray_other: ['hello world plural {{count}}', 'hey plural {{count}}'],
                recursiveA: ['a', '$t(recursiveB)'],
                recursiveB: ['b', '$t(recursiveA)']
            }
        }
    }
}, [
    ['translation:test.0'],
    ['translation:test.2', { myVar: 'test' }],
    ['translation:test', { myVar: 'test', joinArrays: '+' }],
    ['translation:test', { myVar: 'test', joinArrays: '' }],
    ['recursiveA', { joinArrays: ' ' }],
    [['search.flagList', 'flagList'], {}],
    ['keyArray', { count: 1 }],
    ['keyArray', { count: 2 }],
    ['translation:test', { myVar: 'test', joinArrays: false }]
]);

// MARK: translator.translate.test.js (returnDetails)

suite('returnDetails', 'translator.translate.test.js', {
    lng: 'en', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation',
    resources: { en: { translation: { test: 'test_en', deep: { test: 'deep_en' }, p_one: 'one', p_other: 'many' } }, de: { translation: { test: 'test_de' } } }
}, [
    ['translation:test', { returnDetails: true }],
    ['test', { returnDetails: true }],
    ['translation:test', { returnDetails: true, lngs: ['en-US', 'en'] }],
    ['translation:test', { returnDetails: true, lngs: ['de'] }],
    ['translation:test', { returnDetails: true, lng: 'de' }],
    ['translation:test', { returnDetails: true, lng: 'fr' }],
    ['translation:test', { returnDetails: true, lng: 'en-US' }],
    ['translation.test', { returnDetails: true, lng: 'en-US', nsSeparator: '.' }],
    ['translation.deep.test', { returnDetails: true, lng: 'en-US', nsSeparator: '.' }],
    ['deep.test', { returnDetails: true }],
    ['translation:test', { returnDetails: true, testParam: 'test-param' }],
    ['translation:test', { returnDetails: true, replace: { testParam: 'test-param' } }],
    ['p', { returnDetails: true, count: 2 }],
    ['p', { returnDetails: true, count: 1, lng: 'de' }],
    ['missing', { returnDetails: true }],
    ['missing', { returnDetails: true, defaultValue: 'dv' }]
]);

// MARK: languageUtils.test.js (supportedLngs, nonExplicitSupportedLngs, getBestMatchFromCodes)

suite('languageUtils/supportedLngs', 'languageUtils.test.js', { fallbackLng: 'en', supportedLngs: ['nb-NO', 'de', 'en'] },
    [['en'], ['de'], ['de', { fallbackLng: 'fr' }], ['de', { fallbackLng: ['fr', 'en'] }], ['de', { fallbackLng: ['fr', 'de'] }], ['de-CH'], ['nb-NO'], ['nb'], ['fr']],
    { kind: 'resolveHierarchy' });

suite('languageUtils/nonExplicitSupportedLngs', 'languageUtils.test.js',
    { fallbackLng: ['en'], supportedLngs: ['de', 'en', 'zh'], nonExplicitSupportedLngs: true },
    [['en'], ['de'], ['de-AT'], ['zh-HK'], ['zh-CN'], ['fr'], ['fr-CA']], { kind: 'resolveHierarchy' });

suite('languageUtils/bestMatch[A]', 'languageUtils.test.js',
    { fallbackLng: ['en'], supportedLngs: ['en-US', 'en', 'de-DE', 'zh-Hans', 'zh-Hant'] },
    [[['en']], [['ru', 'en']], [['en-GB']], [['ru', 'en-GB']], [['de-CH']], [['ru']], [['c']], [['e']], [['user-id']],
        [['en-AU-SA']], [[]], [['zh-Hant-TW']], [['zh-Hans-TW']]], { kind: 'bestMatch' });

suite('languageUtils/bestMatch[B]', 'languageUtils.test.js',
    { fallbackLng: ['en'], supportedLngs: ['en', 'fil-PH', 'haw-US', 'pt-BR'] },
    [[['fi-FI']], [['ha']], [['fil']], [['pt-PT']], [['haw']], [['pt']]], { kind: 'bestMatch' });

suite('languageUtils/bestMatch[C]', 'languageUtils.test.js',
    { fallbackLng: ['fr'], supportedLngs: ['dev', 'en', 'fr'] },
    [[['de']], [['ru', 'en']], [['en-GB']], [['ru', 'en-GB']], [['de-CH']], [['ru']], [[]]], { kind: 'bestMatch' });

suite('languageUtils/bestMatch[C,nonExplicit]', 'languageUtils.test.js',
    { fallbackLng: ['fr'], supportedLngs: ['dev', 'en', 'fr'], nonExplicitSupportedLngs: true },
    [[['de']], [['ru', 'en']], [['en-GB']], [['ru', 'en-GB']], [['de-CH']], [['ru']], [[]]], { kind: 'bestMatch' });

suite('languageUtils/bestMatch[format]', 'languageUtils.test.js', { fallbackLng: 'dev', supportedLngs: ['en', 'pt-br'] },
    [[['pt-br']], [['pt-BR']], [['en']]], { kind: 'bestMatch' });
suite('languageUtils/bestMatch[format,lowerCaseLng]', 'languageUtils.test.js', { fallbackLng: 'dev', supportedLngs: ['en', 'pt-BR'], lowerCaseLng: true },
    [[['pt-BR']]], { kind: 'bestMatch' });
suite('languageUtils/bestMatch[format,EN]', 'languageUtils.test.js', { fallbackLng: 'dev', supportedLngs: ['EN', 'pt-BR'] },
    [[['en']], [['EN']]], { kind: 'bestMatch' });
suite('languageUtils/bestMatch[format,EN-US]', 'languageUtils.test.js', { fallbackLng: 'dev', supportedLngs: ['EN-US'] },
    [[['en']]], { kind: 'bestMatch' });

// MARK: translator.translate.missing.test.js (saveMissing: what the missingKeyHandler receives)

var __missingResources = {
    en: { translation: { test: 'test_en', deep: { test: 'deep_en' } } },
    de: { translation: { test: 'test_de' } }
};

suite('missing/saveMissing', 'translator.translate.missing.test.js', {
    lng: 'en', fallbackLng: 'en', ns: 'translation', defaultNS: 'translation', saveMissing: true, resources: __missingResources
}, [
    ['translation:test.missing'],
    ['translation:test'],
    ['translation:missing', { defaultValue: 'dv' }],
    ['translation:missing', { lng: 'de' }],
    ['translation:missing', { defaultValue: 'dv', lng: 'de' }],
    ['translation:missing', { defaultValue: '' }],
    ['other:missing'],
    ['translation:test', { defaultValue: 'different' }]
], { kind: 'missing' });

['current', 'all', 'fallback'].forEach(function (to) {
    suite('missing/saveMissingTo[' + to + ']', 'translator.translate.missing.test.js', {
        lng: 'de-CH', fallbackLng: ['fr', 'en'], saveMissing: true, saveMissingTo: to,
        resources: { en: { translation: { test: 'test_en' } } }
    }, [['missing'], ['missing', { defaultValue: 'dv' }], ['missing', { lng: 'en' }]], { kind: 'missing' });
});

suite('missing/updateMissing', 'translator.translate.updateMissing.test.js', {
    lng: 'en', fallbackLng: 'en', saveMissing: true, updateMissing: true, resources: __missingResources
}, [
    ['test', { defaultValue: 'different' }],
    ['test', { defaultValue: 'test_en' }],
    ['test'],
    ['missing', { defaultValue: 'dv' }]
], { kind: 'missing' });

suite('missing/plurals[ar]', 'translator.translate.missing.test.js', {
    lng: 'ar', fallbackLng: 'ar', saveMissing: true, saveMissingPlurals: true, resources: __missingResources
}, [
    ['translation:test.missing', { count: 10 }],
    ['translation:test.missing', { count: 0 }],
    ['translation:test.missing', { count: 0, defaultValue_zero: 'default0', defaultValue_one: 'default1' }],
    ['translation:test.missing', { count: 1, defaultValue: 'dv', defaultValue_one: 'default1' }]
], { kind: 'missing' });

suite('missing/plurals[en ordinal]', 'translator.translate.missing.test.js', {
    lng: 'en', fallbackLng: 'en', saveMissing: true, saveMissingPlurals: true, resources: __missingResources
}, [
    ['translation:test.missing', { count: 3, ordinal: true }],
    ['translation:test.missing', { count: 0, ordinal: true }],
    ['translation:test.missing', { count: 1, ordinal: true, defaultValue_ordinal_one: 'first', defaultValue: 'dv' }],
    ['translation:test.missing', { count: 2 }]
], { kind: 'missing' });

suite('missing/plurals[off]', 'translator.translate.missing.test.js', {
    lng: 'ar', fallbackLng: 'ar', saveMissing: true, saveMissingPlurals: false, resources: __missingResources
}, [['translation:test.missing', { count: 10 }]], { kind: 'missing' });

suite('missing/off', 'translator.translate.missing.test.js', {
    lng: 'en', fallbackLng: 'en', saveMissing: false, resources: __missingResources
}, [['translation:test.missing']], { kind: 'missing' });

suite('missing/appendNamespaceToMissingKey', 'translator.translate.missing.test.js', {
    lng: 'en', fallbackLng: 'en', appendNamespaceToMissingKey: true, resources: __missingResources
}, [['missing'], ['translation:missing'], ['other:missing'], ['test'], ['missing', { defaultValue: 'dv' }], ['missing', { nsSeparator: '|' }]]);

// pluralResolver: languages without rules (Intl falls back to the default locale)
suite('plural/suffix[unknown]', 'pluralResolver.test.js', { fallbackLng: 'en' },
    [['xx', { count: 1 }], ['xx', { count: 2 }], ['dev', { count: 1 }], ['dev', { count: 2 }], ['zz-ZZ', { count: 1 }],
        ['xx', { count: 1, ordinal: true }], ['xx', { count: 2, ordinal: true }], ['dev', { count: 3, ordinal: true }],
        ['zz-ZZ', { count: 1, ordinal: true }], ['en-US', { count: 21, ordinal: true }], ['pt-BR', { count: 1 }]],
    { kind: 'pluralSuffix' });

// MARK: postProcess (the post-processors are defined in harness.js)

var __postProcessResources = {
    en: {
        translation: {
            a: 'hello',
            b: 'Hi {{name}}',
            c: 'see $t(a)',
            d: 'see $t(a, {"postProcess": "bang"})',
            item_one: '{{count}} item',
            item_other: '{{count}} items',
            friend: 'friend',
            friend_male: 'boyfriend',
            steps: ['open {{app}}', 'sign in'],
            group: { title: 'Title', inner: { deep: 'deep' } },
            empty: ''
        }
    }
};

suite('postProcess/call', 'postProcessor.test.js (cases written for this port)', { lng: 'en', resources: __postProcessResources }, [
    ['a', { postProcess: 'uppercase' }],
    ['a', { postProcess: ['uppercase', 'bang'] }],
    ['a', { postProcess: ['wrap', 'times'], times: 2 }],
    ['a', { postProcess: ['times', 'wrap'], times: 2 }],
    ['a', { postProcess: 'times', times: 3 }],
    ['a', { postProcess: 'times' }],
    ['a', { postProcess: 'unknown' }],
    ['a', { postProcess: ['unknown', 'bang'] }],
    ['a', { postProcess: 'noop' }],
    ['a', { postProcess: ['bang', 'noop', 'wrap'] }],
    ['a', { postProcess: [] }],
    ['a', { postProcess: '' }],
    ['b', { name: 'x<y', postProcess: 'uppercase' }],
    ['b', { name: 'x<y', postProcess: 'uppercase', interpolation: { escapeValue: false } }],
    ['b', { postProcess: 'bang' }],
    ['zzz', { postProcess: 'uppercase' }],
    ['ns:zzz', { postProcess: 'uppercase' }],
    ['zzz', { defaultValue: 'fallback {{x}}', x: 'v', postProcess: 'uppercase' }],
    [['nope', 'a'], { postProcess: 'keyed' }],
    ['a', { postProcess: 'keyed' }],
    ['translation:a', { postProcess: 'keyed' }],
    ['a', { postProcess: 'uppercase', skipInterpolation: true }],
    ['b', { postProcess: 'uppercase', skipInterpolation: true }],
    ['item', { count: 1, postProcess: 'uppercase' }],
    ['item', { count: 5, postProcess: 'wrap' }],
    ['friend', { context: 'male', postProcess: 'uppercase' }],
    ['empty', { postProcess: 'bang' }],
    ['empty', { defaultValue: '', postProcess: 'bang' }],
    ['c', { postProcess: 'uppercase' }],
    ['c', { postProcess: 'wrap' }],
    ['c', { postProcess: ['wrap', 'bang'] }],
    ['d', { postProcess: 'wrap' }],
    ['d']
]);

suite('postProcess/init', 'postProcessor.test.js (cases written for this port)', {
    lng: 'en', resources: __postProcessResources, postProcess: ['wrap']
}, [
    ['a'],
    ['b', { name: 'Ann' }],
    ['zzz'],
    ['c'],
    ['a', { postProcess: [] }],
    ['a', { postProcess: ['bang'] }],
    ['a', { postProcess: 'uppercase' }],
    ['a', { postProcess: ['bang', 'unknown'] }],
    ['a', { skipInterpolation: true }]
]);

suite('postProcess/init-string', 'postProcessor.test.js (cases written for this port)', {
    lng: 'en', resources: __postProcessResources, postProcess: 'uppercase'
}, [['a'], ['b', { name: 'Ann' }], ['a', { postProcess: 'bang' }]]);

suite('postProcess/structures', 'postProcessor.test.js (cases written for this port)', { lng: 'en', resources: __postProcessResources }, [
    ['group', { returnObjects: true, postProcess: 'wrap' }],
    ['group', { returnObjects: true, postProcess: ['uppercase', 'bang'] }],
    ['steps', { returnObjects: true, app: 'Mail', postProcess: 'wrap' }],
    ['steps', { joinArrays: '+', app: 'Mail', postProcess: 'wrap' }],
    ['steps', { joinArrays: '+', app: 'Mail', postProcess: ['uppercase', 'bang'] }],
    ['group.title', { postProcess: 'keyed' }],
    ['group', { postProcess: 'wrap' }],
    ['a', { returnDetails: true, postProcess: 'uppercase' }],
    ['zzz', { returnDetails: true, postProcess: 'uppercase' }]
]);

suite('postProcess/cimode', 'postProcessor.test.js (cases written for this port)', { lng: 'cimode', resources: __postProcessResources }, [
    ['a', { postProcess: 'uppercase' }],
    ['ns:a', { postProcess: 'uppercase' }]
]);

suite('postProcess/fallback', 'postProcessor.test.js (cases written for this port)', {
    lng: 'de', fallbackLng: 'en', resources: __postProcessResources
}, [
    ['a', { postProcess: 'uppercase' }],
    ['a', { postProcess: 'keyed', lng: 'en' }],
    ['b', { name: 'Ann', postProcess: ['wrap', 'bang'] }]
]);

// MARK: getFixedT with keyPrefix, resolvedLanguage, dir and hasLoadedNamespace (written for this port)

var __fixedResources = {
    en: {
        translation: {
            title: 'Title', hello: 'Hello', settings: { title: 'Settings', nested: { deep: 'Deep' }, item_one: '{{count}} item', item_other: '{{count}} items' },
            'a.b': 'flat'
        },
        common: { ok: 'OK', settings: { ok: 'Common OK' } }
    },
    pt: { translation: { settings: { title: 'Ajustes' } } }
};
var __fixedSource = 'i18next.getFixedT.test.js (cases written for this port)';

suite('fixedT/keyPrefix', __fixedSource, { lng: 'en', resources: __fixedResources }, [
    ['title', { fixed: { keyPrefix: 'settings' } }],
    ['nested.deep', { fixed: { keyPrefix: 'settings' } }],
    ['missing', { fixed: { keyPrefix: 'settings' } }],
    ['item', { fixed: { keyPrefix: 'settings' }, call: { count: 2 } }],
    ['title', { fixed: { keyPrefix: 'settings' }, call: { keyPrefix: 'settings.nested' } }],
    ['deep', { fixed: { keyPrefix: 'settings' }, call: { keyPrefix: 'settings.nested' } }],
    ['title', { fixed: { keyPrefix: 'settings' }, call: { keyPrefix: '' } }],
    ['hello', { fixed: {}, call: { keyPrefix: 'settings' } }],
    ['title', { fixed: { keyPrefix: '' } }],
    [['missing', 'title'], { fixed: { keyPrefix: 'settings' } }],
    [['title', 'hello'], { fixed: { keyPrefix: 'settings' } }],
    ['ok', { fixed: { keyPrefix: 'settings', ns: ['common'] } }],
    ['common:ok', { fixed: { keyPrefix: 'settings' } }],
    ['title', { fixed: { lng: 'pt', keyPrefix: 'settings' } }],
    ['title', { fixed: { lng: 'pt', keyPrefix: 'settings' }, call: { lng: 'en' } }],
    ['title', { fixed: { lngs: ['pt', 'en'], keyPrefix: 'settings' } }],
    ['hello', { fixed: { lng: 'pt' } }],
    ['hello', { fixed: { lng: 'pt' }, call: { lng: 'en' } }],
    ['ok', { fixed: { ns: ['common'] } }],
    ['ok', { fixed: { ns: ['common'] }, call: { ns: 'translation' } }],
    ['b', { fixed: { keyPrefix: 'a' } }]
], { kind: 'fixedT' });

suite('fixedT/keyPrefix[keySeparator]', __fixedSource, {
    lng: 'en', keySeparator: '>', resources: { en: { translation: { settings: { title: 'Settings' } } } }
}, [
    ['title', { fixed: { keyPrefix: 'settings' } }],
    ['title', { fixed: { keyPrefix: 'settings' }, call: { keySeparator: '.' } }]
], { kind: 'fixedT' });

suite('fixedT/keyPrefix[no keySeparator]', __fixedSource, {
    lng: 'en', keySeparator: false, resources: { en: { translation: { 'settings.title': 'Flat', settings: { title: 'Nested' } } } }
}, [['title', { fixed: { keyPrefix: 'settings' } }]], { kind: 'fixedT' });

suite('resolvedLanguage', __fixedSource, { lng: 'pt-BR', fallbackLng: 'en', resources: __fixedResources }, [
    [null, {}],
    [null, { changeTo: 'pt' }],
    [null, { changeTo: 'en-GB' }],
    [null, { changeTo: 'de' }],
    [null, { changeTo: 'cimode' }],
    [null, { changeTo: 'dev' }]
], { kind: 'resolvedLanguage' });

suite('resolvedLanguage[no fallback]', __fixedSource, { lng: 'de', resources: __fixedResources }, [
    [null, {}], [null, { changeTo: 'pt-BR' }], [null, { changeTo: 'en' }]
], { kind: 'resolvedLanguage' });

suite('resolvedLanguage[empty bundles]', __fixedSource, {
    lng: 'pt', fallbackLng: 'en', resources: { pt: { translation: {} }, en: { translation: { a: 'b' } } }
}, [[null, {}]], { kind: 'resolvedLanguage' });

suite('resolvedLanguage[supportedLngs]', __fixedSource, {
    lng: 'fr', supportedLngs: ['en'], resources: { fr: { translation: { a: 'b' } }, en: { translation: { a: 'b' } } }
}, [[null, {}], [null, { changeTo: 'en-US' }]], { kind: 'resolvedLanguage' });

suite('dir', __fixedSource, { lng: 'en', resources: __fixedResources }, [
    ['en', {}], ['ar', {}], ['he', {}], ['fa', {}], ['ur', {}], ['ps', {}], ['ckb', {}], ['yi', {}], ['dv', {}],
    ['ar-EG', {}], ['ar-SA', {}], ['he-IL', {}], ['fa-IR', {}], ['pt-BR', {}], ['en-US', {}], ['zh-Hans', {}],
    ['ar-Latn', {}], ['az-Arab', {}], ['az-Latn', {}], ['ku-Arab', {}], ['pa-Arab', {}], ['sd-Arab', {}], ['uz-Arab', {}],
    ['AR', {}], ['Ar-eg', {}], ['xx', {}], ['', {}], [null, {}]
], { kind: 'dir' });

suite('dir[active language]', __fixedSource, { lng: 'ar', resources: { ar: { translation: { a: 'b' } } } }, [[null, {}], ['en', {}]], { kind: 'dir' });
suite('dir[no language]', __fixedSource, { resources: __fixedResources }, [[null, {}]], { kind: 'dir' });

suite('hasLoadedNamespace', __fixedSource, { lng: 'en', fallbackLng: 'en', resources: __fixedResources }, [
    ['translation', {}], ['common', {}], ['unknown', {}], ['common', { lng: 'pt' }], ['unknown', { lng: 'de' }]
], { kind: 'hasLoadedNamespace' });

suite('hasLoadedNamespace[cimode]', __fixedSource, { lng: 'cimode', resources: __fixedResources }, [['unknown', {}]], { kind: 'hasLoadedNamespace' });
suite('hasLoadedNamespace[no language]', __fixedSource, { resources: __fixedResources }, [['translation', {}]], { kind: 'hasLoadedNamespace' });
suite('hasLoadedNamespace[no resources]', __fixedSource, { lng: 'en' }, [['translation', {}]], { kind: 'hasLoadedNamespace' });

// MARK: second batch of options: missingInterpolationHandler, useRawValueToEscape, returnNull, returnedObjectHandler,
// missingKeyNoValueFallbackToKey (written for this port; handlers are named in harness.js)

var __secondResources = {
    en: {
        translation: {
            a: 'hello {{name}}', b: '{{- name}} and {{other}}', c: '{{name}}', fmt: 'n={{n, number}}', raw: 'v={{v}}',
            nested: 'see $t(a)', plain: 'plain', nul: null, empty: '', arr: ['one {{name}}', 'two'],
            obj: { x: 'ex', y: { z: 'zed' } }, single: { only: 'one' }
        }
    },
    de: { translation: { nul: 'de-value', a: 'hallo {{name}}' } }
};
var __secondSource = 'i18next.options.test.js (cases written for this port)';

['bracket', 'html', 'nothing', 'placeholder', 'number'].forEach(function (handler) {
    suite('missingInterpolationHandler/' + handler, __secondSource, {
        lng: 'en', resources: __secondResources, missingInterpolationHandler: handler
    }, [
        ['a'], ['a', { name: 'x' }], ['b'], ['b', { other: 'o' }], ['b', { name: 'n' }], ['c', { name: '<i>' }],
        ['fmt'], ['raw'], ['nested'], ['zzz', { defaultValue: 'dv {{q}}' }], ['a', { interpolation: { escapeValue: false } }],
        ['plain']
    ]);
});

suite('missingInterpolationHandler/skipOnVariables=false', __secondSource, {
    lng: 'en', resources: __secondResources, missingInterpolationHandler: 'bracket', interpolation: { skipOnVariables: false }
}, [['a'], ['b'], ['a', { name: 'x' }], ['nested']]);

suite('missingInterpolationHandler/call', __secondSource, { lng: 'en', resources: __secondResources }, [
    ['a'], ['a', { missingInterpolationHandler: 'bracket' }], ['b', { missingInterpolationHandler: 'html' }],
    ['a', { missingInterpolationHandler: 'nothing', name: 'x' }], ['nested', { missingInterpolationHandler: 'bracket' }]
]);

suite('missingInterpolationHandler/call overrides init', __secondSource, {
    lng: 'en', resources: __secondResources, missingInterpolationHandler: 'bracket'
}, [['a'], ['a', { missingInterpolationHandler: 'html' }], ['a', { missingInterpolationHandler: 'nothing' }]]);

var __rawCases = [
    ['c', { name: ['<a>', '&'] }], ['c', { name: { k: '<' } }], ['c', { name: 5 }], ['c', { name: true }],
    ['c', { name: null }], ['c', { name: '<b>' }], ['c', { name: '<b>', interpolation: { escapeValue: false } }],
    ['c', { name: 1.5e21 }], ['b', { name: ['<x>'], other: ['<y>'] }], ['raw', { v: [1, '<2>', null] }]
];
suite('useRawValueToEscape/off', __secondSource, { lng: 'en', resources: __secondResources }, __rawCases);
suite('useRawValueToEscape/on', __secondSource, {
    lng: 'en', resources: __secondResources, interpolation: { useRawValueToEscape: true }
}, __rawCases);

suite('returnNull/off', __secondSource, { lng: 'en', resources: __secondResources }, [
    ['nul'], ['nul', { defaultValue: 'dv' }], ['nested'], ['nul', { lng: 'de' }]
]);
suite('returnNull/off with fallback', __secondSource, { lng: 'en', fallbackLng: 'de', resources: __secondResources }, [
    ['nul'], ['nul', { defaultValue: 'dv' }]
]);
suite('returnNull/on', __secondSource, { lng: 'en', returnNull: true, resources: __secondResources }, [
    ['nul'], ['nul', { defaultValue: 'dv' }], ['nested'], ['plain'], ['nul', { lng: 'de' }]
]);
suite('returnNull/on with fallback', __secondSource, {
    lng: 'en', fallbackLng: 'de', returnNull: true, resources: __secondResources
}, [['nul'], ['nul', { defaultValue: 'dv' }], ['plain'], ['empty']]);
suite('returnNull/on exists', __secondSource, { lng: 'en', returnNull: true, resources: __secondResources }, [
    ['nul'], ['plain'], ['zzz'], ['empty']
], { kind: 'exists' });
suite('returnNull/off exists', __secondSource, { lng: 'en', resources: __secondResources }, [
    ['nul'], ['plain'], ['zzz'], ['empty']
], { kind: 'exists' });

['describe', 'passthrough', 'firstOfArray'].forEach(function (handler) {
    suite('returnedObjectHandler/' + handler, __secondSource, {
        lng: 'en', resources: __secondResources, returnedObjectHandler: handler
    }, [
        ['obj'], ['obj.y'], ['arr', { name: 'N' }], ['plain'], ['missing'], ['single'], ['obj', { ns: 'translation' }],
        ['obj', { returnObjects: true }], ['arr', { joinArrays: '-', name: 'N' }], ['translation:obj'], ['nul']
    ]);
});
suite('returnedObjectHandler/with instance returnObjects', __secondSource, {
    lng: 'en', returnObjects: true, resources: __secondResources, returnedObjectHandler: 'describe'
}, [['obj'], ['arr', { name: 'N' }]]);

var __noValueResources = { en: { translation: { plain: 'plain', item_one: '{{count}} item', item_other: '{{count}} items' } } };
suite('missingKeyNoValueFallbackToKey/off', __secondSource, {
    lng: 'en', fallbackLng: 'en', saveMissing: true, resources: __noValueResources
}, [['nokey'], ['nokey', { defaultValue: 'dv' }], ['plain'], ['ns:nokey'], ['nokey', { count: 2 }]], { kind: 'missing' });
suite('missingKeyNoValueFallbackToKey/on', __secondSource, {
    lng: 'en', fallbackLng: 'en', saveMissing: true, missingKeyNoValueFallbackToKey: true, resources: __noValueResources
}, [
    ['nokey'], ['nokey', { defaultValue: 'dv' }], ['plain'], ['ns:nokey'], ['nokey', { count: 2 }],
    ['nokey', { missingKeyNoValueFallbackToKey: false }], ['item', { count: 1, defaultValue: 'dv' }]
], { kind: 'missing' });
suite('missingKeyNoValueFallbackToKey/call', __secondSource, {
    lng: 'en', fallbackLng: 'en', saveMissing: true, resources: __noValueResources
}, [['nokey', { missingKeyNoValueFallbackToKey: true }], ['nokey', { missingKeyNoValueFallbackToKey: false }]], { kind: 'missing' });

// MARK: store accessors, hydrate and cloneInstance (written for this port: there is no upstream test to take them
// from; the answers are still i18next's own). A `session` runs steps against named instances, see harness.js.

var __batch3Source = 'ResourceStore / I18n.hydrate / I18n.cloneInstance (written for this port)';
var __batch3Resources = {
    en: { translation: { a: 'A en', b: 'B en', nested: { x: 'X en' } }, common: { ok: 'OK' } },
    de: { translation: { a: 'A de' } },
    fr: {},
    es: { translation: {}, common: { ok: '' } }
};

suite('getDataByLanguage', __batch3Source, { lng: 'en', resources: __batch3Resources },
    ['en', 'de', 'fr', 'es', 'zz', 'EN', 'en-US', ''].map(function (l) { return [l]; }),
    { kind: 'getDataByLanguage' });

function sessionSuite(name, init, steps) {
    suite('session/' + name, __batch3Source, init, [[null, { steps: steps }]], { kind: 'session' });
}

// ResourceStore: writes, merges, removals and the questions asked about them.
var __store = { lng: 'en', fallbackLng: 'en', resources: __batch3Resources };
sessionSuite('store/addResource', __store, [
    ['i18n', 'addResource', ['en', 'translation', 'c', 'C']],
    ['i18n', 'addResource', ['en', 'translation', 'deep.er.key', 'D']],
    ['i18n', 'addResource', ['fr', 'translation', 'a', 'A fr']],
    ['i18n', 'addResource', ['en', 'translation', 'a', 'A replaced']],
    ['i18n', 'addResource', ['en', 'translation', 'nested.x', { y: 1 }]],
    ['i18n', 'toJSON'],
    ['i18n', 'getResource', ['en', 'translation', 'deep.er.key']],
    ['i18n', 'hasLanguageSomeTranslations', ['fr']]
]);
sessionSuite('store/addResource-empty-key', __store, [
    ['i18n', 'addResource', ['en', 'translation', '', { whole: 'bundle' }]],
    ['i18n', 'getResourceBundle', ['en', 'translation']],
    ['i18n', 'toJSON']
]);
sessionSuite('store/addResources', __store, [
    ['i18n', 'addResources', ['en', 'translation', { c: 'C', 'd.e': 'DE', n: { m: 'NM' } }]],
    ['i18n', 'addResources', ['de', 'extra', { k: 'K' }]],
    ['i18n', 'toJSON'],
    ['i18n', 't', ['d.e']],
    ['i18n', 't', ['k', { ns: 'extra', lng: 'de' }]]
]);
sessionSuite('store/addResourceBundle-shallow', __store, [
    ['i18n', 'addResourceBundle', ['en', 'translation', { a: 'A new', z: 'Z', nested: { y: 'Y' } }]],
    ['i18n', 'getResourceBundle', ['en', 'translation']],
    ['i18n', 'addResourceBundle', ['pt', 'translation', { a: 'A pt' }]],
    ['i18n', 'toJSON']
]);
sessionSuite('store/addResourceBundle-deep', __store, [
    ['i18n', 'addResourceBundle', ['en', 'translation', { a: 'A new', z: 'Z', nested: { y: 'Y', x: 'X new' } }, true, false]],
    ['i18n', 'getResourceBundle', ['en', 'translation']],
    ['i18n', 'addResourceBundle', ['en', 'translation', { a: 'A over', nested: { x: 'X over' } }, true, true]],
    ['i18n', 'getResourceBundle', ['en', 'translation']],
    ['i18n', 'addResourceBundle', ['en', 'translation', { nested: 'flat now', b: { deeper: 1 } }, true, false]],
    ['i18n', 'getResourceBundle', ['en', 'translation']],
    ['i18n', 'addResourceBundle', ['en', 'translation', { nested: 'flat now', b: { deeper: 1 } }, true, true]],
    ['i18n', 'getResourceBundle', ['en', 'translation']]
]);
sessionSuite('store/removeResourceBundle', __store, [
    ['i18n', 'removeResourceBundle', ['en', 'common']],
    ['i18n', 'hasResourceBundle', ['en', 'common']],
    ['i18n', 'getDataByLanguage', ['en']],
    ['i18n', 'removeResourceBundle', ['en', 'nothing']],
    ['i18n', 'removeResourceBundle', ['zz', 'translation']],
    ['i18n', 'removeResourceBundle', ['de', 'translation']],
    ['i18n', 'getDataByLanguage', ['de']],
    ['i18n', 'hasLanguageSomeTranslations', ['de']],
    ['i18n', 'toJSON']
]);
sessionSuite('store/hasLanguageSomeTranslations', {
    lng: 'en',
    resources: {
        a: { ns: { k: 'v' } }, b: { ns: {} }, c: { ns: {}, other: { k: 1 } }, d: { ns: [] }, e: { ns: [1] },
        f: { ns: '' }, g: { ns: 'text' }, h: { ns: 0 }, i: { ns: 5 }, j: { ns: true }, k: { ns: false }, l: { ns: null }
    }
}, ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'zz'].map(function (l) {
    return ['i18n', 'hasLanguageSomeTranslations', [l]];
}));
sessionSuite('store/hasResourceBundle', __store, [
    ['i18n', 'hasResourceBundle', ['en', 'translation']],
    ['i18n', 'hasResourceBundle', ['fr', 'translation']],
    ['i18n', 'hasResourceBundle', ['es', 'common']],
    ['i18n', 'hasResourceBundle', ['en', 'zzz']],
    ['i18n', 'getResourceBundle', ['es', 'common']],
    ['i18n', 'getResourceBundle', ['es', 'zzz']]
]);

// hydrate: seeds the store and the language, once each.
var __hydrated = { en: { translation: { hello: 'Hello', nested: { k: 'K' } }, extra: { e: 'E' } }, pt: { translation: { hello: 'Olá' } } };
sessionSuite('hydrate/resources-only', { lng: 'en', fallbackLng: 'en' }, [
    ['i18n', 't', ['hello']],
    ['i18n', 'hydrate', [__hydrated]],
    ['i18n', 't', ['hello']],
    ['i18n', 't', ['e', { ns: 'extra' }]],
    ['i18n', 'language'],
    ['i18n', 'resolvedLanguage'],
    ['i18n', 'getDataByLanguage', ['pt']]
]);
sessionSuite('hydrate/with-language', { lng: 'en', fallbackLng: 'en' }, [
    ['i18n', 'hydrate', [__hydrated, 'pt']],
    ['i18n', 'language'],
    ['i18n', 'resolvedLanguage'],
    ['i18n', 'languages'],
    ['i18n', 't', ['hello']],
    ['i18n', 't', ['nested.k']]
]);
sessionSuite('hydrate/language-only', { lng: 'en', fallbackLng: 'en', resources: __hydrated }, [
    ['i18n', 'hydrate', [null, 'pt']],
    ['i18n', 'language'],
    ['i18n', 't', ['hello']],
    ['i18n', 'resolvedLanguage']
]);
sessionSuite('hydrate/only-once', { lng: 'en', fallbackLng: 'en' }, [
    ['i18n', 'hydrate', [__hydrated, 'pt']],
    ['i18n', 'hydrate', [{ en: { translation: { hello: 'Second' } } }, 'en']],
    ['i18n', 'language'],
    ['i18n', 't', ['hello']],
    ['i18n', 'hydrate', [{ en: { translation: { hello: 'Third' } } }]],
    ['i18n', 't', ['hello']]
]);
sessionSuite('hydrate/replaces-store', { lng: 'en', resources: { en: { translation: { old: 'Old', hello: 'Init' } } } }, [
    ['i18n', 't', ['old']],
    ['i18n', 'hydrate', [__hydrated, 'en']],
    ['i18n', 't', ['old']],
    ['i18n', 't', ['hello']],
    ['i18n', 'getDataByLanguage', ['en']]
]);
sessionSuite('hydrate/empty-arguments', { lng: 'en', resources: __hydrated }, [
    ['i18n', 'hydrate', []],
    ['i18n', 'hydrate', [null, '']],
    ['i18n', 'language'],
    ['i18n', 'hydrate', [{}, 'pt']],
    ['i18n', 'getDataByLanguage', ['en']],
    ['i18n', 'language']
]);
sessionSuite('hydrate/on-a-clone', { lng: 'en', resources: __hydrated }, [
    ['i18n', 'cloneInstance', [{}], 'c'],
    ['c', 'hydrate', [{ en: { translation: { hello: 'Never' } } }, 'pt']],
    ['c', 'language'],
    ['c', 't', ['hello']],
    ['i18n', 't', ['hello']]
]);

// cloneInstance
var __cloneInit = { lng: 'en', fallbackLng: 'en', resources: __batch3Resources };
sessionSuite('clone/inherits', __cloneInit, [
    ['i18n', 'cloneInstance', [{}], 'c'],
    ['c', 'language'],
    ['c', 'languages'],
    ['c', 'resolvedLanguage'],
    ['c', 't', ['a']],
    ['c', 't', ['ok', { ns: 'common' }]],
    ['c', 't', ['missing']]
]);
sessionSuite('clone/language-override', __cloneInit, [
    ['i18n', 'cloneInstance', [{ lng: 'de' }], 'c'],
    ['c', 'language'],
    ['c', 'languages'],
    ['c', 'resolvedLanguage'],
    ['c', 't', ['a']],
    ['c', 't', ['b']],
    ['i18n', 'language'],
    ['i18n', 't', ['a']]
]);
sessionSuite('clone/languages-are-independent', __cloneInit, [
    ['i18n', 'cloneInstance', [{}], 'c'],
    ['c', 'changeLanguage', ['de']],
    ['c', 'language'],
    ['c', 't', ['a']],
    ['i18n', 'language'],
    ['i18n', 't', ['a']],
    ['i18n', 'changeLanguage', ['fr']],
    ['i18n', 'language'],
    ['c', 'language'],
    ['c', 'resolvedLanguage'],
    ['i18n', 'resolvedLanguage']
]);
// i18next starts the clone in `lng` as it was configured, not in the language the original is in now; this port
// starts it in the current one (see ConformanceTests.swift).
sessionSuite('clone/after-original-changed-language', __cloneInit, [
    ['i18n', 'changeLanguage', ['de']],
    ['i18n', 'cloneInstance', [{}], 'c'],
    ['c', 'language'],
    ['c', 't', ['a']]
]);
sessionSuite('clone/shared-store', __cloneInit, [
    ['i18n', 'cloneInstance', [{}], 'c'],
    ['c', 'addResource', ['en', 'translation', 'fromClone', 'FC']],
    ['i18n', 't', ['fromClone']],
    ['i18n', 'addResource', ['en', 'translation', 'fromOriginal', 'FO']],
    ['c', 't', ['fromOriginal']],
    ['c', 'addResourceBundle', ['de', 'translation', { b: 'B de' }]],
    ['i18n', 't', ['b', { lng: 'de' }]],
    ['i18n', 'removeResourceBundle', ['de', 'translation']],
    ['c', 'hasResourceBundle', ['de', 'translation']],
    ['c', 'getDataByLanguage', ['de']]
]);
sessionSuite('clone/forked-store', __cloneInit, [
    ['i18n', 'cloneInstance', [{ forkResourceStore: true }], 'c'],
    ['c', 't', ['a']],
    ['c', 'addResource', ['en', 'translation', 'fromClone', 'FC']],
    ['i18n', 't', ['fromClone']],
    ['c', 't', ['fromClone']],
    ['i18n', 'addResource', ['en', 'translation', 'fromOriginal', 'FO']],
    ['c', 't', ['fromOriginal']],
    ['i18n', 't', ['fromOriginal']],
    ['c', 'addResourceBundle', ['de', 'translation', { b: 'B de' }]],
    ['i18n', 'getResourceBundle', ['de', 'translation']],
    ['c', 'getResourceBundle', ['de', 'translation']],
    ['i18n', 'removeResourceBundle', ['en', 'common']],
    ['c', 'hasResourceBundle', ['en', 'common']],
    ['c', 'toJSON']
]);
sessionSuite('clone/forked-store-copies-deeply', __cloneInit, [
    ['i18n', 'cloneInstance', [{ forkResourceStore: true }], 'c'],
    ['c', 'addResource', ['en', 'translation', 'nested.x', 'X clone']],
    ['c', 't', ['nested.x']],
    ['i18n', 't', ['nested.x']],
    ['i18n', 'addResource', ['en', 'translation', 'nested.z', 'Z original']],
    ['c', 't', ['nested.z']],
    ['i18n', 'getResourceBundle', ['en', 'translation']],
    ['c', 'getResourceBundle', ['en', 'translation']]
]);
sessionSuite('clone/forked-store-with-language', __cloneInit, [
    ['i18n', 'cloneInstance', [{ forkResourceStore: true, lng: 'de' }], 'c'],
    ['c', 'language'],
    ['c', 't', ['a']],
    ['c', 'resolvedLanguage']
]);
sessionSuite('clone/options', __cloneInit, [
    ['i18n', 'cloneInstance', [{ interpolation: { prefix: '<<', suffix: '>>' }, keySeparator: '/', defaultNS: 'common' }], 'c'],
    ['i18n', 'addResource', ['en', 'translation', 'ip', 'x {{n}} <<n>>']],
    ['i18n', 't', ['ip', { n: 1 }]],
    ['c', 't', ['ip', { n: 1 }]],
    ['c', 't', ['ok']],
    ['i18n', 't', ['ok']],
    ['i18n', 't', ['nested.x']],
    ['c', 't', ['translation:nested/x']]
]);
sessionSuite('clone/missing-key-options', __cloneInit, [
    ['i18n', 'cloneInstance', [{ returnEmptyString: true }], 'c'],
    ['c', 't', ['nothing', { defaultValue: 'dv' }]],
    ['c', 't', ['nothing']],
    ['c', 'exists', ['nothing']],
    ['c', 'exists', ['a']]
]);
sessionSuite('clone/post-processors', { lng: 'en', resources: __batch3Resources, postProcess: ['bang'] }, [
    ['i18n', 'cloneInstance', [{}], 'c'],
    ['c', 't', ['a']],
    ['c', 't', ['a', { postProcess: ['uppercase', 'wrap'] }]],
    ['c', 'usePostProcessor', ['angle']],
    ['c', 't', ['a', { postProcess: ['angle'] }]],
    ['i18n', 't', ['a', { postProcess: ['angle'] }]],
    ['i18n', 'usePostProcessor', ['question']],
    ['c', 't', ['a', { postProcess: ['question', 'angle'] }]],
    ['i18n', 't', ['a', { postProcess: ['question', 'angle'] }]]
]);
sessionSuite('clone/clone-of-clone', __cloneInit, [
    ['i18n', 'cloneInstance', [{ lng: 'de' }], 'c'],
    ['c', 'cloneInstance', [{}], 'cc'],
    ['cc', 'language'],
    ['cc', 't', ['a']],
    ['cc', 'addResource', ['de', 'translation', 'deep', 'D']],
    ['i18n', 't', ['deep', { lng: 'de' }]],
    ['c', 'cloneInstance', [{ forkResourceStore: true }], 'cf'],
    ['cf', 'addResource', ['de', 'translation', 'forked', 'F']],
    ['i18n', 't', ['forked', { lng: 'de' }]],
    ['cf', 't', ['forked', { lng: 'de' }]],
    ['cf', 't', ['deep', { lng: 'de' }]]
]);
sessionSuite('clone/language-options-follow-the-clone', __cloneInit, [
    ['i18n', 'cloneInstance', [{ fallbackLng: 'de' }], 'c'],
    ['c', 'languages'],
    ['c', 't', ['a', { lng: 'fr' }]],
    ['i18n', 'languages'],
    ['i18n', 't', ['a', { lng: 'fr' }]]
]);

// MARK: BCP 47 aliases (what `Intl.getCanonicalLocales` does beyond the structure of a tag). The expected answers are
// those of the system's ICU, as JavaScriptCore exposes it.

var __aliasTags = [
    // deprecated and ISO 639-2/3 languages
    'iw', 'iw-IL', 'in', 'in-ID', 'ji', 'jw', 'mo', 'mo-MD', 'tl', 'tl-PH', 'tl-Latn-PH', 'fil', 'sh', 'sh-Latn', 'sh-BA',
    'sh-cyrl', 'sh-latn-rs', 'hbs', 'hbs-BA', 'cnr', 'cnr-ME', 'cnr-BA', 'cnr-Cyrl-ME', 'swc', 'swc-CD', 'swc-KE', 'prs',
    'prs-AF', 'prs-IR', 'drw-AF', 'tnf-AF', 'kmr', 'kmr-TR', 'ckb', 'ckb-IQ', 'arb', 'arb-SA', 'pes', 'pes-IR', 'zsm',
    'zsm-MY', 'zlm', 'nep', 'npi', 'aze', 'uzn', 'azj', 'ekk', 'est', 'lvs', 'hrv', 'srp', 'scc', 'scr', 'bos', 'cmn',
    'cmn-Hans', 'cmn-Hans-CN', 'cmn-TW', 'yue', 'yue-HK', 'eng', 'eng-US', 'eng-GB', 'spa', 'spa-MX', 'por', 'por-BR',
    'deu', 'deu-AT', 'ger', 'fra', 'fra-CA', 'fre', 'ita', 'jpn', 'jpn-JP', 'kor', 'kor-KR', 'rus', 'rus-RU', 'zho',
    'zho-CN', 'zho-Hans', 'zho-Hant-TW', 'chi', 'chi-TW', 'dut', 'nld', 'gre', 'ell', 'cze', 'ces', 'pol', 'swe', 'dan',
    'nor', 'fin', 'tur', 'heb', 'ara', 'hin', 'tha', 'vie', 'ind', 'msa', 'fas', 'kat', 'isl', 'mkd', 'mri', 'ron', 'slk',
    'sqi', 'bod', 'cym', 'eus', 'hye', 'mya', 'bh', 'bih', 'no', 'no-NO', 'nb', 'nn', 'ckb', 'gom', 'pnb', 'pbu', 'nno',
    'nob', 'ory', 'ori', 'ukr', 'ukr-UA', 'ell-GR', 'IW', 'Iw-il', 'ENG-us', 'SGN-us',
    // deprecated and numeric regions
    'en-UK', 'en-uk', 'fr-FX', 'de-DD', 'en-BU', 'my-BU', 'en-TP', 'pt-TP', 'en-ZR', 'fr-ZR', 'en-YD', 'en-840', 'en-826',
    'es-724', 'pt-076', 'de-276', 'fr-250', 'zh-156', 'ja-392', 'en-001', 'es-419', 'en-150', 'en-062', 'en-AN', 'nl-AN',
    'es-AN', 'pap-AN', 'en-CS', 'sr-CS', 'sr-YU', 'sl-YU', 'mk-YU', 'bs-YU', 'sr-cyrl-cs', 'sr-latn-yu', 'en-SU', 'ru-SU',
    'uk-su', 'ka-SU', 'hy-su', 'lv-SU', 'ru-172', 'ka-172', 'en-172', 'hy-810', 'et-810', 'lt-810', 'en-200', 'cs-200',
    'sk-200', 'en-230', 'en-530', 'nl-530', 'en-532', 'sl-890', 'hr-890', 'bs-890', 'mk-890', 'sr-890', 'sr-891',
    'de-278', 'de-280', 'en-736', 'ar-736', 'en-886', 'en-582', 'mh-582', 'en-QU', 'de-QU', 'en-NT', 'ar-NT', 'en-NH',
    'fr-NH', 'bi-NH', 'en-HV', 'fr-HV', 'en-RH', 'en-DY', 'fr-DY', 'en-VD', 'vi-VD', 'en-FQ', 'en-NQ', 'en-CT', 'en-JT',
    'en-MI', 'en-PC', 'en-PU', 'en-PZ', 'es-PZ', 'en-WK', 'en-999', 'en-958', 'en-QM', 'en-XA',
    // scripts
    'en-Qaai', 'und-Qaai', 'und-Zinh', 'zh-Hani', 'sr-Cyrl', 'sr-latn',
    // variants
    'en-heploc', 'en-Latn-heploc', 'ja-latn-hepburn-heploc', 'ja-hepburn-heploc', 'ja-hepburn-fonipa-heploc',
    'en-heploc-hepburn', 'ja-latn-alalc97-hepburn', 'ja-hepburn', 'en-polytoni', 'el-polytoni', 'el-polyton',
    'el-polytoni-1901', 'hy-arevela', 'hy-arevmda', 'hy-Latn-arevela', 'hy-AM-arevmda', 'hy-arevela-fonipa', 'en-aaland',
    'sv-aaland', 'sv-SE-aaland', 'sv-aaland-fonipa', 'sv-AX', 'zh-guoyu', 'zh-Hans-guoyu', 'zh-CN-guoyu', 'en-guoyu',
    'zh-hakka', 'zh-hakka-fonipa', 'zh-xiang', 'en-hakka', 'art-lojban', 'art-lojban-fonipa', 'en-lojban', 'cel-gaulish',
    'cel-GAULISH', 'en-gaulish', 'aa-saaho', 'ssy-saaho', 'nb-bokmal', 'nn-nynorsk', 'no-bokmal', 'no-nynorsk',
    'ca-ES-valencia', 'en-1901', 'de-1996', 'de-AT-1901', 'en-fonipa-fonipa', 'en-oxendict', 'en-GB-oxendict',
    'en-GB-oed', 'de-CH-1901-fonipa', 'sl-rozaj-biske', 'sl-biske-rozaj',
    // sign languages
    'sgn-US', 'sgn-us', 'sgn-BR', 'sgn-CO', 'sgn-DK', 'sgn-DE', 'sgn-FR', 'sgn-GB', 'sgn-UK', 'sgn-GR', 'sgn-IE', 'sgn-IT',
    'sgn-JP', 'sgn-MX', 'sgn-NI', 'sgn-NL', 'sgn-NO', 'sgn-PT', 'sgn-SE', 'sgn-ZA', 'sgn-ES', 'sgn-CN', 'sgn-CU', 'sgn-DD',
    'sgn-FX', 'sgn-AN', 'sgn-Latn-US', 'sgn-US-fonipa', 'sgn-BR-fonipa', 'sgn-BE', 'sgn-CH', 'sgn', 'ase', 'bfi',
    // grandfathered tags and extended languages
    'i-klingon', 'zh-min-nan', 'zh-cmn', 'zh-cmn-Hans-CN', 'zh-yue', 'en-gb-oed', 'no-bok', 'no-nyn', 'ar-arb',
    // extensions
    'en-u-nu-latn', 'de-u-co-phonebk', 'en-t-ja', 'en-a-bbb-x-a-ccc',
    'en-u-nu-latn-a-ext', 'IW-u-nu-latn', 'tl-u-nu-latn',
    // private use
    'x-private', 'en-x-private', 'iw-x-private', 'x', 'en-x'
];
suite('languageUtils/formatCode/aliases', 'Intl.getCanonicalLocales', {},
    __aliasTags.map(function (c) { return [c]; }), { kind: 'formatCode' });
suite('languageUtils/formatCode/aliases[lowerCaseLng]', 'Intl.getCanonicalLocales', { lowerCaseLng: true },
    ['iw-IL', 'sgn-US', 'en-UK', 'sr-latn-yu', 'cmn-Hans-CN', 'tl-PH', 'sh', 'ru-SU'].map(function (c) { return [c]; }),
    { kind: 'formatCode' });
suite('languageUtils/formatCode/aliases[cleanCode]', 'Intl.getCanonicalLocales', { cleanCode: true },
    ['IW', 'iw-il', 'TL', 'ENG', 'sgn-us', 'EN-uk'].map(function (c) { return [c]; }), { kind: 'formatCode' });
suite('languageUtils/formatCode/aliases[cleanCode=false]', 'Intl.getCanonicalLocales', { cleanCode: false },
    ['IW', 'iw-il', 'TL', 'ENG', 'iw', 'sgn-us', 'EN-uk'].map(function (c) { return [c]; }), { kind: 'formatCode' });
suite('languageUtils/languagePart/aliases', 'Intl.getCanonicalLocales', {},
    ['iw-IL', 'tl-PH', 'eng-US', 'sh-BA', 'cnr-ME', 'sgn-US', 'ru-SU'].map(function (c) { return [c]; }),
    { kind: 'languagePart' });
suite('languageUtils/hierarchy/aliases', 'Intl.getCanonicalLocales', { fallbackLng: 'en' },
    ['iw-IL', 'tl-PH', 'eng-US', 'sh-BA', 'cnr-ME', 'ru-SU', 'zh-Hant-TW', 'sr-latn-yu'].map(function (c) { return [c]; }),
    { kind: 'resolveHierarchy' });
suite('languageUtils/bestMatch/aliases', 'Intl.getCanonicalLocales',
    { supportedLngs: ['he', 'fil', 'sr-Latn', 'en'], nonExplicitSupportedLngs: true },
    [[['iw-IL']], [['tl-PH']], [['sh-BA']], [['eng-US']], [['iw', 'en']], [['sgn-US']]], { kind: 'bestMatch' });
