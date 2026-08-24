package main

import (
	"net/http"
	"time"

	"gateway/config"
	"gateway/router"
)

func main() {
	config.Load()

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           router.New(),
		ReadHeaderTimeout: time.Duration(config.StreamTimeout) * time.Second,
		WriteTimeout:      time.Duration(config.StreamTimeout) * time.Second,
	}
	if err := srv.ListenAndServe(); err != nil {
		panic(err)
	}
}
