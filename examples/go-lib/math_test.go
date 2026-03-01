package math

import "testing"

func TestAdd(t *testing.T) {
	got := Add(2, 3)
	want := 5
	if got != want {
		t.Errorf("Add(2, 3) = %d; want %d", got, want)
	}
}

func TestSubtract(t *testing.T) {
	got := Subtract(10, 4)
	want := 6
	if got != want {
		t.Errorf("Subtract(10, 4) = %d; want %d", got, want)
	}
}

func TestMultiply(t *testing.T) {
	got := Multiply(3, 7)
	want := 21
	if got != want {
		t.Errorf("Multiply(3, 7) = %d; want %d", got, want)
	}
}

func TestGreet(t *testing.T) {
	got := Greet("thingfactory")
	want := "Hello, thingfactory!"
	if got != want {
		t.Errorf("Greet(thingfactory) = %q; want %q", got, want)
	}
}
