package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	r := setupRouter()
	// Listen and Server in 0.0.0.0:8080
	r.Run(":8080")
}

func setupRouter() *gin.Engine {
	r := gin.Default()
	r.GET("/hello", func(c *gin.Context) {
		name := c.DefaultQuery("name", "CICD")
		c.JSON(http.StatusOK, gin.H{
			"message": Hello(name),
		})
	})
	return r
}

// Hello returns a greeting for the named person.
func Hello(name string) string {
	return "Hello, " + name + "!"
}