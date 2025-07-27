"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.shield = void 0;
const tslib_1 = require("tslib");
const object_hash_1 = tslib_1.__importDefault(require("object-hash"));
const graphql_middleware_1 = require("graphql-middleware");
const validation_js_1 = require("./validation.js");
const generator_js_1 = require("./generator.js");
const constructors_js_1 = require("./constructors.js");
const utils_js_1 = require("./utils.js");
/**
 *
 * @param options
 *
 * Makes sure all of defined rules are in accord with the options
 * shield can process.
 *
 */
function normalizeOptions(options) {
    if (typeof options.fallbackError === 'string') {
        options.fallbackError = new Error(options.fallbackError);
    }
    return {
        debug: options.debug !== undefined ? options.debug : false,
        allowExternalErrors: (0, utils_js_1.withDefault)(false)(options.allowExternalErrors),
        fallbackRule: (0, utils_js_1.withDefault)(constructors_js_1.allow)(options.fallbackRule),
        fallbackError: (0, utils_js_1.withDefault)(new Error('Not Authorised!'))(options.fallbackError),
        hashFunction: (0, utils_js_1.withDefault)(object_hash_1.default)(options.hashFunction),
    };
}
/**
 *
 * @param ruleTree
 * @param options
 *
 * Validates rules and generates middleware from defined rule tree.
 *
 */
function shield(ruleTree, options = {}) {
    const normalizedOptions = normalizeOptions(options);
    const ruleTreeValidity = (0, validation_js_1.validateRuleTree)(ruleTree);
    if (ruleTreeValidity.status === 'ok') {
        const generatorFunction = (0, generator_js_1.generateMiddlewareGeneratorFromRuleTree)(ruleTree, normalizedOptions);
        return (0, graphql_middleware_1.middleware)(generatorFunction);
    }
    else {
        throw new validation_js_1.ValidationError(ruleTreeValidity.message);
    }
}
exports.shield = shield;
