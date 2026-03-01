// Package math provides simple arithmetic operations.
// This library is used to demonstrate real Go compilation via thingfactory pipelines.
package math

// Add returns the sum of two integers.
func Add(a, b int) int {
	return a + b
}

// Subtract returns the difference of two integers.
func Subtract(a, b int) int {
	return a - b
}

// Multiply returns the product of two integers.
func Multiply(a, b int) int {
	return a * b
}

// Greet returns a greeting string.
func Greet(name string) string {
	return "Hello, " + name + "!"
}
