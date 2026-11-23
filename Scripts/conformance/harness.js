// Runs conformance cases against the real i18next (loaded into the same JavaScriptCore context) and records
// what it answers. `cases.js` calls `suite(...)`; `generate.swift` then reads `__run()`.
//
//   suite(name, source, init, tests, options)
//     name     unique id of the group
//     source   the upstream test file the cases were taken from
//     init     i18next init options (JSON only: no functions)
//     tests    [[key, options?], ...]
//     options  { kind }, one of: t (default), exists, getResource, resolveHierarchy, formatCode, languagePart, pluralSuffix,
//              bestMatch, missing (runs `t` and also records every call the `missingKeyHandler` receives),
//              fixedT (options = { fixed: { lng | lngs, ns, keyPrefix }, call: {...} }),
//              dir (key = language or null), resolvedLanguage (options.changeTo changes the language first),
//              hasLoadedNamespace (key = namespace, options = { lng }),
//              getDataByLanguage (key = language),
//              session (key = null, options = { steps: [[on, method, args, as?], ...] }: runs the steps against the
//                       instances by name (`i18n` is the one created from `init`, `as` names what `cloneInstance`
//                       makes) and answers with one entry per step: what a read method returned, else null.
//                       Methods: t, exists, language, languages, resolvedLanguage, changeLanguage, addResource,
//                       addResources, addResourceBundle, removeResourceBundle, getResource, getResourceBundle,
//                       hasResourceBundle, getDataByLanguage, hasLanguageSomeTranslations, toJSON, hydrate,
//                       cloneInstance, usePostProcessor)
//
// Handler options can be given by name: see `__handlers`.
//
// Post-processors `uppercase`, `wrap`, `bang`, `keyed`, `noop` and `times` are registered on every instance.

var __suites = [];

function suite(name, source, init, tests, options) {
    __suites.push({ name: name, source: source, init: init, tests: tests, options: options || {} });
}

// Post-processors registered on every instance (they only run when a case names them in `postProcess`).
// ConformanceTests.swift registers the same ones.
var __processors = {
    uppercase: function (value) { return value.toUpperCase(); },
    wrap: function (value) { return '[' + value + ']'; },
    bang: function (value) { return value + '!'; },
    keyed: function (value, key) { return value + '@' + (Array.isArray(key) ? key.join('|') : key); },
    noop: function () { return undefined; },
    times: function (value, key, options) { return new Array(options.times || 1).fill(value).join('-'); }
};

// Handlers that init and call options name by string (`missingInterpolationHandler: 'bracket'`), because the cases
// are JSON. ConformanceTests.swift implements the same ones.
var __handlers = {
    missingInterpolationHandler: {
        bracket: function (str, match) { return '[' + match[1].trim() + ']'; },
        html: function (str, match) { return '<b>' + match[1].trim() + '</b>'; },
        nothing: function () { return undefined; },
        placeholder: function (str, match) { return match[0]; },
        number: function () { return 42; }
    },
    returnedObjectHandler: {
        describe: function (key, value, options) {
            return 'object:' + key + ':' + Object.keys(value).length + ':' + (options.ns || []).join(',');
        },
        passthrough: function (key, value) { return value; },
        firstOfArray: function (key, value) { return Array.isArray(value) ? value[0] : null; }
    }
};

function __withHandlers(options) {
    if (!options) return options;
    Object.keys(__handlers).forEach(function (name) {
        if (typeof options[name] === 'string') {
            var handler = __handlers[name][options[name]];
            if (!handler) throw new Error('unknown ' + name + ' ' + options[name]);
            options[name] = handler;
        }
    });
    return options;
}

// Post-processors a session registers by name after the instance exists (see the `session` kind).
var __lateProcessors = {
    angle: function (value) { return '<' + value + '>'; },
    question: function (value) { return value + '?'; }
};

function __session(instance, steps) {
    var instances = { i18n: instance };
    return steps.map(function (step) {
        var target = instances[step[0]];
        if (!target) throw new Error('no instance ' + step[0]);
        var method = step[1];
        var args = __clone(step[2]) || [];
        var result;
        switch (method) {
            case 'cloneInstance': instances[step[3]] = target.cloneInstance(__withHandlers(args[0]) || {}); break;
            case 't': result = target.t(args[0], __withHandlers(args[1]) || {}); break;
            case 'exists': result = target.exists(args[0], args[1] || {}); break;
            case 'language': result = target.language; break;
            case 'languages': result = target.languages; break;
            case 'resolvedLanguage': result = target.resolvedLanguage; break;
            case 'changeLanguage': target.changeLanguage(args[0]); break;
            case 'addResource': target.addResource(args[0], args[1], args[2], args[3]); break;
            case 'addResources': target.addResources(args[0], args[1], args[2]); break;
            case 'addResourceBundle': target.addResourceBundle(args[0], args[1], args[2], args[3], args[4]); break;
            case 'removeResourceBundle': target.removeResourceBundle(args[0], args[1]); break;
            case 'getResource': result = target.getResource(args[0], args[1], args[2]); break;
            case 'getResourceBundle': result = target.getResourceBundle(args[0], args[1]); break;
            case 'hasResourceBundle': result = target.hasResourceBundle(args[0], args[1]); break;
            case 'getDataByLanguage': result = target.getDataByLanguage(args[0]); break;
            case 'hasLanguageSomeTranslations': result = target.store.hasLanguageSomeTranslations(args[0]); break;
            case 'toJSON': result = target.store.toJSON(); break;
            case 'hydrate': target.hydrate(args[0], args[1]); break;
            case 'usePostProcessor':
                target.use({ type: 'postProcessor', name: args[0], process: __lateProcessors[args[0]] || __processors[args[0]] });
                break;
            default: throw new Error('unknown session method ' + method);
        }
        return result === undefined ? null : __clone(result);
    });
}

function __clone(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

function __call(instance, kind, key, options) {
    switch (kind) {
        case 't':
            return instance.t(key, __withHandlers(__clone(options)) || {});
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
        case 'fixedT':
            var fixed = (options || {}).fixed || {};
            return instance.getFixedT(fixed.lngs || fixed.lng, fixed.ns, fixed.keyPrefix)(key, __clone((options || {}).call) || {});
        case 'dir':
            // i18next asks `Intl.Locale` first, and the answer then depends on the runtime. Hide it so that what is
            // recorded is i18next's own list of right-to-left languages, which is what this port implements.
            var textInfo = Intl.Locale.prototype.getTextInfo;
            Intl.Locale.prototype.getTextInfo = undefined;
            try {
                return instance.dir(key === null ? undefined : key);
            } finally {
                Intl.Locale.prototype.getTextInfo = textInfo;
            }
        case 'resolvedLanguage':
            if ((options || {}).changeTo !== undefined) instance.changeLanguage(options.changeTo);
            return instance.resolvedLanguage === undefined ? null : instance.resolvedLanguage;
        case 'hasLoadedNamespace':
            return instance.hasLoadedNamespace(key, __clone(options) || {});
        case 'getDataByLanguage':
            return instance.getDataByLanguage(key);
        case 'session':
            return __session(instance, (options || {}).steps || []);
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
                var init = Object.assign({ initAsync: false, debug: false }, __withHandlers(__clone(s.init)));
                var calls = [];
                if (kind === 'missing') {
                    init.missingKeyHandler = function (languages, namespace, missingKey, fallbackValue, isUpdate) {
                        calls.push({
                            languages: languages, namespace: namespace, key: missingKey,
                            fallbackValue: fallbackValue === undefined ? null : fallbackValue, isUpdate: isUpdate
                        });
                    };
                }
                instance.init(init);
                Object.keys(__processors).forEach(function (name) {
                    instance.use({ type: 'postProcessor', name: name, process: __processors[name] });
                });
                var result = kind === 'missing' ? { result: instance.t(key, __withHandlers(__clone(options)) || {}), calls: calls } : __call(instance, kind, key, options);
                record.expected = result === undefined ? null : result;
            } catch (error) {
                record.error = String(error);
            }
            out.push(record);
        });
    });
    return out;
}
