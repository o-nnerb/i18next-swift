// Runs conformance cases against the real i18next (loaded into the same JavaScriptCore context) and records
// what it answers. `cases.js` calls `suite(...)`; `generate.swift` then reads `__run()`.
//
//   suite(name, source, init, tests, options)
//     name     unique id of the group
//     source   the upstream test file the cases were taken from
//     init     i18next init options (JSON only: no functions)
//     tests    [[key, options?], ...]
//     options  { kind }, one of: t (default), exists, getResource, resolveHierarchy, formatCode, languagePart, pluralSuffix,
//              bestMatch

var __suites = [];

function suite(name, source, init, tests, options) {
    __suites.push({ name: name, source: source, init: init, tests: tests, options: options || {} });
}

function __clone(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function __call(instance, kind, key, options) {
    switch (kind) {
        case 't':
            return instance.t(key, __clone(options) || {});
        case 'exists':
            return instance.exists(key, __clone(options) || {});
        case 'getResource':
            // key = [lng, ns, key]
            return instance.getResource(key[0], key[1], key[2], __clone(options) || {});
        case 'resolveHierarchy':
            // key = language code, options = { fallbackLng }
            return instance.services.languageUtils.toResolveHierarchy(key, (options || {}).fallbackLng);
        case 'formatCode':
            return instance.services.languageUtils.formatLanguageCode(key);
        case 'languagePart':
            return instance.services.languageUtils.getLanguagePartFromCode(key);
        case 'bestMatch':
            // key = array of candidate codes
            return instance.services.languageUtils.getBestMatchFromCodes(key);
        case 'pluralSuffix':
            // key = language, options = { count, ordinal }
            return instance.services.pluralResolver.getSuffix(key, (options || {}).count, __clone(options) || {});
        default:
            throw new Error('unknown kind ' + kind);
    }
}

function __run() {
    var out = [];
    __suites.forEach(function (s) {
        var kind = s.options.kind || 't';
        s.tests.forEach(function (test, index) {
            var key = test[0];
            var options = test[1];
            var record = {
                id: s.name + '#' + index,
                suite: s.name,
                source: s.source,
                kind: kind,
                init: s.init,
                key: key === undefined ? null : key,
                options: options === undefined ? {} : options
            };
            try {
                var instance = i18next.createInstance();
                instance.init(Object.assign({ initAsync: false, debug: false }, __clone(s.init)));
                var result = __call(instance, kind, key, options);
                record.expected = result === undefined ? null : result;
            } catch (error) {
                record.error = String(error);
            }
            out.push(record);
        });
    });
    return out;
}
