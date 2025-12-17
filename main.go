package main

import "fmt"

func main() {
	fmt.Println(Hello("CICD"))
}

// Hello returns a greeting for the named person.
func Hello(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}
