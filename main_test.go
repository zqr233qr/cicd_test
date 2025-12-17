package main

import "testing"

func TestHello(t *testing.T) {
	expected := "Hello, CICD!"
	result := Hello("CICD")
	if result != expected {
		t.Errorf("Expected %s, but got %s", expected, result)
	}
}
