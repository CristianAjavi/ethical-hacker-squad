package router

import (
	"net/http"

	"gateway/handlers"
	"gateway/middleware"
)

// New wires the public surface. Anything registered here is reachable without a
// session; the authenticated surface lives in router/private.go.
func New() *http.ServeMux {
	mux := http.NewServeMux()

	mux.Handle("/v1/status", middleware.BodyLimit(http.HandlerFunc(handlers.Status)))
	mux.Handle("/v1/hooks/delivery", middleware.BodyLimit(http.HandlerFunc(handlers.Delivery)))
	mux.Handle("/v1/upload", http.HandlerFunc(handlers.Upload))

	return mux
}
