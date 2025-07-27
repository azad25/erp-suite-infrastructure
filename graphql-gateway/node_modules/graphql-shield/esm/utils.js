import { Rule, LogicRule } from './rules.js';
/**
 *
 * @param x
 *
 * Makes sure that a certain field is a rule.
 *
 */
export function isRule(x) {
    return (x instanceof Rule || (x && x.constructor && x.constructor.name === 'Rule'));
}
/**
 *
 * @param x
 *
 * Makes sure that a certain field is a logic rule.
 *
 */
export function isLogicRule(x) {
    return (x instanceof LogicRule ||
        (x &&
            x.constructor &&
            (x.constructor.name === 'RuleOr' ||
                x.constructor.name === 'RuleAnd' ||
                x.constructor.name === 'RuleChain' ||
                x.constructor.name === 'RuleRace' ||
                x.constructor.name === 'RuleNot' ||
                x.constructor.name === 'RuleTrue' ||
                x.constructor.name === 'RuleFalse')));
}
/**
 *
 * @param x
 *
 * Makes sure that a certain field is a rule or a logic rule.
 *
 */
export function isRuleFunction(x) {
    return isRule(x) || isLogicRule(x);
}
/**
 *
 * @param x
 *
 * Determines whether a certain field is rule field map or not.
 *
 */
export function isRuleFieldMap(x) {
    return (typeof x === 'object' &&
        Object.values(x).every((rule) => isRuleFunction(rule)));
}
/**
 *
 * @param obj
 * @param func
 *
 * Flattens object of particular type by checking if the leaf
 * evaluates to true from particular function.
 *
 */
export function flattenObjectOf(obj, f) {
    const values = Object.keys(obj).reduce((acc, key) => {
        const val = obj[key];
        if (f(val)) {
            return [...acc, val];
        }
        else if (typeof val === 'object' && !f(val)) {
            return [...acc, ...flattenObjectOf(val, f)];
        }
        else {
            return acc;
        }
    }, []);
    return values;
}
/**
 *
 * Returns fallback is provided value is undefined
 *
 * @param fallback
 */
export function withDefault(fallback) {
    return (value) => {
        if (value === undefined)
            return fallback;
        return value;
    };
}
