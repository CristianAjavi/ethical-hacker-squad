package handlers

import (
	"io"
	"net/http"
)

// Upload accepts an object and hands it to the storage layer.
func Upload(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if err := store(r.URL.Query().Get("name"), body); err != nil {
		http.Error(w, "storage error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

// Delivery receives a signed callback from the delivery provider.
func Delivery(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if !verify(r.Header.Get("X-Signature"), body) {
		http.Error(w, "bad signature", http.StatusUnauthorized)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// Status answers the load balancer.
func Status(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}
