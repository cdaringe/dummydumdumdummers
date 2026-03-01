"use strict";
/**
 * A minimal TypeScript library used to demonstrate real pipeline compilation.
 * This is compiled by the thingfactory typescript_build_pipeline().
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.add = add;
exports.subtract = subtract;
exports.multiply = multiply;
exports.greet = greet;
function add(a, b) {
    return a + b;
}
function subtract(a, b) {
    return a - b;
}
function multiply(a, b) {
    return a * b;
}
function greet(name) {
    return `Hello, ${name}!`;
}
//# sourceMappingURL=index.js.map